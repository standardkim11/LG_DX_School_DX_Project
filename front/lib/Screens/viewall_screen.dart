import 'package:flutter/material.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/tab_bar.dart';
import '../components/date_card.dart';
import '../components/bottom_navigation.dart';
import 'routine_screen.dart';
import 'todo_screen.dart';
import 'dashboard_screen.dart';
import 'priority.dart';

class ViewAllScreen extends StatefulWidget {
  const ViewAllScreen({super.key});

  @override
  State<ViewAllScreen> createState() => _ViewAllScreenState();
}

class _ViewAllScreenState extends State<ViewAllScreen> {
  int _selectedTabIndex = 1; // routine 탭이 선택된 상태
  int _selectedDateIndex = 15; // 12일 금요일 (인덱스 15)
  late ScrollController _dateScrollController;

  @override
  void initState() {
    super.initState();
    _dateScrollController = ScrollController();
    // 초기 스크롤 위치를 저장된 날짜 인덱스로 설정 (중앙에 오도록)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate(context);
    });
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedDate([BuildContext? ctx]) {
    if (_dateScrollController.hasClients) {
      final contextToUse = ctx ?? context;
      final screenWidth = MediaQuery.of(contextToUse).size.width;
      final cardWidth = 64.0; // 카드 너비(60) + 좌우 마진(4)
      // 선택된 날짜를 중앙에 배치: (인덱스 * 카드너비) - (화면너비/2) + (카드너비/2)
      final scrollPosition =
          (_selectedDateIndex * cardWidth) -
          (screenWidth / 2) +
          (cardWidth / 2);
      _dateScrollController.animateTo(
        scrollPosition.clamp(
          0.0,
          _dateScrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<bool> _showConfirmDialog({VoidCallback? onConfirm}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        bool? selectedButton; // null: 아무것도 선택 안됨, true: YES, false: NO
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 40),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.backgroundWhite,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '선택을 그만하시겠습니까?',
                      style: AppTextStyles.sectionTitle(
                        context,
                      ).copyWith(fontSize: 18, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // YES 버튼
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedButton = true;
                              });
                              // 색상 변경을 보여주기 위해 약간의 지연 후 닫기
                              Future.delayed(
                                const Duration(milliseconds: 150),
                                () {
                                  if (context.mounted) {
                                    Navigator.of(context).pop(true);
                                    if (onConfirm != null) {
                                      onConfirm();
                                    } else {
                                      // viewall 화면에서 루틴 탭이 선택된 상태로 이동
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        PageRouteBuilder(
                                          pageBuilder:
                                              (
                                                context,
                                                animation,
                                                secondaryAnimation,
                                              ) => const RoutineScreen(),
                                          transitionDuration: Duration.zero,
                                          reverseTransitionDuration:
                                              Duration.zero,
                                        ),
                                        (route) => false, // 모든 이전 화면 제거
                                      );
                                    }
                                  }
                                },
                              );
                            },
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: selectedButton == true
                                    ? AppColors.textAccent
                                    : AppColors.backgroundGray,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'YES',
                                style: TextStyle(
                                  color: selectedButton == true
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontSize: 16,
                                  fontFamily: 'LG Smart_H',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // NO 버튼
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedButton = false;
                              });
                              // 색상 변경을 보여주기 위해 약간의 지연 후 닫기
                              Future.delayed(
                                const Duration(milliseconds: 150),
                                () {
                                  if (context.mounted) {
                                    Navigator.of(context).pop(false);
                                  }
                                },
                              );
                            },
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: selectedButton == false
                                    ? AppColors.textAccent
                                    : AppColors.backgroundGray,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'NO',
                                style: TextStyle(
                                  color: selectedButton == false
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontSize: 16,
                                  fontFamily: 'LG Smart_H',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    return result ?? false;
  }

  Future<bool> _onWillPop() async {
    return await _showConfirmDialog();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundGray,
        body: SafeArea(
          child: Stack(
            children: [
              // 메인 콘텐츠
              Column(
                children: [
                  // 상단 인사말
                  _buildGreeting(context),
                  const SizedBox(height: 10),

                  // 탭 바
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: CustomTabBar(
                      selectedIndex: _selectedTabIndex,
                      onTabChanged: (index) {
                        // 모든 탭 클릭 시 확인 다이얼로그 표시 (루틴 탭 포함)
                        _showConfirmDialog(
                          onConfirm: () {
                            if (index == 0) {
                              // 투두 탭 클릭 시 투두 화면으로 이동
                              Navigator.pushAndRemoveUntil(
                                context,
                                PageRouteBuilder(
                                  pageBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                      ) => const TodoScreen(),
                                  transitionDuration: Duration.zero,
                                  reverseTransitionDuration: Duration.zero,
                                ),
                                (route) => false, // 모든 이전 화면 제거
                              );
                            } else if (index == 1) {
                              // 루틴 탭 클릭 시 루틴 화면으로 이동 (날짜 리셋)
                              resetRoutineScreenDate();
                              Navigator.pushAndRemoveUntil(
                                context,
                                PageRouteBuilder(
                                  pageBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                      ) => const RoutineScreen(),
                                  transitionDuration: Duration.zero,
                                  reverseTransitionDuration: Duration.zero,
                                ),
                                (route) => false, // 모든 이전 화면 제거
                              );
                            } else if (index == 2) {
                              // dashboard 탭 클릭 시 대시보드 화면으로 이동
                              Navigator.pushAndRemoveUntil(
                                context,
                                PageRouteBuilder(
                                  pageBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                      ) => const DashboardScreen(),
                                  transitionDuration: Duration.zero,
                                  reverseTransitionDuration: Duration.zero,
                                ),
                                (route) => false, // 모든 이전 화면 제거
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 날짜 캘린더
                  _buildDateCalendar(context),
                  const SizedBox(height: 15),

                  // 루틴 카드 섹션
                  Expanded(
                    child: SingleChildScrollView(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(bottom: 100),
                        decoration: const BoxDecoration(
                          color: AppColors.backgroundGray,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 섹션 제목
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                child: Text(
                                  '나의 루틴 목록',
                                  style: AppTextStyles.sectionTitle(context),
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

                  // 하단 네비게이션
                  const CustomBottomNavigation(currentScreen: 'routine'),
                ],
              ),

              // 선택 완료 버튼 (네비게이션 바 위에 고정)
              Positioned(
                left: 0,
                right: 0,
                bottom: 60 + MediaQuery.of(context).padding.bottom,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundGray,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      // 선택 완료 로직 - priority 화면으로 이동
                      Navigator.pushAndRemoveUntil(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  PriorityScreen(),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                        ),
                        (route) => false, // 모든 이전 화면 제거
                      );
                    },
                    child: Container(
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.textAccent,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        '선택 완료',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, top: 50),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('지현님, 반가워요!', style: AppTextStyles.greetingTitle(context)),
            const SizedBox(height: 8),
            Text(
              '오늘도 함께 습관을 만들어봐요',
              style: AppTextStyles.greetingSubtitle(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateCalendar(BuildContext context) {
    // 기준일: 12일 금요일 찾기
    final now = DateTime.now();
    final baseDate = DateTime(now.year, now.month, 12);
    // 금요일은 weekday 5, 현재 12일의 요일을 확인하고 금요일로 조정
    final currentWeekday = baseDate.weekday; // 1=월요일, 7=일요일
    final daysUntilFriday = (5 - currentWeekday + 7) % 7;
    final referenceDate = baseDate.add(Duration(days: daysUntilFriday));

    // 앞뒤로 15일씩만 생성 (총 31일: 15일 전부터 15일 후까지)
    final dates = List.generate(31, (index) {
      final date = referenceDate.add(
        Duration(days: index - 15),
      ); // 15일 전부터 15일 후까지
      final weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
      return {
        'day': date.day,
        'label': weekdays[date.weekday - 1], // weekday는 1-7
        'date': date,
      };
    });

    return SizedBox(
      height: 80,
      child: ListView.builder(
        controller: _dateScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 1),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = index == _selectedDateIndex;
          return GestureDetector(
            onTap: () {
              // 다른 날짜 선택 시 확인 다이얼로그 표시
              if (index != _selectedDateIndex) {
                final selectedIndex = index; // 클로저에서 사용하기 위해 변수에 저장
                _showConfirmDialog(
                  onConfirm: () {
                    // 선택한 날짜로 설정하고 루틴 화면으로 이동
                    setRoutineScreenDate(selectedIndex);
                    Navigator.pushAndRemoveUntil(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const RoutineScreen(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                      (route) => false, // 모든 이전 화면 제거
                    );
                  },
                );
              } else {
                // 같은 날짜 선택 시 그냥 스크롤만
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToSelectedDate(context);
                });
              }
            },
            child: Container(
              width: 60,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: DateCard(
                day: date['day'] as int,
                label: date['label'] as String,
                isSelected: isSelected,
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildRoutineCards() {
    return [
      // 첫 번째 행
      Row(
        children: [
          Expanded(
            child: _buildRoutineCard(
              title: '귀가 전 바닥 청소하기',
              time: '17:30',
              bottomBadgeText: '수정',
              bottomBadgeColor: const Color(0xFF4B57BB),
              isChecked: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildRoutineCard(
              title: '아침에 물 마시기',
              time: '8시까지 완료하기',
              bottomBadgeText: '수정',
              bottomBadgeColor: const Color(0xFF4B57BB),
              isChecked: false,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      // 두 번째 행
      Row(
        children: [
          Expanded(
            child: _buildRoutineCard(
              title: '로봇청소기 물청소하기',
              time: '13:00(화, 목)',
              bottomBadgeText: '수정',
              bottomBadgeColor: const Color(0xFF4B57BB),
              isChecked: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildRoutineCard(
              title: '건조기 돌리기',
              time: '2/4',
              bottomBadgeText: '수정',
              bottomBadgeColor: const Color(0xFF4B57BB),
              isChecked: true,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      // 세 번째 행
      Row(
        children: [
          Expanded(
            child: _buildRoutineCard(
              title: '세탁기 돌리기',
              time: '2/4',
              bottomBadgeText: '수정',
              bottomBadgeColor: const Color(0xFF4B57BB),
              isChecked: true,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: SizedBox()), // 빈 공간
        ],
      ),
    ];
  }

  Widget _buildRoutineCard({
    required String title,
    required String time,
    String? bottomBadgeText,
    Color? bottomBadgeColor,
    required bool isChecked,
  }) {
    return Container(
      width: double.infinity,
      height: 88,
      decoration: ShapeDecoration(
        color: AppColors.backgroundWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 17, 17, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: ShapeDecoration(
                        color: isChecked
                            ? AppColors.textAccent
                            : Colors.transparent,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            width: isChecked ? 0 : 1,
                            color: isChecked
                                ? AppColors.textAccent
                                : AppColors.textUnselected,
                          ),
                        ),
                      ),
                      child: isChecked
                          ? const Center(
                              child: Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.todoTitle(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 26),
                  child: Text(time, style: AppTextStyles.todoCategory(context)),
                ),
              ],
            ),
          ),
          if (bottomBadgeText != null)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: ShapeDecoration(
                  color: bottomBadgeColor ?? const Color(0xFF6065BB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  bottomBadgeText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontFamily: 'LG Smart_H',
                    fontWeight: FontWeight.w400,
                    height: 2.50,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
