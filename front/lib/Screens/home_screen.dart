import 'package:flutter/material.dart';
import 'lgrouthinq.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1) 전체 배경 Home.png
          Positioned.fill(
            child: Image.asset(
              'assets/home_screen/MainHome.png',
              fit: BoxFit.cover,
            ),
          ),

          // 2) 맨 아래 PNG로 만든 네비게이션 바
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 홈 아이콘 (비활성화)
                    Image.asset(
                      'assets/bottom_navigation_icon/home.png',
                      height: 48,
                    ),
                    // 디바이스 아이콘 (비활성화)
                    Image.asset(
                      'assets/bottom_navigation_icon/device.png',
                      height: 48,
                    ),
                    // 루틴 아이콘 (활성화 - 클릭 가능)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RoutineScreen(),
                          ),
                        );
                      },
                      child: Image.asset(
                        'assets/bottom_navigation_icon/routine.png',
                        height: 48,
                      ),
                    ),
                    // 케어 아이콘 (비활성화)
                    Image.asset(
                      'assets/bottom_navigation_icon/care.png',
                      height: 48,
                    ),
                    // 메뉴 아이콘 (비활성화)
                    Image.asset(
                      'assets/bottom_navigation_icon/menu.png',
                      height: 48,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
