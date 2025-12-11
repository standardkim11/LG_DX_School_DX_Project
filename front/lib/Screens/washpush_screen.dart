import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/bottom_navigation.dart';
import '../Services/config.dart';
import '../Services/routine_service.dart';
import 'push_screen.dart';

class WashPushScreen extends StatefulWidget {
  const WashPushScreen({super.key});

  @override
  State<WashPushScreen> createState() => _WashPushScreenState();
}

class _WashPushScreenState extends State<WashPushScreen> {
  bool _isPopupClosed = false;
  bool _isSkipped = false; // 오늘 건너뛰기 여부
  String? _notificationFirstLine; // DB에서 가져온 첫 번째 줄
  String? _notificationSecondLine; // DB에서 가져온 두 번째 줄
  String? _routineName; // DB에서 가져온 루틴 이름
  bool _isLoadingNotification = true; // 알림 로딩 상태
  List<Map<String, dynamic>> _allRoutines = []; // DB에서 가져온 루틴 리스트
  bool _isLoadingRoutines = false; // 루틴 로딩 상태
  String? _weatherMessage; // 날씨 정보 메시지

  static const _cardShadow = BoxShadow(
    color: Color(0x0F222C5C),
    blurRadius: 68,
    offset: Offset(58, 26),
    spreadRadius: 0,
  );

  static const _bannerTitleStyle = TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w600,
    height: 1,
  );

  static const _bannerTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 15,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w700,
    height: 1.52,
  );

  static const _cardTitleStyle = TextStyle(
    color: Colors.black,
    fontSize: 15,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w300,
    height: 1.33,
  );

  static const _cardTimeStyle = TextStyle(
    color: Colors.black,
    fontSize: 13,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w400,
    height: 0.5,
  );

  static const _buttonTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w400,
    height: 1.43,
  );

  // API 베이스 URL
  static String get baseUrl {
    return ApiConfig.getBaseUrl(
      isWeb: kIsWeb,
      isAndroid: !kIsWeb && Platform.isAndroid,
      isIOS: !kIsWeb && Platform.isIOS,
    );
  }

  static const int userId = 1;

  @override
  void initState() {
    super.initState();
    // DB에서 미사용 알림 데이터 가져오기
    _loadUnusedNotification();
    // DB에서 루틴 데이터 가져오기
    _loadAllRoutines();
    // 날씨 정보 가져오기
    _loadWeatherInfo();
  }

  Future<void> _loadAllRoutines() async {
    setState(() {
      _isLoadingRoutines = true;
    });

    try {
      final allRoutines = await RoutineService.getAllRoutines();

      if (mounted) {
        setState(() {
          // DB에서 가져온 루틴을 화면 표시 형식으로 변환
          _allRoutines = allRoutines.asMap().entries.map((entry) {
            final routine = entry.value;
            return {
              'key': ValueKey('routine_${routine.id}'),
              'title': routine.name,
              'time': routine.getTimeDisplay(),
              'imagePath': _getImagePath(routine.routineType),
              'orderNumber': entry.key + 1,
              'routineId': routine.id,
            };
          }).toList();
          _isLoadingRoutines = false;
        });
      }
    } catch (e) {
      print('[WashPushScreen] 루틴 로딩 실패: $e');
      if (mounted) {
        setState(() {
          _isLoadingRoutines = false;
        });
      }
    }
  }

  // 루틴 타입에 따른 이미지 경로 반환
  String _getImagePath(String routineType) {
    final type = routineType.toUpperCase();
    if (type.contains('LAUNDRY') || type.contains('WASH')) {
      return 'assets/priority_screen/washing.png';
    } else if (type.contains('ROBOT') || type.contains('CLEANER')) {
      return 'assets/priority_screen/robot.png';
    } else if (type.contains('CLEANING')) {
      return 'assets/priority_screen/robot.png';
    } else {
      return 'assets/priority_screen/washing.png'; // 기본값
    }
  }

  Future<void> _loadUnusedNotification() async {
    try {
      List<String> urlsToTry = [baseUrl];
      if (!kIsWeb && Platform.isAndroid && ApiConfig.useEmulator == null) {
        urlsToTry = ApiConfig.getAndroidBaseUrls();
      }

      // 병렬로 여러 URL 시도
      final futures = urlsToTry.map((url) async {
        try {
          final uri = Uri.parse(
            '$url/recommend/unused-notification',
          ).replace(queryParameters: {'user_id': userId.toString()});
          final response = await http
              .get(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              )
              .timeout(
                const Duration(seconds: 120), // 실제 기기 네트워크 고려하여 120초로 증가
                onTimeout: () {
                  throw Exception('요청 시간 초과');
                },
              );

          if (response.statusCode == 200) {
            final data =
                jsonDecode(utf8.decode(response.bodyBytes))
                    as Map<String, dynamic>;
            return data;
          }
          return null;
        } catch (e) {
          print('[WashPushScreen] 미사용 알림 로딩 실패 ($url): $e');
          return null;
        }
      });

      // 첫 번째 성공한 응답 사용
      final results = await Future.wait(futures);
      Map<String, dynamic>? data;
      try {
        data = results.firstWhere((result) => result != null);
      } catch (e) {
        // 모든 URL이 실패한 경우
        data = null;
      }

      if (data != null && mounted) {
        final hasNotification = data['has_notification'] as bool? ?? false;

        if (hasNotification) {
          final notification = data['notification'] as Map<String, dynamic>?;
          if (notification != null) {
            setState(() {
              _notificationFirstLine = notification['first_line'] as String?;
              _notificationSecondLine = notification['second_line'] as String?;
              _routineName = notification['routine_name'] as String?;
              _isLoadingNotification = false;
            });
            // 알림 데이터를 가져온 후 팝업 표시
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showWasherPopup(context);
            });
            return;
          }
        }
      }

      // 알림이 없거나 데이터를 가져오지 못한 경우 기본값 사용
      if (mounted) {
        setState(() {
          _isLoadingNotification = false;
          // 기본값은 null로 두고, 팝업은 표시하지 않음
        });
      }
    } catch (e) {
      print('[WashPushScreen] 미사용 알림 로딩 실패: $e');
      if (mounted) {
        setState(() {
          _isLoadingNotification = false;
        });
      }
    }
  }

  Future<void> _loadWeatherInfo() async {
    try {
      // 날씨 정보 API 호출
      List<String> urlsToTry = [baseUrl];
      if (!kIsWeb && Platform.isAndroid && ApiConfig.useEmulator == null) {
        urlsToTry = ApiConfig.getAndroidBaseUrls();
      }

      String? weatherMessage;
      print('[WashPushScreen] 날씨 정보 로딩 시작: ${urlsToTry.length}개 URL');
      for (int i = 0; i < urlsToTry.length; i++) {
        final url = urlsToTry[i];
        print('[WashPushScreen] 날씨 정보 시도 ${i + 1}/${urlsToTry.length}: $url');
        try {
          final uri = Uri.parse('$url/recommend/weather?user_id=$userId');
          print('[WashPushScreen] 날씨 정보 API 호출: $uri');
          final response = await http
              .get(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              )
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  throw Exception('요청 시간 초과');
                },
              );

          print(
            '[WashPushScreen] 날씨 정보 API 응답: statusCode=${response.statusCode}',
          );
          if (response.statusCode == 200) {
            try {
              final data =
                  jsonDecode(utf8.decode(response.bodyBytes))
                      as Map<String, dynamic>;
              final recommendationMessage =
                  data['recommendation_message'] as String?;
              if (recommendationMessage != null &&
                  recommendationMessage.isNotEmpty) {
                weatherMessage = recommendationMessage;
              } else {
                // 날씨 정보는 있지만 추천 메시지가 없는 경우
                final weatherLabel = data['weather_label'] as String? ?? '맑음';
                weatherMessage = '오늘 날씨는 $weatherLabel이에요.';
              }
              print(
                '[WashPushScreen] 날씨 정보 로딩 성공: $url, weather_label=${data['weather_label']}, recommendation_message=$recommendationMessage',
              );
              break; // 성공하면 종료
            } catch (parseError) {
              print('[WashPushScreen] 날씨 정보 JSON 파싱 실패: $parseError');
              print('[WashPushScreen] 응답 본문: ${response.body}');
              continue;
            }
          } else {
            // HTTP 에러
            print(
              '[WashPushScreen] 날씨 정보 HTTP 에러 ($url): statusCode=${response.statusCode}, body=${response.body}',
            );
            continue;
          }
        } catch (e, stackTrace) {
          // 모든 URL 시도 실패 시 로그 출력
          print('[WashPushScreen] 날씨 정보 로딩 실패 ($url): $e');
          print('[WashPushScreen] 스택 트레이스: $stackTrace');
          if (i == urlsToTry.length - 1) {
            // 마지막 URL도 실패
            print('[WashPushScreen] 날씨 정보 로딩 실패 - 모든 URL 시도 완료');
          }
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _weatherMessage = weatherMessage;
        });
      }
    } catch (e) {
      // 날씨 정보 로딩 실패 시 로그 출력
      print('[WashPushScreen] 날씨 정보 로딩 중 예외 발생: $e');
      if (mounted) {
        setState(() {
          _weatherMessage = null;
        });
      }
    }
  }

  void _showWasherPopup(BuildContext context) {
    // 알림 데이터가 없으면 팝업 표시 안 함
    if (_notificationFirstLine == null || _notificationSecondLine == null) {
      return;
    }

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
                      '${_routineName ?? '세탁기'} 알림',
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
                          _notificationFirstLine ?? '',
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
                          _notificationSecondLine ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'LG Smart_H',
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111111),
                            height: 1.3,
                          ),
                        ),
                        // 날씨 정보 표시
                        if (_weatherMessage != null &&
                            _weatherMessage!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8E9F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _weatherMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 9,
                                fontFamily: 'LG Smart_H',
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF4B57BB),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
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
                                    setState(() {
                                      _isPopupClosed = true;
                                    });
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
                                    // push_screen으로 이동
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const PushScreen(),
                                      ),
                                    );
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
                                  '오늘 건너뛰기',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: SafeArea(
        child: Stack(
          children: [
            // 메인 콘텐츠 (PriorityScreen 스타일 배경)
            Column(
              children: [
                // 상단 제목과 배너 영역 (흰색 배경)
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      // 상단 제목
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 47,
                          left: 30,
                          right: 20,
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Image.asset(
                                'assets/lgrouthinq/Back_icon.png',
                                width: 24,
                                height: 24,
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  '우선순위 설정',
                                  style: AppTextStyles.sectionTitle(context)
                                      .copyWith(
                                        fontSize: 24,
                                        height: 1,
                                        fontWeight: FontWeight.w500,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 24, // 오른쪽 공간 (뒤로가기 버튼과 대칭)
                            ),
                          ],
                        ),
                      ),

                      // 보라색 배너
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Container(
                          width: double.infinity,
                          height: 140,
                          padding: const EdgeInsets.all(16),
                          decoration: ShapeDecoration(
                            color: AppColors.textAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(50),
                                topRight: Radius.circular(50),
                              ),
                            ),
                            shadows: [_cardShadow],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '지현님이 선택한 루틴',
                                        style: _bannerTitleStyle.copyWith(
                                          fontSize: 20,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      if (_notificationFirstLine != null &&
                                          _notificationSecondLine != null) ...[
                                        Text(
                                          _notificationFirstLine!,
                                          style: _bannerTextStyle.copyWith(
                                            fontSize: 11,
                                            height: 1.3,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _notificationSecondLine!,
                                          style: _bannerTextStyle.copyWith(
                                            fontSize: 11,
                                            height: 1.3,
                                          ),
                                        ),
                                      ] else
                                        Text(
                                          '선택한 루틴을 확인해주세요',
                                          style: _bannerTextStyle.copyWith(
                                            fontSize: 11,
                                            height: 1.3,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 20,
                                  right: 20,
                                ),
                                child: Container(
                                  width: 67,
                                  height: 67,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFE8E8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/routine_screen/jiheon_human.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 루틴 리스트 (팝업이 닫힌 후에만 표시)
                if (_isPopupClosed)
                  Expanded(
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      child: _isLoadingRoutines
                          ? const Center(child: CircularProgressIndicator())
                          : Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 20,
                              ),
                              child: Builder(
                                builder: (context) {
                                  // 오늘 건너뛰기를 눌렀으면 해당 루틴 제거
                                  List<Map<String, dynamic>> filteredRoutines;
                                  if (_isSkipped && _routineName != null) {
                                    // 건너뛴 루틴 이름과 일치하는 루틴 제거
                                    filteredRoutines = _allRoutines
                                        .where(
                                          (r) => r['title'] != _routineName,
                                        )
                                        .toList();
                                  } else {
                                    filteredRoutines =
                                        List<Map<String, dynamic>>.from(
                                          _allRoutines,
                                        );
                                  }

                                  if (filteredRoutines.isEmpty) {
                                    return Center(
                                      child: Text(
                                        '표시할 루틴이 없습니다',
                                        style: AppTextStyles.todoCategory(
                                          context,
                                        ),
                                      ),
                                    );
                                  }

                                  // 순서 번호 재정렬
                                  final routinesWithOrder = filteredRoutines
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                        final routine =
                                            Map<String, dynamic>.from(
                                              entry.value,
                                            );
                                        routine['orderNumber'] = entry.key + 1;
                                        // key가 없으면 새로 생성
                                        if (routine['key'] == null) {
                                          routine['key'] = ValueKey(
                                            'routine_${entry.key}',
                                          );
                                        }
                                        return routine;
                                      })
                                      .toList();

                                  return ClipRect(
                                    child: ReorderableListView(
                                      physics: const ClampingScrollPhysics(),
                                      buildDefaultDragHandles: false,
                                      onReorder: (oldIndex, newIndex) {
                                        setState(() {
                                          // 인덱스 범위 검증
                                          if (oldIndex < 0 ||
                                              oldIndex >=
                                                  routinesWithOrder.length)
                                            return;
                                          if (newIndex < 0) newIndex = 0;
                                          if (newIndex >=
                                              routinesWithOrder.length)
                                            newIndex =
                                                routinesWithOrder.length - 1;

                                          if (newIndex > oldIndex) {
                                            newIndex -= 1;
                                          }

                                          // 범위 재검증
                                          if (newIndex < 0) newIndex = 0;
                                          if (newIndex >=
                                              routinesWithOrder.length)
                                            newIndex =
                                                routinesWithOrder.length - 1;

                                          // 필터링된 리스트에서 아이템 이동
                                          final item = routinesWithOrder
                                              .removeAt(oldIndex);
                                          routinesWithOrder.insert(
                                            newIndex,
                                            item,
                                          );

                                          // 원본 리스트 업데이트
                                          if (_isSkipped) {
                                            // 세탁기가 제거된 상태면 필터링된 리스트만 업데이트
                                            _allRoutines = _allRoutines
                                                .where(
                                                  (r) =>
                                                      r['title'] != '세탁기 돌리기',
                                                )
                                                .toList();
                                            for (
                                              int i = 0;
                                              i < routinesWithOrder.length;
                                              i++
                                            ) {
                                              final key =
                                                  routinesWithOrder[i]['key'];
                                              final index = _allRoutines
                                                  .indexWhere(
                                                    (r) => r['key'] == key,
                                                  );
                                              if (index != -1) {
                                                _allRoutines[index] =
                                                    routinesWithOrder[i];
                                              }
                                            }
                                          } else {
                                            // 모든 루틴이 있는 상태면 전체 리스트 업데이트
                                            for (
                                              int i = 0;
                                              i < routinesWithOrder.length;
                                              i++
                                            ) {
                                              final key =
                                                  routinesWithOrder[i]['key'];
                                              final index = _allRoutines
                                                  .indexWhere(
                                                    (r) => r['key'] == key,
                                                  );
                                              if (index != -1) {
                                                _allRoutines[index] =
                                                    routinesWithOrder[i];
                                              }
                                            }
                                          }

                                          // 순서 번호 재정렬
                                          for (
                                            int i = 0;
                                            i < _allRoutines.length;
                                            i++
                                          ) {
                                            _allRoutines[i]['orderNumber'] =
                                                i + 1;
                                          }
                                        });
                                      },
                                      children: routinesWithOrder
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                            final index = entry.key;
                                            final routine = entry.value;

                                            return Padding(
                                              key:
                                                  routine['key'] as Key? ??
                                                  ValueKey('routine_$index'),
                                              padding: EdgeInsets.only(
                                                bottom:
                                                    index <
                                                        routinesWithOrder
                                                                .length -
                                                            1
                                                    ? 12
                                                    : 0,
                                              ),
                                              child:
                                                  ReorderableDragStartListener(
                                                    index: index,
                                                    child: _PriorityCard(
                                                      title:
                                                          routine['title']
                                                              as String,
                                                      time:
                                                          routine['time']
                                                              as String,
                                                      imagePath:
                                                          routine['imagePath']
                                                              as String,
                                                      orderNumber:
                                                          routine['orderNumber']
                                                              as int,
                                                    ),
                                                  ),
                                            );
                                          })
                                          .toList(),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  )
                else
                  Expanded(child: Container(color: AppColors.backgroundGray)),

                // 우선순위 설정 버튼 (팝업이 닫힌 후에만 표시)
                if (_isPopupClosed)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        decoration: ShapeDecoration(
                          color: AppColors.textAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '우선순위 설정',
                            style: _buttonTextStyle.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // 하단 네비게이션
                const CustomBottomNavigation(currentScreen: 'washpush'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityCard extends StatelessWidget {
  final String title;
  final String time;
  final String imagePath;
  final int orderNumber;

  const _PriorityCard({
    required this.title,
    required this.time,
    required this.imagePath,
    required this.orderNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 80,
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: AppColors.backgroundWhite,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: AppColors.backgroundGray),
          borderRadius: BorderRadius.circular(16),
        ),
        shadows: [_WashPushScreenState._cardShadow],
      ),
      child: Row(
        children: [
          // 순서 번호 배지
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.textAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$orderNumber',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textAccent,
                  fontFamily: 'LG Smart_H',
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: title == '로봇청소기 물청소하기' ? 4 : 0),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: _WashPushScreenState._cardTitleStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(time, style: _WashPushScreenState._cardTimeStyle),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Center(
            child: Icon(
              Icons.drag_handle,
              color: AppColors.textAccent,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}
