import 'package:flutter/material.dart';

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
              'assets/Home.png', // 실제 파일명/경로에 맞게
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
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset('assets/Home_icon.png', height: 28),
                    Image.asset('assets/Device_icon.png', height: 28),
                    Image.asset('assets/Routine_icon.png', height: 28),
                    Image.asset('assets/Care_icon.png', height: 28),
                    Image.asset('assets/Menu_icon.png', height: 28),
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
