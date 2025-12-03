import 'package:flutter/material.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/routine_card.dart';
import '../components/viewall_date_card.dart';
import '../components/tab_bar.dart';
import '../components/greeting_header.dart';
import 'routine_screen.dart';

class ViewAllScreen extends StatelessWidget {
  const ViewAllScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: SafeArea(
        child: Column(
      children: [
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: 20),
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundGray,
                  ),
                  child: SizedBox(
                    height: 700,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 헤더
              Positioned(
                          left: 16,
                          top: 58,
                          child: GreetingHeader(
                            name: '지현',
                            subtitle: '오늘도 함께 습관을 만들어봐요',
                          ),
                        ),

                        // 탭 바
              Positioned(
                left: 7,
                          top: 121,
                          child: CustomTabBar(
                            selectedIndex: 1,
                            onTabChanged: (index) {
                              if (index == 0) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const RoutineScreen(),
                                  ),
                                );
                              } else if (index == 2) {
                                // dashboard로 이동하는 로직 추가 필요
                              }
                            },
                          ),
                        ),

                        // 날짜 카드
              Positioned(
                left: 48.25,
                top: 170,
                          child: SizedBox(
                  width: 345,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                                ViewAllDateCard(day: 2, label: 'RI', width: 31),
                                ViewAllDateCard(day: 3, label: 'SAT'),
                                ViewAllDateCard(
                                  day: 4,
                                  label: 'SUN',
                                  isSelected: true,
                                ),
                                ViewAllDateCard(day: 5, label: 'MON'),
                                ViewAllDateCard(day: 6, label: 'TUE'),
                                ViewAllDateCard(day: 7, label: 'WED'),
                                ViewAllDateCard(day: 8, label: 'THU'),
                                ViewAllDateCard(day: 9, label: 'FRI'),
                          ],
                        ),
                      ),
                        ),

                        // 섹션 제목
                        Positioned(
                          left: 9,
                          top: 287,
                              child: Text(
                            '나의 루틴 목록',
                            style: AppTextStyles.routineListTitle(context),
                          ),
                        ),

                        // 루틴 카드들
                        ..._buildRoutineCards(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 선택 완료 버튼
                      Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(color: AppColors.backgroundGray),
              child: ElevatedButton(
                onPressed: () {
                  // 선택 완료 로직
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '선택 완료',
                                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                                  fontFamily: 'LG Smart_H',
                                  fontWeight: FontWeight.w600,
                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
    );
  }

  List<Widget> _buildRoutineCards() {
    return [
      // 첫 번째 행
      RoutineCard(
        title: '귀가 전 바닥 청소하기',
        time: '17:30',
        bottomBadgeText: '사용자 수정',
        bottomBadgeColor: const Color(0xFF4B57BB),
        left: 9,
        top: 323,
        isChecked: true,
      ),
      RoutineCard(
        title: '아침에 물 마시기',
        time: '8시까지 완료하기',
        bottomBadgeText: '사용자 수정',
        bottomBadgeColor: const Color(0xFF4B57BB),
        left: 182,
        top: 323,
        isChecked: false,
      ),
      // 두 번째 행
      RoutineCard(
        title: '로봇청소기 물청소하기',
        time: '13:00(화, 목)',
        bottomBadgeText: '사용자 수정',
        bottomBadgeColor: const Color(0xFF4B57BB),
        left: 9,
        top: 432,
        isChecked: true,
      ),
      RoutineCard(
        title: '건조기 돌리기',
        time: '2/4',
        bottomBadgeText: '사용자 수정',
        bottomBadgeColor: const Color(0xFF4B57BB),
        left: 182,
        top: 432,
        isChecked: true,
      ),
      // 세 번째 행
      RoutineCard(
        title: '세탁기 돌리기',
        time: '2/4',
        bottomBadgeText: '사용자 수정',
        bottomBadgeColor: const Color(0xFF4B57BB),
        left: 9,
        top: 541,
        isChecked: true,
      ),
    ];
  }
}
