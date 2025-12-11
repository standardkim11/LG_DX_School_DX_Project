import 'package:flutter/material.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/tab_bar.dart';
import '../components/date_card.dart';
import '../components/bottom_navigation.dart';
import '../components/habit_card.dart';
import '../components/add_todo_modal.dart';
import 'routine_screen.dart';
import 'dashboard_screen.dart';
import 'chat_screen.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

// 전역 상태 관리
class _TodoScreenStateManager {
  static int _selectedDateIndex = 15;
  static Map<String, String> _checkStates = {}; // 체크 상태 저장
  static Map<String, List<Map<String, dynamic>>> _todosByDate =
      {}; // 날짜별 todo 목록

  static int get selectedDateIndex => _selectedDateIndex;
  static set selectedDateIndex(int value) => _selectedDateIndex = value;

  static String? getCheckState(String key) => _checkStates[key];
  static void setCheckState(String key, String? value) {
    if (value == null) {
      _checkStates.remove(key);
    } else {
      _checkStates[key] = value;
    }
  }

  // 날짜별 todo 목록 관리
  static Map<String, List<Map<String, dynamic>>> get todosByDate =>
      Map<String, List<Map<String, dynamic>>>.from(_todosByDate);
  static void setTodosByDate(Map<String, List<Map<String, dynamic>>> todos) {
    _todosByDate = Map<String, List<Map<String, dynamic>>>.from(todos);
  }

  // 특정 날짜의 todo 목록 가져오기
  static List<Map<String, dynamic>> getTodosForDate(String dateKey) {
    return List<Map<String, dynamic>>.from(_todosByDate[dateKey] ?? []);
  }
}

// 외부에서 접근 가능한 함수
List<Map<String, dynamic>> getTodosForDate(String dateKey) {
  return _TodoScreenStateManager.getTodosForDate(dateKey);
}

// 외부에서 todo를 추가할 수 있는 함수
void addTodoToDate(String dateKey, Map<String, dynamic> todo) {
  final todosByDate = Map<String, List<Map<String, dynamic>>>.from(
    _TodoScreenStateManager.todosByDate,
  );

  if (todosByDate.containsKey(dateKey)) {
    todosByDate[dateKey]!.add(todo);
  } else {
    todosByDate[dateKey] = [todo];
  }

  _TodoScreenStateManager.setTodosByDate(todosByDate);
}

class _TodoScreenState extends State<TodoScreen> {
  int _selectedTabIndex = 0;
  int _selectedDateIndex = _TodoScreenStateManager.selectedDateIndex;
  late ScrollController _dateScrollController;

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

  // 날짜별 할 일 관리 (날짜 키: "YYYY-MM-DD" 형식)
  Map<String, List<Map<String, dynamic>>> _todosByDate = {};

  // 현재 선택된 날짜의 할 일 목록
  List<Map<String, dynamic>> get _todos {
    final selectedDate = _getSelectedDate();
    final dateKey = _formatDateKey(selectedDate);
    return _todosByDate[dateKey] ?? [];
  }

  set _todos(List<Map<String, dynamic>> value) {
    final selectedDate = _getSelectedDate();
    final dateKey = _formatDateKey(selectedDate);
    _todosByDate[dateKey] = value;
  }

  // 선택된 날짜 가져오기
  DateTime _getSelectedDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 오늘 날짜를 기준으로 인덱스 15로 설정했으므로, 오늘부터 계산
    return today.add(Duration(days: _selectedDateIndex - 15));
  }

  // 날짜를 키 형식으로 변환
  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getTodoKey(Map<String, dynamic> todo) {
    return '${todo['title']}_${todo['category']}';
  }

  @override
  void initState() {
    super.initState();
    _dateScrollController = ScrollController();

    // 항상 오늘 날짜 인덱스(15)로 설정
    _TodoScreenStateManager.selectedDateIndex = 15;
    _selectedDateIndex = 15;

    // 전역 상태에서 todo 목록 복원
    _todosByDate = Map<String, List<Map<String, dynamic>>>.from(
      _TodoScreenStateManager.todosByDate,
    );

    // 오늘 날짜 계산
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateKeyToday = _formatDateKey(today); // 오늘 날짜 키

    // 오늘 날짜에 기본 todo가 없으면 추가
    if (!_todosByDate.containsKey(dateKeyToday) ||
        _todosByDate[dateKeyToday]!.isEmpty) {
      _todosByDate[dateKeyToday] = [
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
      // 전역 상태도 업데이트
      _TodoScreenStateManager.setTodosByDate(_todosByDate);
    }

    // 저장된 체크 상태 복원
    final selectedDate = _getSelectedDate();
    final selectedDateKey = _formatDateKey(selectedDate);
    final todos = _todosByDate[selectedDateKey] ?? [];
    for (var todo in todos) {
      final key = _getTodoKey(todo);
      final savedState = _TodoScreenStateManager.getCheckState(key);
      if (savedState != null) {
        todo['checkType'] = savedState;
      }
    }

    // 초기 스크롤 위치를 저장된 날짜 인덱스로 설정 (중앙에 오도록)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate(context);
    });
  }

  void _showAddTodoModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const AddTodoModal(),
      ),
    ).then((result) {
      if (result != null) {
        // 일정 추가 로직
        final selectedDate = _getSelectedDate();
        final dateKey = _formatDateKey(selectedDate);
        // 시간 정보 포함하여 제목 생성
        String title = result['title'] as String;
        final time = result['time'] as String?;
        if (time != null && time.isNotEmpty) {
          title = '$time $title';
        }

        final newTodo = {
          'title': title,
          'category': result['category'] as String? ?? '기타',
          'isHighlighted': true,
          'checkType': 'none',
        };

        setState(() {
          if (_todosByDate.containsKey(dateKey)) {
            _todosByDate[dateKey]!.add(newTodo);
          } else {
            _todosByDate[dateKey] = [newTodo];
          }
          // 전역 상태도 업데이트
          _TodoScreenStateManager.setTodosByDate(_todosByDate);
        });
      }
    });
  }

  /// todo 수정 모달 열기
  void _showEditTodoModal(
    BuildContext context,
    Map<String, dynamic> todo,
    int originalIndex,
  ) {
    // todo의 title에서 시간과 제목 분리
    // 형식: "18:30 장보기" 또는 "장보기"
    String? initialTime;
    String initialTitle = todo['title'] as String;
    
    // 시간 패턴 찾기 (예: "18:30 " 또는 "18:30")
    final timePattern = RegExp(r'^(\d{2}:\d{2})\s+(.+)$');
    final match = timePattern.firstMatch(initialTitle);
    if (match != null) {
      initialTime = match.group(1);
      initialTitle = match.group(2)!;
    }
    
    final initialCategory = todo['category'] as String? ?? '기타';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddTodoModal(
          initialTitle: initialTitle,
          initialTime: initialTime,
          initialCategory: initialCategory,
          isEditMode: true,
        ),
      ),
    ).then((result) {
      if (result != null) {
        // 일정 수정 로직
        final selectedDate = _getSelectedDate();
        final dateKey = _formatDateKey(selectedDate);
        final todos = _todosByDate[dateKey] ?? [];

        // 시간 정보 포함하여 제목 생성
        String title = result['title'] as String;
        final time = result['time'] as String?;
        if (time != null && time.isNotEmpty) {
          title = '$time $title';
        }

        // 기존 todo 찾아서 업데이트
        final todoIndex = todos.indexWhere(
          (t) =>
              t['title'] == todo['title'] &&
              t['category'] == todo['category'],
        );

        if (todoIndex != -1) {
          setState(() {
            todos[todoIndex] = {
              'title': title,
              'category': result['category'] as String? ?? '기타',
              'isHighlighted': todos[todoIndex]['isHighlighted'] ?? true,
              'checkType': todos[todoIndex]['checkType'] ?? 'none',
            };
            _todosByDate[dateKey] = todos;
            // 전역 상태도 업데이트
            _TodoScreenStateManager.setTodosByDate(_todosByDate);
          });
        }
      }
    });
  }

  // 체크된 항목을 하단으로 정렬
  List<Map<String, dynamic>> get _sortedTodos {
    final unchecked = _todos
        .where((todo) => todo['checkType'] != 'done')
        .toList();
    final checked = _todos
        .where((todo) => todo['checkType'] == 'done')
        .toList();
    return [...unchecked, ...checked];
  }

  void _toggleCheck(int index) {
    setState(() {
      final todos = _todos; // 현재 날짜의 할 일 목록
      final newState = todos[index]['checkType'] == 'done' ? 'none' : 'done';
      todos[index]['checkType'] = newState;
      // 날짜별 할 일 목록 업데이트
      final selectedDate = _getSelectedDate();
      final dateKey = _formatDateKey(selectedDate);
      _todosByDate[dateKey] = todos;
      // 전역 상태도 업데이트
      _TodoScreenStateManager.setTodosByDate(_todosByDate);
      // 체크 상태 저장
      final key = _getTodoKey(todos[index]);
      _TodoScreenStateManager.setCheckState(key, newState);
    });
  }

  @override
  Widget build(BuildContext context) {
    // BottomNavigationBar 높이 (SafeArea 포함)
    final bottomNavHeight = 60.0 + MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            // 화면 어디를 눌러도 스와이프 해제
            SwipeStateManager().clearSwipedCard();
          },
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
                        // 현재 선택된 탭(to-do)을 다시 누르면 오늘 날짜로 이동
                        if (index == _selectedTabIndex && index == 0) {
                          setState(() {
                            _selectedDateIndex = 15; // 오늘 날짜 (인덱스 15)
                            _TodoScreenStateManager.selectedDateIndex = 15;
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _scrollToSelectedDate(context);
                          });
                          return;
                        }

                        // to-do 탭(index 0)으로 전환할 때 오늘 날짜로 이동
                        if (index == 0) {
                          setState(() {
                            _selectedDateIndex = 15; // 오늘 날짜 (인덱스 15)
                            _TodoScreenStateManager.selectedDateIndex = 15;
                            _selectedTabIndex = index;
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _scrollToSelectedDate(context);
                          });
                          return;
                        }

                        if (index == 1) {
                          // routine 탭 클릭 시 화면 전환
                          Navigator.pushReplacement(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const RoutineScreen(),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          );
                        } else if (index == 2) {
                          // dashboard 탭 클릭 시 화면 전환
                          Navigator.pushReplacement(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const DashboardScreen(),
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
                  const SizedBox(height: 6),

                  // 날짜 캘린더
                  _buildDateCalendar(context),
                  const SizedBox(height: 30),

                  // 할 일 섹션
                  Expanded(child: _buildTodoSection(context)),

                  // 하단 네비게이션
                  const CustomBottomNavigation(currentScreen: 'todo'),
                ],
              ),

              // 일정 추가하기 바
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
                      _showAddTodoModal(context);
                    },
                    child: Container(
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        image: const DecorationImage(
                          image: AssetImage('assets/todo_screen/bar.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: const Text(
                        '일정 추가하기',
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

              // chat.png 플로팅 버튼
              Positioned(
                right: 20,
                bottom: 60 + MediaQuery.of(context).padding.bottom + 84 + 10,
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
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChatScreen(),
                          ),
                        );
                      },
                      child: Image.asset(
                        'assets/todo_screen/chat.png',
                        width: 45,
                        height: 45,
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
    // 기준일: 오늘 날짜 (매번 현재 날짜를 가져옴)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final referenceDate = today; // 오늘을 기준으로 설정

    // 앞뒤로 15일씩만 생성 (총 31일: 15일 전부터 15일 후까지)
    // 인덱스 15가 오늘 날짜가 되도록 설정
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
              setState(() {
                _selectedDateIndex = index;
                _TodoScreenStateManager.selectedDateIndex = index;
                // 날짜 변경 시 해당 날짜의 할 일 목록으로 업데이트
                // _todos getter가 자동으로 선택된 날짜의 할 일을 반환
              });
              // 선택된 날짜를 중앙으로 스크롤
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToSelectedDate(context);
              });
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

  Widget _buildTodoSection(BuildContext context) {
    // 하단 네비게이션과 일정 추가하기 바 높이 계산
    final bottomNavHeight = 60.0 + MediaQuery.of(context).padding.bottom;
    final todoBarHeight = 84.0; // 일정 추가하기 바 높이 (60) + 패딩 (24)
    final bottomPadding = bottomNavHeight + todoBarHeight + 10; // 여유 공간 추가

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 할 일 리스트 (스크롤 가능)
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: bottomPadding),
              children: [
                ..._sortedTodos.asMap().entries.map((entry) {
                  final index = entry.key;
                  final todo = entry.value;
                  final isFirstChecked =
                      index > 0 &&
                      _sortedTodos[index - 1]['checkType'] != 'done' &&
                      todo['checkType'] == 'done';

                  // 원본 리스트에서의 인덱스 찾기
                  final originalIndex = _todos.indexWhere(
                    (t) =>
                        t['title'] == todo['title'] &&
                        t['category'] == todo['category'],
                  );
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                    child: Padding(
                      key: ValueKey('${todo['title']}_${todo['checkType']}'),
                      padding: EdgeInsets.only(
                        bottom: 12,
                        top: isFirstChecked ? 20 : 0, // 체크된 항목 시작 부분에 여백 추가
                      ),
                      child: TodoItemCard(
                        title: todo['title'] as String,
                        category: todo['category'] as String,
                        isHighlighted: todo['isHighlighted'] as bool,
                        checkType: todo['checkType'] as String,
                        cardKey:
                            'todo_${todo['title']}_${todo['category']}_$originalIndex',
                        onCheckChanged: () => _toggleCheck(originalIndex),
                        onView: () {
                          // View 버튼 클릭 시 수정 모달 열기
                          _showEditTodoModal(context, todo, originalIndex);
                        },
                        onDelete: () {
                          // Delete 버튼 클릭 시 해당 날짜의 todo 목록에서 제거
                          setState(() {
                            final selectedDate = _getSelectedDate();
                            final dateKey = _formatDateKey(selectedDate);
                            final todos = _todosByDate[dateKey] ?? [];

                            // 제거할 항목 찾기 (title과 category로 매칭)
                            todos.removeWhere(
                              (t) =>
                                  t['title'] == todo['title'] &&
                                  t['category'] == todo['category'],
                            );

                            _todosByDate[dateKey] = todos;

                            // 전역 상태도 업데이트
                            _TodoScreenStateManager.setTodosByDate(
                              _todosByDate,
                            );

                            // 체크 상태도 제거
                            final key = _getTodoKey(todo);
                            _TodoScreenStateManager.setCheckState(
                              key,
                              null,
                            ); // null을 전달하면 키가 제거됨
                          });
                        },
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
