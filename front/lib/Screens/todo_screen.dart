import 'package:flutter/material.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/tab_bar.dart';
import '../components/date_card.dart';
import '../components/bottom_navigation.dart';
import '../components/habit_card.dart';
import 'routine_screen.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  int _selectedTabIndex = 0;

  final List<Map<String, dynamic>> _todos = [
    {
      'title': '18:00 지나랑 밥 🍚',
      'category': '친구',
      'isHighlighted': true,
      'checkType': 'none',
    },
    {
      'title': '피그마 복습하기',
      'category': '공부',
      'isHighlighted': true,
      'checkType': 'none',
    },
    {
      'title': '다이소에서 신상키링 사기',
      'category': '취미',
      'isHighlighted': false,
      'checkType': 'done',
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
                      if (index == 1) {
                        // routine 탭 클릭 시 화면 전환
                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => const RoutineScreen(),
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
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
                const CustomBottomNavigation(currentScreen: 'todo'),
              ],
            ),

            // 일정 추가하기 바
            Positioned(
              left: 10,
              right: 10,
              bottom: bottomNavHeight - 10,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  image: const DecorationImage(
                    image: AssetImage('assets/todo_screen/bar.png'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: const Center(
                  child: Text(
                    '일정 추가하기',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
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
                Text('오늘 할 일', style: AppTextStyles.sectionTitle(context)),
                Text('VIEW ALL', style: AppTextStyles.viewAll(context)),
              ],
            ),
          ),

          // 할 일 리스트 (스크롤 없음)
          Column(
            children: _todos
                .map(
                  (todo) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TodoItemCard(
                      title: todo['title'] as String,
                      category: todo['category'] as String,
                      isHighlighted: todo['isHighlighted'] as bool,
                      checkType: todo['checkType'] as String,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
