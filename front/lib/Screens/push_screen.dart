import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/context_event_service.dart';
import '../Services/config.dart';
import 'routine_screen.dart';
import 'priority.dart';
import 'dart:async';

class PushScreen extends StatefulWidget {
  const PushScreen({super.key});

  @override
  State<PushScreen> createState() => _PushScreenState();
}

class _PushScreenState extends State<PushScreen> {
  String? _latenessMessage;
  String? _unusedFirstLine;
  String? _unusedSecondLine;
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
    _loadContextEvent();
    _loadUnusedNotification();
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

    try {
      final response = await ContextEventService.getContextEvent(
        currentLat: testLat,
        currentLng: testLng,
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

      for (final url in urlsToTry) {
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
                const Duration(seconds: 60),
                onTimeout: () {
                  throw Exception('요청 시간 초과');
                },
              );

          if (response.statusCode == 200) {
            final data =
                jsonDecode(utf8.decode(response.bodyBytes))
                    as Map<String, dynamic>;
            final hasNotification = data['has_notification'] as bool? ?? false;

            if (hasNotification) {
              final notification =
                  data['notification'] as Map<String, dynamic>?;
              if (notification != null && mounted) {
                setState(() {
                  _unusedFirstLine = notification['first_line'] as String?;
                  _unusedSecondLine = notification['second_line'] as String?;
                });
              }
            }
            break; // 성공하면 종료
          }
        } catch (e) {
          print('[PushScreen] 미사용 알림 로딩 실패 ($url): $e');
          continue;
        }
      }
    } catch (e) {
      print('[PushScreen] 미사용 알림 로딩 실패: $e');
    }
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

                  // 미사용 알림 카드 (귀가 알림 아래 간격을 두고 배치)
                  if (!_isLoading &&
                      _unusedFirstLine != null &&
                      _unusedSecondLine != null) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildNotificationCard(
                        firstLine: _unusedFirstLine!,
                        secondLine: _unusedSecondLine!,
                        timeLabel: '지금',
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
                    softWrap: true,
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
                    softWrap: true,
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
