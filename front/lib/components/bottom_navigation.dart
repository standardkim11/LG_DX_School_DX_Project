// 하단바 아이콘 모아둔 곳

import 'package:flutter/material.dart';
import '../Screens/home_screen.dart';
import '../Screens/push_screen.dart';
import '../Screens/care_screen.dart';
import '../Screens/routine_screen.dart';

class CustomBottomNavigation extends StatelessWidget {
  final String? currentScreen; // 'home', 'routine', 'todo' 등

  const CustomBottomNavigation({super.key, this.currentScreen});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double screenWidth = constraints.maxWidth;
            const int iconCount = 5;
            const int gapCount = 6; // 양쪽 끝 포함
            const double iconSize = 50;
            const double totalIconWidth = iconCount * iconSize;
            final double totalGapWidth = screenWidth - totalIconWidth;
            final double gapWidth = totalGapWidth > 0
                ? totalGapWidth / gapCount
                : 0;

            return SizedBox(
              width: screenWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: gapWidth),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(),
                        ),
                        (route) => false, // 모든 이전 화면 제거
                      );
                    },
                    child: SizedBox(
                      width: iconSize,
                      height: iconSize,
                      child: Image.asset(
                        'assets/bottom_navigation_icon/Home_icon.png', // home_screen에서는 bottom_navigation을 사용하지 않으므로 항상 일반 아이콘
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        isAntiAlias: true,
                      ),
                    ),
                  ),
                  SizedBox(width: gapWidth),
                  SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: Image.asset(
                      'assets/bottom_navigation_icon/Device_icon.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      isAntiAlias: true,
                    ),
                  ),
                  SizedBox(width: gapWidth),
                  GestureDetector(
                    onTap: () {
                      // routine_screen이 아닌 경우에만 RoutineScreen으로 이동
                      if (currentScreen != 'routine') {
                        // RoutineScreen으로 이동 (현재 선택된 날짜는 RoutineScreen 내부에서 유지됨)
                        Navigator.pushAndRemoveUntil(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const RoutineScreen(),
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                          ),
                          (route) => false, // 모든 이전 화면 제거
                        );
                      }
                      // routine_screen에 이미 있으면 아무 동작도 하지 않음
                    },
                    child: SizedBox(
                      width: iconSize,
                      height: iconSize,
                      child: Image.asset(
                        'assets/bottom_navigation_icon/Routine_icon_bold.png', // bottom_navigation을 사용하는 화면에서는 항상 bold
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        isAntiAlias: true,
                      ),
                    ),
                  ),
                  SizedBox(width: gapWidth),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CareScreen(),
                        ),
                      );
                    },
                    child: SizedBox(
                      width: iconSize,
                      height: iconSize,
                      child: Image.asset(
                        'assets/bottom_navigation_icon/Care_icon.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        isAntiAlias: true,
                      ),
                    ),
                  ),
                  SizedBox(width: gapWidth),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PushScreen(),
                        ),
                      );
                    },
                    child: SizedBox(
                      width: iconSize,
                      height: iconSize,
                      child: Image.asset(
                        'assets/bottom_navigation_icon/Menu_icon.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        isAntiAlias: true,
                      ),
                    ),
                  ),
                  SizedBox(width: gapWidth),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
