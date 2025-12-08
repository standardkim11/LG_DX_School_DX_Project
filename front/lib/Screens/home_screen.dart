import 'package:flutter/material.dart';
import 'lgrouthinq.dart' as lg;
import 'push_screen.dart';

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
              'assets/home_screen/MainHome.png', // 실제 파일명/경로에 맞게
              fit: BoxFit.cover,
            ),
          ),

          // 2) 맨 아래 PNG로 만든 네비게이션 바
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
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
                          SizedBox(
                            width: iconSize,
                            height: iconSize,
                            child: Image.asset(
                              'assets/bottom_navigation_icon/Home_icon_bold.png',
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              isAntiAlias: true,
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
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const lg.RoutineScreen(),
                                ),
                              );
                            },
                            child: SizedBox(
                              width: iconSize,
                              height: iconSize,
                              child: Image.asset(
                                'assets/bottom_navigation_icon/Routine_icon.png',
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
                              'assets/bottom_navigation_icon/Care_icon.png',
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              isAntiAlias: true,
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
            ),
          ),
        ],
      ),
    );
  }
}
