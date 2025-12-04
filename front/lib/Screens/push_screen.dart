import 'package:flutter/material.dart';
import '../services/context_event_service.dart';
import 'routine_screen.dart';
import 'dart:async';

class PushScreen extends StatefulWidget {
  const PushScreen({super.key});

  @override
  State<PushScreen> createState() => _PushScreenState();
}

class _PushScreenState extends State<PushScreen> {
  String? _latenessMessage;
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
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    super.dispose();
  }

  void _updateCurrentTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _loadContextEvent() async {
    // 테스트용 위치 (실제로는 GPS에서 가져와야 함)
    // 사용자 집 위치 근처로 설정 (예: 서울시청 좌표)
    const double testLat = 37.5665;
    const double testLng = 126.9780;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ContextEventService.getContextEvent(
        currentLat: testLat,
        currentLng: testLng,
      );

      if (response != null && response['triggered'] == true) {
        final latenessMinutes = response['lateness_minutes'] as int? ?? 0;
        
        // 메시지 생성
        String message;
        if (latenessMinutes > 0) {
          message = '평소보다 귀가가 ${latenessMinutes}분 늦었네요';
        } else if (latenessMinutes < 0) {
          message = '평소보다 귀가가 ${-latenessMinutes}분 빠르시네요';
        } else {
          message = '오늘은 평소와 거의 비슷한 시간에 귀가 중이에요';
        }

        setState(() {
          _latenessMessage = message;
          _isLoading = false;
        });
      } else {
        // API가 triggered=false를 반환하거나 오류 발생 시 기본 메시지
        setState(() {
          _latenessMessage = '오늘은 평소와 거의 비슷한 시간에 귀가 중이에요';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading context event: $e');
      setState(() {
        _latenessMessage = '오늘은 평소와 거의 비슷한 시간에 귀가 중이에요';
        _isLoading = false;
      });
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
              ),
            ),

            // 상단 시간 표시
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        _currentTime,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'LG Smart_H',
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
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 알림 카드들
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 첫 번째 알림 카드
                  if (!_isLoading && _latenessMessage != null)
                    _buildNotificationCard(
                      icon: Icons.home,
                      message: '지현님, $_latenessMessage',
                      timeLabel: '지금',
                    ),
                  const SizedBox(height: 12),
                  // 두 번째 알림 카드
                  if (!_isLoading)
                    _buildNotificationCard(
                      icon: Icons.home,
                      message: '지현님, 해야하는 루틴 추천 해드릴께요.',
                      timeLabel: _getTimeAgoLabel(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required IconData icon,
    required String message,
    required String timeLabel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 아이콘 (빨간색 배경)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFF3132), // 빨간색
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // 메시지와 시간
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'LG Smart_H',
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    timeLabel,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'LG Smart_H',
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

  String _getTimeAgoLabel() {
    // 첫 번째 알림이 "지금"이므로 두 번째는 "10분 전" 같은 형식
    // 실제로는 API 응답 시간과의 차이를 계산해야 하지만,
    // 현재는 고정값으로 설정
    return '10분 전';
  }
}

