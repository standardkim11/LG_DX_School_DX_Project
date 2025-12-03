// 하단바 아이콘 모아둔 곳

import 'package:flutter/material.dart';

class CustomBottomNavigation extends StatelessWidget {
  const CustomBottomNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
            // 홈 아이콘
            Image.asset('assets/bottom_navigation_icon/home.png', height: 48),
            // 디바이스 아이콘
            Image.asset('assets/bottom_navigation_icon/device.png', height: 48),
            // 루틴 아이콘
            Image.asset(
              'assets/bottom_navigation_icon/routine.png',
              height: 48,
            ),
            // 케어 아이콘
            Image.asset('assets/bottom_navigation_icon/care.png', height: 48),
            // 메뉴 아이콘
            Image.asset('assets/bottom_navigation_icon/menu.png', height: 48),
          ],
        ),
      ),
    );
  }
}
