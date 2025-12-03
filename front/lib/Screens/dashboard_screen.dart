import 'package:flutter/material.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/tab_bar.dart';
import '../components/bottom_navigation.dart';
import 'todo_screen.dart';
import 'routine_screen.dart';

// 상수
class _DashboardConstants {
  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x0F222C5C),
    blurRadius: 68,
    offset: Offset(58, 26),
    spreadRadius: 0,
  );
}

// 통계 카드 위젯
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final double? labelFontSize;
  final double? valueFontSize;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.labelFontSize,
    this.valueFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textUnselected,
              fontSize: labelFontSize ?? 10,
              fontFamily: 'LG Smart_H',
              fontWeight: FontWeight.w700,
              height: 2.40,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textSecondary,
              fontSize: valueFontSize ?? 20,
              fontFamily: 'LG Smart_H',
              fontWeight: FontWeight.w400,
              height: 1.20,
            ),
          ),
        ],
      ),
    );
  }
}

// 경쟁 카드 위젯
class CompetitionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress;
  final int participantCount;
  final String? friendImagePath;

  const CompetitionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.participantCount,
    this.friendImagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: ShapeDecoration(
        color: AppColors.textSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontFamily: 'LG Smart_H',
                  fontWeight: FontWeight.w700,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'LG Smart_H',
                  fontWeight: FontWeight.w400,
                  height: 1.50,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 4,
                decoration: ShapeDecoration(
                  color: AppColors.textSelected,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 4,
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (friendImagePath != null)
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: ShapeDecoration(
                    image: DecorationImage(
                      image: AssetImage(friendImagePath!),
                      fit: BoxFit.cover,
                    ),
                    shape: OvalBorder(
                      side: const BorderSide(width: 1, color: Colors.white),
                    ),
                  ),
                ),
              Text(
                '친구 $participantCount명이 참여 중',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'LG Smart_H',
                  fontWeight: FontWeight.w400,
                  height: 1.20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedTabIndex = 2;

  void _onTabChanged(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const TodoScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const RoutineScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } else {
      setState(() {
        _selectedTabIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, top: 70),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '지현님, 반가워요!',
                        style: AppTextStyles.greetingTitle(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '오늘도 함께 습관을 만들어봐요',
                        style: AppTextStyles.greetingSubtitle(context),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: CustomTabBar(
                  selectedIndex: _selectedTabIndex,
                  onTabChanged: _onTabChanged,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: ShapeDecoration(
                    color: AppColors.backgroundWhite,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(
                        width: 1,
                        color: AppColors.borderLight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    shadows: [_DashboardConstants.cardShadow],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '12월 루틴 진행 사항',
                        style: AppTextStyles.tabUnselected(
                          context,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: [
                          Row(
                            children: [
                              StatCard(
                                label: '성공률',
                                value: '84%',
                                labelFontSize: 15,
                                valueFontSize: 24,
                              ),
                              StatCard(
                                label: '완료한 루틴 수',
                                value: '32',
                                labelFontSize: 15,
                                valueFontSize: 24,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              StatCard(
                                label: '미룬 루틴 수',
                                value: '4',
                                labelFontSize: 15,
                                valueFontSize: 24,
                              ),
                              StatCard(
                                label: '실패한 루틴 수',
                                value: '2',
                                valueColor: const Color(0xFFFF3132),
                                labelFontSize: 15,
                                valueFontSize: 24,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '누가 더 루틴을 잘 지키나 경쟁해요',
                            style: AppTextStyles.sectionTitle(
                              context,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text('VIEW ALL', style: AppTextStyles.viewAll(context)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 140,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          CompetitionCard(
                            title: '미라클모닝',
                            subtitle: '6시 전에 정수기 사용하기',
                            progress: 0.19,
                            participantCount: 2,
                            friendImagePath:
                                'assets/routine_screen/friends1.png',
                          ),
                          const SizedBox(width: 12),
                          CompetitionCard(
                            title: '뽀득뽀득 우리집',
                            subtitle: '주 3회 물청소하기',
                            progress: 0.55,
                            participantCount: 1,
                            friendImagePath:
                                'assets/routine_screen/friends2.png',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavigation(currentScreen: 'routine'),
    );
  }
}
