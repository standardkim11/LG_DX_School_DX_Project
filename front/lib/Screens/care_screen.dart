import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'robotpush_screen.dart';
import '../Services/config.dart';

class CareScreen extends StatefulWidget {
  const CareScreen({super.key});

  @override
  State<CareScreen> createState() => _CareScreenState();
}

class _CareScreenState extends State<CareScreen> {
  String? _robotCleanerMessage;
  int? _robotCleanerRoutineId; // 로봇청소기 루틴 ID 저장
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
    _loadRobotCleanerNotification();
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    super.dispose();
  }

  void _updateCurrentTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _loadRobotCleanerNotification() async {
    setState(() {
      _isLoading = true;
    });

    // 세탁기는 돌렸지만 로봇청소기를 돌리지 않고 1시간이 지난 경우 알림 표시
    await _checkRobotCleanerStatus();

    setState(() {
      _isLoading = false;
    });
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

  Future<void> _checkRobotCleanerStatus() async {
    try {
      // 백엔드 API에서 로봇청소기 알림 정보 가져오기
      List<String> urlsToTry = [baseUrl];
      if (!kIsWeb && Platform.isAndroid && ApiConfig.useEmulator == null) {
        urlsToTry = ApiConfig.getAndroidBaseUrls();
      }

      print('[CareScreen] 로봇청소기 알림 로딩 시작: ${urlsToTry.length}개 URL');
      bool requestSucceeded = false;
      
      for (int i = 0; i < urlsToTry.length; i++) {
        final url = urlsToTry[i];
        print('[CareScreen] 로봇청소기 알림 시도 ${i + 1}/${urlsToTry.length}: $url');
        try {
          final uri = Uri.parse(
            '$url/recommend/robot-cleaner-notification',
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
                const Duration(seconds: 10), // 실제 기기에서는 빠른 실패로 다음 URL 시도
                onTimeout: () {
                  throw Exception('요청 시간 초과');
                },
              );

          if (response.statusCode == 200) {
            final data =
                jsonDecode(utf8.decode(response.bodyBytes))
                    as Map<String, dynamic>;

            final hasNotification = data['has_notification'] as bool? ?? false;

            if (hasNotification && mounted) {
              final notification =
                  data['notification'] as Map<String, dynamic>?;

              print('[CareScreen] 알림 있음 - notification: $notification');

              if (notification != null) {
                setState(() {
                  final message = notification['message'] as String?;
                  final routineId =
                      notification['robot_cleaner_routine_id'] as int?;
                  if (message != null) {
                    _robotCleanerMessage = message;
                  } else {
                    // message가 없으면 기본 메시지 사용
                    _robotCleanerMessage =
                        '건조기를 안 돌린지 1시간이 넘었어요.\n지금 안돌리면 입을 옷이 없어요';
                  }
                  _robotCleanerRoutineId = routineId;
                });
              }
            } else {
              // 알림이 없으면 메시지 초기화
              if (mounted) {
                setState(() {
                  _robotCleanerMessage = null;
                });
              }
            }
            requestSucceeded = true;
            print('[CareScreen] 로봇청소기 알림 로딩 성공: $url (알림 있음: $hasNotification)');
            break; // 성공하면 종료
          } else {
            // HTTP 에러
            print(
              '[CareScreen] 로봇청소기 알림 HTTP 에러 ($url): ${response.statusCode}',
            );
            continue;
          }
        } catch (e) {
          // 연결 실패
          print('[CareScreen] 로봇청소기 알림 로딩 실패 ($url): $e');
          if (i == urlsToTry.length - 1) {
            // 마지막 URL도 실패
            print('[CareScreen] 로봇청소기 알림 로딩 실패 - 모든 URL 시도 완료');
          }
          continue;
        }
      }

      // 실제로 모든 URL 시도가 실패한 경우에만 실패 메시지 출력
      if (!requestSucceeded) {
        print('[CareScreen] 로봇청소기 알림 최종 실패: 모든 URL 연결 시도 완료');
      }
    } catch (e) {
      print('[CareScreen] 로봇청소기 알림 로딩 중 예외 발생: $e');
      // 에러 발생 시 알림 표시 안 함
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        // 왼쪽으로 스와이프 감지 (필요시 다른 화면으로 이동)
        if (details.primaryVelocity! < -500) {
          Navigator.pop(context);
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

                  // 알림 카드들 (시간/날짜 아래 적절한 간격으로 배치)
                  if (!_isLoading) ...[
                    // 로봇청소기 알림 카드
                    if (_robotCleanerMessage != null) ...[
                      const SizedBox(height: 50),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RobotPushScreen(
                                  routineId: _robotCleanerRoutineId,
                                ),
                              ),
                            );
                          },
                          child: _buildNotificationCard(
                            firstLine: _robotCleanerMessage != null
                                ? '지현님, ${_robotCleanerMessage!.split('\n').first}'
                                : '지현님, 로봇청소기를 실행시켜주세요',
                            secondLine:
                                _robotCleanerMessage != null &&
                                    _robotCleanerMessage!.split('\n').length > 1
                                ? _robotCleanerMessage!.split('\n')[1]
                                : '깨끗한 집을 위해 지금 실행시켜주세요',
                            timeLabel: '지금',
                          ),
                        ),
                      ),
                    ],
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
          // 아이콘 (ThinQ 아이콘)
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
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
