import 'package:flutter/material.dart';
import 'dart:async';
import 'robotpush_screen.dart';

class CareScreen extends StatefulWidget {
  const CareScreen({super.key});

  @override
  State<CareScreen> createState() => _CareScreenState();
}

class _CareScreenState extends State<CareScreen> {
  String? _robotCleanerMessage;
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

  Future<void> _checkRobotCleanerStatus() async {
    try {
      // 실제로는 백엔드 API에서 세탁기 실행 시간과 로봇청소기 실행 시간을 비교해야 함
      // 여기서는 시뮬레이션으로 1시간 이상 지났다고 가정
      const bool washerCompleted = true; // 세탁기는 완료됨
      const bool robotCleanerNotRun = true; // 로봇청소기는 아직 실행 안 함
      const int hoursPassed = 1; // 1시간 경과

      if (washerCompleted && robotCleanerNotRun && hoursPassed >= 1) {
        setState(() {
          _robotCleanerMessage =
              '로봇청소기를 안 돌린지 1시간이 넘었어요.\n깨끗한 집을 위해 지금 실행시켜주세요';
        });
      }
    } catch (e) {
      print('Error loading robot cleaner notification: $e');
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
                                builder: (context) => const RobotPushScreen(),
                              ),
                            );
                          },
                          child: _buildNotificationCard(
                            icon: Icons.home,
                            message: '지현님, $_robotCleanerMessage',
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
    IconData? icon,
    required String message,
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
          // 아이콘 (빨간색 배경) - icon이 null이 아닐 때만 표시
          if (icon != null) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3132), // 빨간색
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
          ],
          // 메시지와 시간
          Expanded(
            child: Stack(
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'LG Smart_H',
                      height: 1.5,
                      letterSpacing: -0.2,
                    ),
                    children: [
                      TextSpan(
                        text: '지현님',
                        style: const TextStyle(fontSize: 12),
                      ),
                      TextSpan(text: message.replaceFirst('지현님', '')),
                    ],
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
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
                ),
              ],
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
