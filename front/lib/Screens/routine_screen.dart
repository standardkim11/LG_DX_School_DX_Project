import 'package:flutter/material.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/tab_bar.dart';
import '../components/date_card.dart';
import '../components/bottom_navigation.dart';
import '../components/habit_card.dart';
import 'todo_screen.dart';
import 'viewall_screen.dart';
import 'dashboard_screen.dart';
import 'chat_screen.dart';
import 'routinesave_screen.dart';
import '../Services/routine_service.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

// 전역 상태 관리
class _RoutineScreenStateManager {
  static int _selectedDateIndex = 15;
  static final Map<String, String> _checkStates = {}; // 체크 상태 저장
  static Set<int> _selectedRoutineIds = {}; // VIEW ALL에서 선택된 루틴 ID들
  static List<int> _priorityOrder = []; // 우선순위 순서 (루틴 ID 리스트)

  static int get selectedDateIndex => _selectedDateIndex;
  static set selectedDateIndex(int value) => _selectedDateIndex = value;

  static String? getCheckState(String key) => _checkStates[key];
  static void setCheckState(String key, String value) =>
      _checkStates[key] = value;

  // 선택된 루틴 ID들 관리
  static Set<int> get selectedRoutineIds => Set<int>.from(_selectedRoutineIds);
  static void setSelectedRoutineIds(Set<int> ids) {
    _selectedRoutineIds = Set<int>.from(ids);
  }

  static void clearSelectedRoutineIds() {
    _selectedRoutineIds.clear();
  }

  // 우선순위 순서 관리 (날짜별)
  static final Map<String, List<int>> _priorityOrdersByDate = {}; // 날짜별 우선순위 순서
  static final Map<String, Set<int>> _selectedRoutinesByDate =
      {}; // 날짜별 선택된 루틴 ID들

  static List<int> get priorityOrder => List<int>.from(_priorityOrder);
  static void setPriorityOrder(List<int> order) {
    _priorityOrder = List<int>.from(order);
  }

  // 날짜별 우선순위 순서 관리
  static List<int>? getPriorityOrderForDate(String dateKey) {
    return _priorityOrdersByDate[dateKey] != null
        ? List<int>.from(_priorityOrdersByDate[dateKey]!)
        : null;
  }

  static void setPriorityOrderForDate(String dateKey, List<int> order) {
    _priorityOrdersByDate[dateKey] = List<int>.from(order);
  }

  // 날짜별 선택된 루틴 ID 관리
  static Set<int>? getSelectedRoutinesForDate(String dateKey) {
    return _selectedRoutinesByDate[dateKey] != null
        ? Set<int>.from(_selectedRoutinesByDate[dateKey]!)
        : null;
  }

  static void setSelectedRoutinesForDate(String dateKey, Set<int> routineIds) {
    _selectedRoutinesByDate[dateKey] = Set<int>.from(routineIds);
  }

  // 필요시 우선순위 순서 초기화
  // static void clearPriorityOrder() {
  //   _priorityOrder.clear();
  // }

  // 날짜를 12일(금요일, 인덱스 15)로 리셋하는 메서드
  static void resetToDefaultDate() {
    _selectedDateIndex = 15;
  }
}

// 외부에서 접근 가능한 날짜 리셋 함수
void resetRoutineScreenDate() {
  _RoutineScreenStateManager.resetToDefaultDate();
}

// 외부에서 접근 가능한 날짜 설정 함수
void setRoutineScreenDate(int dateIndex) {
  _RoutineScreenStateManager.selectedDateIndex = dateIndex;
}

// 외부에서 접근 가능한 선택된 루틴 ID 설정 함수
void setSelectedRoutineIds(Set<int> routineIds) {
  _RoutineScreenStateManager.setSelectedRoutineIds(routineIds);
}

// 외부에서 접근 가능한 선택된 루틴 ID 가져오기 함수
Set<int> getSelectedRoutineIds() {
  return _RoutineScreenStateManager.selectedRoutineIds;
}

// 외부에서 접근 가능한 선택된 루틴 ID 초기화 함수
void clearSelectedRoutineIds() {
  _RoutineScreenStateManager.clearSelectedRoutineIds();
}

// 외부에서 접근 가능한 우선순위 순서 설정 함수
void setPriorityOrder(List<int> order) {
  _RoutineScreenStateManager.setPriorityOrder(order);
}

// 외부에서 접근 가능한 우선순위 순서 가져오기 함수
List<int> getPriorityOrder() {
  return _RoutineScreenStateManager.priorityOrder;
}

// 외부에서 접근 가능한 날짜별 우선순위 순서 설정 함수
void setPriorityOrderForDate(String dateKey, List<int> order) {
  _RoutineScreenStateManager.setPriorityOrderForDate(dateKey, order);
}

// 외부에서 접근 가능한 날짜별 우선순위 순서 가져오기 함수
List<int>? getPriorityOrderForDate(String dateKey) {
  return _RoutineScreenStateManager.getPriorityOrderForDate(dateKey);
}

// 외부에서 접근 가능한 날짜별 선택된 루틴 ID 설정 함수
void setSelectedRoutinesForDate(String dateKey, Set<int> routineIds) {
  _RoutineScreenStateManager.setSelectedRoutinesForDate(dateKey, routineIds);
}

// 외부에서 접근 가능한 날짜별 선택된 루틴 ID 가져오기 함수
Set<int>? getSelectedRoutinesForDate(String dateKey) {
  return _RoutineScreenStateManager.getSelectedRoutinesForDate(dateKey);
}

class _RoutineScreenState extends State<RoutineScreen> {
  int _selectedTabIndex = 1; // routine 탭이 선택된 상태
  int _selectedDateIndex = _RoutineScreenStateManager.selectedDateIndex;
  late ScrollController _dateScrollController;
  bool _isLoading = false;

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
    final baseDate = DateTime(now.year, now.month, 12);
    final currentWeekday = baseDate.weekday;
    final daysUntilFriday = (5 - currentWeekday + 7) % 7;
    final referenceDate = baseDate.add(Duration(days: daysUntilFriday));
    return referenceDate.add(Duration(days: _selectedDateIndex - 15));
  }

  // 날짜를 키 형식으로 변환
  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getTodoKey(Map<String, dynamic> todo) {
    return '${todo['title']}_${todo['category']}';
  }

  // 선택된 루틴 ID들로부터 루틴 데이터를 로드
  Future<void> _loadSelectedRoutines(Set<int> routineIds) async {
    if (routineIds.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 전체 루틴 목록에서 선택된 ID들만 필터링
      final allRoutines = await RoutineService.getAllRoutines();
      final selectedRoutines = allRoutines
          .where((r) => routineIds.contains(r.id))
          .toList();

      // 선택된 날짜의 키
      final selectedDate = _getSelectedDate();
      final dateKey = _formatDateKey(selectedDate);

      // ViewAllRoutineItem을 화면에 표시할 형식으로 변환
      var todos = selectedRoutines.map((routine) {
        return {
          'title': routine.name,
          'category': routine.getTimeDisplay(),
          'isHighlighted': true,
          'checkType': routine.isDoneToday ? 'done' : 'none',
          'routineId': routine.id,
        };
      }).toList();

      // 우선순위 순서가 있으면 그 순서대로 정렬 (날짜별 우선순위 사용)
      final datePriorityOrder =
          _RoutineScreenStateManager.getPriorityOrderForDate(dateKey);
      final priorityOrder =
          datePriorityOrder ??
          _RoutineScreenStateManager.priorityOrder; // 날짜별이 없으면 전역 사용
      if (priorityOrder.isNotEmpty) {
        todos.sort((a, b) {
          final aIndex = priorityOrder.indexOf(a['routineId'] as int);
          final bIndex = priorityOrder.indexOf(b['routineId'] as int);

          // 우선순위 순서에 없는 항목은 뒤로
          if (aIndex == -1 && bIndex == -1) return 0;
          if (aIndex == -1) return 1;
          if (bIndex == -1) return -1;

          return aIndex.compareTo(bIndex);
        });
      }

      setState(() {
        _todosByDate[dateKey] = todos;
        _isLoading = false;

        // 저장된 체크 상태 복원
        for (var todo in todos) {
          final key = _getTodoKey(todo);
          final savedState = _RoutineScreenStateManager.getCheckState(key);
          if (savedState != null) {
            todo['checkType'] = savedState;
          }
        }
      });
    } catch (e) {
      print('Error loading selected routines: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 특정 날짜의 루틴 데이터를 API에서 가져오기
  Future<void> _loadRoutinesForDate(DateTime date) async {
    final dateKey = _formatDateKey(date);

    // 이미 로드된 데이터가 있으면 스킵
    if (_todosByDate.containsKey(dateKey)) {
      return;
    }

    // 해당 날짜에 선택된 루틴이 있으면 선택된 루틴을 로드
    final dateSelectedRoutines =
        _RoutineScreenStateManager.getSelectedRoutinesForDate(dateKey);

    if (dateSelectedRoutines != null && dateSelectedRoutines.isNotEmpty) {
      await _loadSelectedRoutines(dateSelectedRoutines);
      return;
    }

    // viewall에서 설정한 적 없는 날짜는 빈 상태로 설정 (API 호출하지 않음)
    setState(() {
      _todosByDate[dateKey] = [];
    });
  }

  @override
  void initState() {
    super.initState();
    _dateScrollController = ScrollController();

    // 저장된 날짜 인덱스로 복원
    _selectedDateIndex = _RoutineScreenStateManager.selectedDateIndex;

    // 초기 스크롤 위치를 저장된 날짜 인덱스로 설정 (중앙에 오도록)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate(context);

      // 현재 선택된 날짜에 저장된 선택된 루틴이 있는지 확인
      final selectedDate = _getSelectedDate();
      final dateKey = _formatDateKey(selectedDate);

      final dateSelectedRoutines =
          _RoutineScreenStateManager.getSelectedRoutinesForDate(dateKey);

      if (dateSelectedRoutines != null && dateSelectedRoutines.isNotEmpty) {
        // 해당 날짜에 선택된 루틴이 있으면 로드
        _loadSelectedRoutines(dateSelectedRoutines);
      } else {
        // viewall에서 설정한 적 없는 날짜는 빈 상태 (API 호출하지 않음)
        _loadRoutinesForDate(selectedDate);
      }
    });
  }

  // 체크된 항목을 하단으로 정렬 (우선순위 순서 고려)
  List<Map<String, dynamic>> get _sortedTodos {
    final selectedDate = _getSelectedDate();
    final dateKey = _formatDateKey(selectedDate);

    // 날짜별 우선순위 순서 사용, 없으면 전역 우선순위 사용
    final priorityOrder =
        _RoutineScreenStateManager.getPriorityOrderForDate(dateKey) ??
        _RoutineScreenStateManager.priorityOrder;

    // 우선순위 순서가 있으면 그 순서를 기준으로 정렬
    if (priorityOrder.isNotEmpty) {
      final todosList = List<Map<String, dynamic>>.from(_todos);

      // 우선순위 순서로 정렬
      todosList.sort((a, b) {
        final aRoutineId = a['routineId'] as int?;
        final bRoutineId = b['routineId'] as int?;

        // routineId가 없으면 기본 정렬 (체크 상태 기준)
        if (aRoutineId == null || bRoutineId == null) {
          final aDone = a['checkType'] == 'done';
          final bDone = b['checkType'] == 'done';
          if (aDone == bDone) return 0;
          return aDone ? 1 : -1;
        }

        final aIndex = priorityOrder.indexOf(aRoutineId);
        final bIndex = priorityOrder.indexOf(bRoutineId);

        // 우선순위 순서에 없는 항목은 뒤로
        if (aIndex == -1 && bIndex == -1) {
          final aDone = a['checkType'] == 'done';
          final bDone = b['checkType'] == 'done';
          if (aDone == bDone) return 0;
          return aDone ? 1 : -1;
        }
        if (aIndex == -1) return 1;
        if (bIndex == -1) return -1;

        // 같은 우선순위 내에서는 체크 상태 기준 정렬
        if (aIndex == bIndex) {
          final aDone = a['checkType'] == 'done';
          final bDone = b['checkType'] == 'done';
          if (aDone == bDone) return 0;
          return aDone ? 1 : -1;
        }

        return aIndex.compareTo(bIndex);
      });

      // 체크된 항목을 하단으로 이동 (우선순위 순서는 유지)
      final unchecked = todosList
          .where((todo) => todo['checkType'] != 'done')
          .toList();
      final checked = todosList
          .where((todo) => todo['checkType'] == 'done')
          .toList();

      return [...unchecked, ...checked];
    }

    // 우선순위 순서가 없으면 기존 로직 사용
    final unchecked = _todos
        .where((todo) => todo['checkType'] != 'done')
        .toList();
    final checked = _todos
        .where((todo) => todo['checkType'] == 'done')
        .toList();
    return [...unchecked, ...checked];
  }

  void _showCreateRoutineModal(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final modalHeight = screenHeight * 0.42; // todo 모달과 동일한 높이

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: modalHeight,
          decoration: const BoxDecoration(
            color: AppColors.backgroundWhite,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Column(
            children: [
              // 드래그 핸들 (todo 모달과 동일한 스타일)
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 24),
                width: 82,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 헤더 (todo 모달과 동일한 스타일)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '새로운 루틴 생성',
                    style: TextStyle(
                      color: const Color(0xFF9B9BA1),
                      fontSize: 10,
                      fontFamily: 'LG Smart_H',
                      fontWeight: FontWeight.w700,
                      height: 1.60,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 스크롤 가능한 내용
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 새로운 루틴 생성하기 버튼
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context); // 모달 닫기
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ViewSaveScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.borderLight,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '새로운 루틴 생성하기',
                                style: AppTextStyles.todoTitle(context),
                              ),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.borderLight,
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.black,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // 인기있는 루틴 섹션
                      Text(
                        '인기있는 루틴',
                        style: TextStyle(
                          color: const Color(0xFF9B9BA1),
                          fontSize: 10,
                          fontFamily: 'LG Smart_H',
                          fontWeight: FontWeight.w700,
                          height: 1.60,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 인기 루틴 카드들
                      Row(
                        children: [
                          Expanded(
                            child: _buildPopularRoutineCard(
                              '로봇청소기',
                              '40분',
                              const Color(0xFFFFE5E5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildPopularRoutineCard(
                              '독서',
                              '1시간',
                              const Color(0xFFE5E5FF),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildPopularRoutineCard(
                              '빨래',
                              '1시간 21분',
                              const Color(0xFFE5FFE5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPopularRoutineCard(
    String title,
    String duration,
    Color backgroundColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.todoTitle(context)),
          const SizedBox(height: 4),
          Text(duration, style: AppTextStyles.todoCategory(context)),
        ],
      ),
    );
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
      // 체크 상태 저장
      final key = _getTodoKey(todos[index]);
      _RoutineScreenStateManager.setCheckState(key, newState);
    });
  }

  // 확인 팝업 표시 (viewall_screen과 동일한 스타일)
  Future<bool> _showConfirmDialog(
    String message, {
    VoidCallback? onConfirm,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        bool? selectedButton;
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
                      message,
                      style: AppTextStyles.sectionTitle(
                        context,
                      ).copyWith(fontSize: 18, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedButton = true;
                              });
                              Future.delayed(
                                const Duration(milliseconds: 150),
                                () {
                                  if (context.mounted) {
                                    Navigator.of(context).pop(true);
                                    if (onConfirm != null) {
                                      onConfirm();
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
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedButton = false;
                              });
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

  @override
  Widget build(BuildContext context) {
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
                        // 현재 선택된 탭을 다시 누르면 12일로 이동
                        if (index == _selectedTabIndex) {
                          setState(() {
                            _selectedDateIndex = 15; // 12일 금요일 (인덱스 15)
                            _RoutineScreenStateManager.selectedDateIndex = 15;
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _scrollToSelectedDate(context);
                          });
                          return;
                        }

                        if (index == 0) {
                          // to-do 탭 클릭 시 todo_screen으로 전환
                          Navigator.pushReplacement(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const TodoScreen(),
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
                  const SizedBox(height: 10),

                  // 할 일 섹션
                  Expanded(child: _buildTodoSection(context)),

                  // 하단 네비게이션
                  const CustomBottomNavigation(currentScreen: 'routine'),
                ],
              ),

              // 루틴 생성하기 바
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
                      _showCreateRoutineModal(context);
                    },
                    child: Container(
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        image: const DecorationImage(
                          image: AssetImage(
                            'assets/routine_screen/routine_bar.png',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: const Text(
                        '루틴 생성하기',
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
                    borderRadius: BorderRadius.circular(30),
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
              // 날짜 인덱스 업데이트
              setState(() {
                _selectedDateIndex = index;
                _RoutineScreenStateManager.selectedDateIndex = index;
              });

              // 날짜 변경 시: 해당 날짜의 선택된 루틴이 있으면 로드, 없으면 API에서 로드
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final selectedDate = _getSelectedDate();
                final dateKey = _formatDateKey(selectedDate);

                // 해당 날짜에 저장된 선택된 루틴이 있는지 확인
                final dateSelectedRoutines =
                    _RoutineScreenStateManager.getSelectedRoutinesForDate(
                      dateKey,
                    );

                if (dateSelectedRoutines != null &&
                    dateSelectedRoutines.isNotEmpty) {
                  // 해당 날짜에 선택된 루틴이 있으면 로드
                  _loadSelectedRoutines(dateSelectedRoutines);
                } else {
                  // 선택된 루틴이 없으면 해당 날짜의 루틴을 API에서 로드
                  _loadRoutinesForDate(selectedDate);
                }
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
                const SizedBox.shrink(), // 왼쪽 공간 (투두와 동일한 구조)
                GestureDetector(
                  onTap: () {
                    // 현재 선택된 날짜 정보를 ViewAllScreen에 전달
                    final selectedDate = _getSelectedDate();
                    final dateKey = _formatDateKey(selectedDate);

                    // 이미 등록된 일정이 있는지 확인
                    final dateSelectedRoutines =
                        _RoutineScreenStateManager.getSelectedRoutinesForDate(
                          dateKey,
                        );
                    final hasRoutines =
                        dateSelectedRoutines != null &&
                        dateSelectedRoutines.isNotEmpty;

                    if (hasRoutines) {
                      // 등록된 일정이 있으면 확인 팝업 표시
                      _showConfirmDialog(
                        '루틴을 다시 선택하시겠습니까?',
                        onConfirm: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      ViewAllScreen(selectedDateKey: dateKey),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          );
                        },
                      );
                    } else {
                      // 등록된 일정이 없으면 바로 ViewAllScreen으로 이동
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  ViewAllScreen(selectedDateKey: dateKey),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                        ),
                      );
                    }
                  },
                  child: Text(
                    'VIEW ALL',
                    style: AppTextStyles.viewAll(context),
                  ),
                ),
              ],
            ),
          ),

          // 할 일 리스트 (스크롤 가능)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _sortedTodos.isEmpty
                ? Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: Text(
                        'VIEW ALL에서 루틴을 선택해주세요',
                        style: AppTextStyles.todoCategory(context),
                      ),
                    ),
                  )
                : ListView(
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
                        // 첫번째 카드: friends.png, 두번째 카드: friends1.png, 세번째 카드: friends2.png
                        final friendIcons = [
                          'assets/routine_screen/friends.png',
                          'assets/routine_screen/friends1.png',
                          'assets/routine_screen/friends2.png',
                        ];
                        final friendIcon =
                            originalIndex < friendIcons.length &&
                                originalIndex >= 0
                            ? friendIcons[originalIndex]
                            : null;

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
                            key: ValueKey(
                              '${todo['title']}_${todo['checkType']}',
                            ),
                            padding: EdgeInsets.only(
                              bottom: 12,
                              top: isFirstChecked
                                  ? 20
                                  : 0, // 체크된 항목 시작 부분에 여백 추가
                            ),
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
                              onCheckChanged: () => _toggleCheck(originalIndex),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
