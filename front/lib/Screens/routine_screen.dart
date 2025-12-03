import 'package:flutter/material.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/tab_bar.dart';
import '../components/date_card.dart';
import '../components/bottom_navigation.dart';
import '../components/habit_card.dart';
import 'todo_screen.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  int _selectedTabIndex = 1; // routine 탭이 선택된 상태

  final List<Map<String, dynamic>> _todos = [
    {
      'title': '로봇청소기 물청소하기',
      'category': '주 1회',
      'isHighlighted': true,
      'checkType': 'none',
    },
    {
      'title': '이불 빨래 하기',
      'category': '2주 1회',
      'isHighlighted': true,
      'checkType': 'none',
    },
    {
      'title': '아침에 물 마시기',
      'category': '8:00까지 완료하기',
      'isHighlighted': true,
      'checkType': 'none',
    },
  ];

  @override
  Widget build(BuildContext context) {
    // BottomNavigationBar 높이 (SafeArea 포함)
    final bottomNavHeight = 60.0 + MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: SafeArea(
        child: Stack(
          children: [
            // 메인 콘텐츠
            Column(
              children: [
                // 상단 인사말
                _buildGreeting(context),
                const SizedBox(height: 16),

                // 탭 바
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: CustomTabBar(
                    selectedIndex: _selectedTabIndex,
                    onTabChanged: (index) {
                      if (index == 0) {
                        // to-do 탭 클릭 시 todo_screen으로 전환
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TodoScreen(),
                          ),
                        );
                      } else {
                        setState(() {
                          _selectedTabIndex = index;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // 날짜 캘린더
                _buildDateCalendar(context),
                const SizedBox(height: 25),

                // 할 일 섹션
                Expanded(child: _buildTodoSection(context)),

                // 하단 네비게이션
                const CustomBottomNavigation(),
              ],
            ),

            // 루틴 생성하기 바
            RoutineCreateBar(bottomNavHeight: bottomNavHeight),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, top: 70),
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
    final dates = [
      {'day': 2, 'label': 'RI', 'isSelected': false},
      {'day': 3, 'label': 'SAT', 'isSelected': true},
      {'day': 4, 'label': 'SUN', 'isSelected': false},
      {'day': 5, 'label': 'MON', 'isSelected': false},
      {'day': 6, 'label': 'TUE', 'isSelected': false},
      {'day': 7, 'label': 'WED', 'isSelected': false},
      {'day': 8, 'label': 'THU', 'isSelected': false},
      {'day': 9, 'label': 'FRI', 'isSelected': false},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Row(
        children: dates
            .map(
              (date) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: DateCard(
                    day: date['day'] as int,
                    label: date['label'] as String,
                    isSelected: date['isSelected'] as bool,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTodoSection(BuildContext context) {
    // 하단 네비게이션과 루틴 생성하기 바 높이 계산
    final bottomNavHeight = 30.0 + MediaQuery.of(context).padding.bottom;
    final routineBarHeight = 10.0;
    final bottomPadding = bottomNavHeight + routineBarHeight + 5; // 여유 공간 추가

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 헤더
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Habits', style: AppTextStyles.sectionTitle(context)),
                Text('VIEW ALL', style: AppTextStyles.viewAll(context)),
              ],
            ),
          ),

          // 할 일 리스트 (스크롤 가능)
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: bottomPadding),
              children: [
                ..._todos.asMap().entries.map((entry) {
                  final index = entry.key;
                  final todo = entry.value;
                  // 첫번째 카드: friends.png, 두번째 카드: friends1.png, 세번째 카드: friends2.png
                  final friendIcons = [
                    'assets/routine_screen/friends.png',
                    'assets/routine_screen/friends1.png',
                    'assets/routine_screen/friends2.png',
                  ];
                  final friendIcon = index < friendIcons.length
                      ? friendIcons[index]
                      : null;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TodoItemCard(
                      title: todo['title'] as String,
                      category: todo['category'] as String,
                      isHighlighted: todo['isHighlighted'] as bool,
                      checkType: todo['checkType'] as String,
                      friendIcon: friendIcon,
                      friendIconSizes: {
                        'assets/routine_screen/friends.png': 60,
                        'assets/routine_screen/friends1.png': 40,
                        'assets/routine_screen/friends2.png': 26,
                      },
                    ),
                  );
                }),
                // HabitCard
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: HabitCard(
                    subtitle: '습관 형성까지 16일 남았어요',
                    title: '아침에 물 마시기💧',
                    progress: 0.75,
                  ),
                ),
                // chat.png 플로팅 버튼
                Positioned(
                  right: 20,
                  bottom: bottomNavHeight + 60,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/todo_screen/chat.png',
                        width: 45,
                        height: 45,
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
}
