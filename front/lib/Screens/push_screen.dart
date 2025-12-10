import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/context_event_service.dart';
import '../Services/config.dart';
import '../components/app_colors.dart';
import '../Services/routine_service.dart';
import 'routine_screen.dart';
import 'priority.dart';
import 'dart:async';
import 'routine_screen.dart' as routine_module;

class PushScreen extends StatefulWidget {
  const PushScreen({super.key});

  @override
  State<PushScreen> createState() => _PushScreenState();
}

class _PushScreenState extends State<PushScreen> {
  String? _latenessMessage;
  String? _unusedFirstLine;
  String? _unusedSecondLine;
  int? _unusedRoutineId; // 미실행 알림의 루틴 ID
  String? _unusedRoutineName; // 미실행 알림의 루틴 이름
  bool _isLoading = true;
  Timer? _timeTimer;
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _updateCurrentTime();
    // 매 초마다 시간 업데이트
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCurrentTime();
    });
    // 성능 최적화: 두 API 호출을 병렬 처리
    _loadAllData();
  }

  // 병렬로 모든 데이터 로드
  Future<void> _loadAllData() async {
    await Future.wait([_loadContextEvent(), _loadUnusedNotification()]);
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    super.dispose();
  }

  void _updateCurrentTime() {
    if (!mounted) return;
    final now = DateTime.now();
    setState(() {
      _currentTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _loadContextEvent() async {
    // 테스트용 위치 (실제로는 GPS에서 가져와야 함)
    // 사용자 집 위치 근처로 설정 (예: 서울시청 좌표)
    const double testLat = 37.5665;
    const double testLng = 126.9780;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    // 귀가 알림 로드
    await _loadHomeArrivalNotification(testLat, testLng);

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadHomeArrivalNotification(double lat, double lng) async {
    try {
      final response = await ContextEventService.getContextEvent(
        currentLat: lat,
        currentLng: lng,
      );

      if (!mounted) return;

      if (response != null && response['triggered'] == true) {
        final latenessMinutes = response['lateness_minutes'] as int? ?? 0;

        // 메시지 생성
        String message;
        if (latenessMinutes > 0) {
          message = '지현님, 평소보다 귀가가 ${latenessMinutes}분 늦었네요';
        } else if (latenessMinutes < 0) {
          message = '지현님, 평소보다 귀가가 ${-latenessMinutes}분 빠르시네요';
        } else {
          message = '지현님, 오늘은 평소와 거의 비슷한 시간에 귀가 중이에요';
        }

        if (mounted) {
          setState(() {
            _latenessMessage = message;
            _isLoading = false;
          });
        }
      } else {
        // API가 triggered=false를 반환하거나 오류 발생 시 기본 메시지
        if (mounted) {
          setState(() {
            _latenessMessage = '지현님, 오늘은 평소와 거의 비슷한 시간에 귀가 중이에요';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading context event: $e');
      if (mounted) {
        setState(() {
          _latenessMessage = '지현님, 오늘은 평소와 거의 비슷한 시간에 귀가 중이에요';
          _isLoading = false;
        });
      }
    }
  }

  // API 베이스 URL
  static String get baseUrl {
    return ApiConfig.getBaseUrl(
      isWeb: kIsWeb,
      isAndroid: !kIsWeb && Platform.isAndroid,
      isIOS: !kIsWeb && Platform.isIOS,
    );
  }

  static const int userId = 1;

  Future<void> _loadUnusedNotification() async {
    try {
      // 미사용 알림 API 호출
      List<String> urlsToTry = [baseUrl];
      if (!kIsWeb && Platform.isAndroid && ApiConfig.useEmulator == null) {
        urlsToTry = ApiConfig.getAndroidBaseUrls();
      }

      // 성능 최적화: 순차적으로 시도 (실제 기기에서는 10.0.2.2 타임아웃 시간 낭비 방지)
      // 첫 번째 URL부터 시도하고, 성공하면 즉시 반환
      Map<String, dynamic>? data;
      String? successUrl;
      print('[PushScreen] 미사용 알림 로딩 시작: ${urlsToTry.length}개 URL');
      for (int i = 0; i < urlsToTry.length; i++) {
        final url = urlsToTry[i];
        print('[PushScreen] 미사용 알림 시도 ${i + 1}/${urlsToTry.length}: $url');
        try {
          final uri = Uri.parse(
            '$url/recommend/unused-notification',
          ).replace(queryParameters: {'user_id': userId.toString()});
          print('[PushScreen] 미사용 알림 요청 URI: $uri');
          final response = await http
              .get(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              )
              .timeout(
                const Duration(seconds: 10), // 실제 기기에서는 빠른 실패로 다음 URL 시도
                onTimeout: () {
                  print('[PushScreen] 미사용 알림 타임아웃: $url');
                  throw Exception('요청 시간 초과');
                },
              );

          print('[PushScreen] 미사용 알림 응답 상태: ${response.statusCode} (URL: $url)');
          if (response.statusCode == 200) {
            data =
                jsonDecode(utf8.decode(response.bodyBytes))
                    as Map<String, dynamic>;
            successUrl = url;
            print('[PushScreen] 미사용 알림 로딩 성공: $url');
            print('[PushScreen] 미사용 알림 데이터: $data');
            print('[PushScreen] 미사용 알림 - 첫 번째 URL 성공, 나머지 URL 시도 중단');
            break; // 성공하면 즉시 반복 종료
          } else {
            // HTTP 에러
            print('[PushScreen] HTTP 에러 ($url): ${response.statusCode}');
            print('[PushScreen] HTTP 에러 응답 본문: ${response.body}');
            if (i < urlsToTry.length - 1) {
              print('[PushScreen] 미사용 알림 - 다음 URL 시도 계속...');
            }
            continue;
          }
        } catch (e, stackTrace) {
          // 모든 URL 시도 실패 시 로그 출력
          print('[PushScreen] 미사용 알림 로딩 실패 ($url): $e');
          print('[PushScreen] 미사용 알림 에러 스택: $stackTrace');
          if (i < urlsToTry.length - 1) {
            print('[PushScreen] 미사용 알림 - 다음 URL 시도 계속...');
          } else {
            // 마지막 URL도 실패
            print('[PushScreen] 미사용 알림 로딩 실패 - 모든 URL 시도 완료');
          }
          continue;
        }
      }

      // 최종 결과 로그
      if (data != null && successUrl != null) {
        print('[PushScreen] 미사용 알림 최종 성공: $successUrl');
      } else {
        print('[PushScreen] 미사용 알림 최종 실패: 모든 URL 연결 시도 완료');
      }

      if (data != null && mounted) {
        final hasNotification = data['has_notification'] as bool? ?? false;

        print('[PushScreen] 미사용 알림 응답: has_notification=$hasNotification');
        
        if (hasNotification) {
          final notification = data['notification'] as Map<String, dynamic>?;
          print('[PushScreen] 미사용 알림 데이터: $notification');
          if (notification != null) {
            setState(() {
              _unusedFirstLine = notification['first_line'] as String?;
              _unusedSecondLine = notification['second_line'] as String?;
              _unusedRoutineId = notification['routine_id'] as int?;
              _unusedRoutineName = notification['routine_name'] as String?;
            });
            print('[PushScreen] 미사용 알림 설정 완료: first_line=$_unusedFirstLine, second_line=$_unusedSecondLine');
          } else {
            print('[PushScreen] ⚠️ 미사용 알림: notification이 null입니다');
            setState(() {
              _unusedFirstLine = null;
              _unusedSecondLine = null;
              _unusedRoutineId = null;
              _unusedRoutineName = null;
            });
          }
        } else {
          // 알림이 없는 이유 확인
          final reason = data['reason'] as String?;
          final routinesChecked = data['routines_checked'] as int?;
          final routineDetails = data['routine_details'] as List<dynamic>?;
          
          print('[PushScreen] ⚠️ 미사용 알림이 없습니다 (has_notification=false)');
          print('[PushScreen]   - 이유: $reason');
          print('[PushScreen]   - 확인된 루틴 수: $routinesChecked');
          if (routineDetails != null && routineDetails.isNotEmpty) {
            print('[PushScreen]   - 루틴 상세 정보:');
            for (var detail in routineDetails) {
              final detailMap = detail as Map<String, dynamic>;
              print('[PushScreen]     * ${detailMap['routine_name']}: ${detailMap['time_period']} ${detailMap['executions_count']}/${detailMap['expected_count']}회 (${detailMap['schedule_type']}, 주기=${detailMap['schedule_frequency']})');
            }
          }
          
          setState(() {
            _unusedFirstLine = null;
            _unusedSecondLine = null;
            _unusedRoutineId = null;
            _unusedRoutineName = null;
          });
        }
      } else {
        print('[PushScreen] ⚠️ 미사용 알림: data가 null이거나 mounted가 false입니다');
      }
    } catch (e) {
      // 예외 발생 시 로그 출력
      print('[PushScreen] 미사용 알림 로딩 중 예외 발생: $e');
      // 에러 발생 시 알림 표시 안 함
    }
  }

  void _showUnusedNotificationDialog() {
    if (_unusedRoutineId == null) return;

    String? selectedButton;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundGray,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_unusedRoutineName ?? '루틴'} 알림',
                      style: const TextStyle(
                        fontSize: 20,
                        fontFamily: 'LG Smart_H',
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      children: [
                        Text(
                          _unusedFirstLine ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'LG Smart_H',
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111111),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _unusedSecondLine ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'LG Smart_H',
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111111),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTapDown: (_) {
                              setDialogState(() {
                                selectedButton = 'execute';
                              });
                            },
                            onTap: () {
                              setDialogState(() {
                                selectedButton = 'execute';
                              });
                              Future.delayed(
                                const Duration(milliseconds: 300),
                                () {
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                    // 실행하기: 루틴 실행 API 호출 후 루틴 화면으로 이동
                                    if (_unusedRoutineId != null) {
                                      // 먼저 루틴 실행 API 호출 (자동 체크를 위해)
                                      RoutineService.executeRoutine(
                                        routineId: _unusedRoutineId!,
                                        userId: 1,
                                      ).then((success) {
                                        if (success) {
                                          print('[PushScreen] 루틴 실행 성공: $_unusedRoutineId');
                                        } else {
                                          print('[PushScreen] 루틴 실행 실패: $_unusedRoutineId');
                                        }
                                      });
                                      
                                      // 오늘 날짜로 선택된 루틴 추가
                                      final today = DateTime.now();
                                      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
                                      final currentSelected = routine_module.getSelectedRoutinesForDate(dateKey) ?? <int>{};
                                      currentSelected.add(_unusedRoutineId!);
                                      routine_module.setSelectedRoutinesForDate(dateKey, currentSelected);
                                      print('[PushScreen] 루틴 ID $_unusedRoutineId를 오늘 날짜($dateKey)의 선택된 루틴으로 추가');
                                    }
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (context, animation, secondaryAnimation) =>
                                            const RoutineScreen(),
                                        transitionDuration: Duration.zero,
                                        reverseTransitionDuration: Duration.zero,
                                      ),
                                      (route) => false,
                                    );
                                  }
                                },
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: selectedButton == 'execute'
                                    ? const Color(0xFF4B57BB)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '실행하기',
                                  style: TextStyle(
                                    color: selectedButton == 'execute'
                                        ? Colors.white
                                        : Colors.black,
                                    fontSize: 14,
                                    fontFamily: 'LG Smart_H',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTapDown: (_) {
                              setDialogState(() {
                                selectedButton = 'skip';
                              });
                            },
                            onTap: () {
                              setDialogState(() {
                                selectedButton = 'skip';
                              });
                              Future.delayed(
                                const Duration(milliseconds: 300),
                                () {
                                  if (context.mounted) {
                                    Navigator.of(context).pop(); // 팝업 닫기
                                    // 건너뛰기: 그냥 닫기만
                                  }
                                },
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: selectedButton == 'skip'
                                    ? const Color(0xFF4B57BB)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '건너뛰기',
                                  style: TextStyle(
                                    color: selectedButton == 'skip'
                                        ? Colors.white
                                        : Colors.black,
                                    fontSize: 12,
                                    fontFamily: 'LG Smart_H',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleSwipeLeft() {
    // 왼쪽으로 스와이프하면 routine_screen으로 이동
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const RoutineScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        // 왼쪽으로 스와이프 감지
        if (details.primaryVelocity! < -500) {
          _handleSwipeLeft();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // 배경 이미지
            Positioned.fill(
              child: Image.asset(
                'assets/push_screen/pushscreen.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // 이미지 로드 실패 시 대체 배경
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFE8E8F0),
                          const Color(0xFFD0D0E0),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 시간, 날짜, 알림 카드를 세로로 배치
            SafeArea(
              child: Column(
                children: [
                  // 상단 시간 표시
                  Padding(
                    padding: const EdgeInsets.only(top: 50),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentTime,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'LG Smart_H',
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getCurrentDate(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'LG Smart_H',
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 알림 카드 (시간/날짜 아래 적절한 간격으로 배치)
                  if (!_isLoading && _latenessMessage != null) ...[
                    const SizedBox(height: 50),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GestureDetector(
                        onTap: () {
                          // 우선순위 설정 화면으로 즉시 이동 (루틴은 PriorityScreen에서 로드)
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PriorityScreen(
                                selectedRoutines: [],
                                shouldLoadRoutines: true,
                              ),
                            ),
                          );
                        },
                        child: _buildNotificationCard(
                          firstLine: _latenessMessage ?? '',
                          secondLine: '귀가하시면 해야할일 추천해드릴게요',
                          timeLabel: '지금',
                        ),
                      ),
                    ),
                  ],

                  // 미사용 알림 카드 (DB에서 가져온 미실행 루틴 알림)
                  if (!_isLoading &&
                      _unusedFirstLine != null &&
                      _unusedSecondLine != null) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GestureDetector(
                        onTap: () {
                          // 미사용 알림 클릭 시 다이얼로그 표시
                          _showUnusedNotificationDialog();
                        },
                        child: _buildNotificationCard(
                          firstLine: _unusedFirstLine!,
                          secondLine: _unusedSecondLine!,
                          timeLabel: '지금',
                        ),
                      ),
                    ),
                  ],

                  // 하단 여백을 위한 Spacer
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required String firstLine,
    required String secondLine,
    required String timeLabel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 아이콘 (빨간색 배경)
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              //color: const Color(0xFFFF3132), // 빨간색
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Image.asset(
                'assets/home_screen/ThinQ_icon.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 메시지와 시간
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    firstLine,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'LG Smart_H',
                      height: 1.3,
                      letterSpacing: -0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    secondLine,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'LG Smart_H',
                      height: 1.3,
                      letterSpacing: -0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      timeLabel,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'LG Smart_H',
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    return '${now.month}월 ${now.day}일 ${weekdays[now.weekday - 1]}';
  }
}
