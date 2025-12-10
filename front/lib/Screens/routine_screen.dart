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
  // 기본값을 15로 설정 (오늘 날짜가 인덱스 15)
  // initState에서 setRoutineScreenToToday()를 호출하여 오늘 날짜로 설정됨
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

// 외부에서 접근 가능한 오늘 날짜로 설정 함수
void setRoutineScreenToToday() {
  // _buildDateCalendar에서 인덱스 15가 오늘 날짜가 되도록 설정하므로
  // 단순히 인덱스 15로 설정하면 됩니다
  _RoutineScreenStateManager.selectedDateIndex = 15;
  print('[setRoutineScreenToToday] 오늘 날짜로 설정: 인덱스 15');
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

class _RoutineScreenState extends State<RoutineScreen>
    with WidgetsBindingObserver {
  int _selectedTabIndex =
      1; // routine 탭이 선택된 상태 (0: todo, 1: routine, 2: dashboard)
  int _selectedDateIndex = _RoutineScreenStateManager.selectedDateIndex;
  late ScrollController _dateScrollController;
  bool _isLoading = false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dateScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedDate([BuildContext? ctx]) {
    if (_dateScrollController.hasClients) {
      final contextToUse = ctx ?? context;
      final screenWidth = MediaQuery.of(contextToUse).size.width;
      final cardWidth = 64.0; // 카드 너비(60) + 좌우 마진(4)
      // 항상 최신 상태를 가져오기 위해 _RoutineScreenStateManager에서 직접 읽음
      final currentDateIndex = _RoutineScreenStateManager.selectedDateIndex;
      // 선택된 날짜를 중앙에 배치: (인덱스 * 카드너비) - (화면너비/2) + (카드너비/2)
      final scrollPosition =
          (currentDateIndex * cardWidth) - (screenWidth / 2) + (cardWidth / 2);
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
    // _buildDateCalendar와 동일한 로직 사용: 오늘 날짜를 기준으로 인덱스 15가 오늘 날짜
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 항상 최신 상태를 가져오기 위해 _RoutineScreenStateManager에서 직접 읽음
    final currentDateIndex = _RoutineScreenStateManager.selectedDateIndex;
    return today.add(Duration(days: currentDateIndex - 15));
  }

  // 날짜를 키 형식으로 변환
  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getTodoKey(Map<String, dynamic> todo) {
    return '${todo['title']}_${todo['category']}';
  }

  // 선택된 루틴 ID들로부터 루틴 데이터를 로드
  Future<void> _loadSelectedRoutines(
    Set<int> routineIds, {
    bool forceRefresh = false,
  }) async {
    if (routineIds.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 전체 루틴 목록에서 선택된 ID들만 필터링
      final allRoutines = await RoutineService.getAllRoutines();

      print('[RoutineScreen] API에서 받은 전체 루틴 수: ${allRoutines.length}');
      print(
        '[RoutineScreen] API에서 받은 루틴 ID들: ${allRoutines.map((r) => r.id).toList()}',
      );
      print('[RoutineScreen] 선택된 루틴 ID들: $routineIds');

      // API 호출이 실패해서 빈 리스트가 반환된 경우, 선택된 루틴 ID를 유지
      if (allRoutines.isEmpty) {
        print(
          '[RoutineScreen] 경고: API 호출 실패 또는 빈 리스트 반환. 선택된 루틴 ID 유지: $routineIds',
        );
        setState(() {
          _isLoading = false;
        });
        return; // API 실패 시에도 선택된 루틴 ID는 유지하고 종료
      }

      // 실제로 존재하는 루틴 ID만 필터링 (DB에서 삭제된 루틴 제외)
      final existingRoutineIds = allRoutines.map((r) => r.id).toSet();
      final validRoutineIds = routineIds
          .where((id) => existingRoutineIds.contains(id))
          .toSet();

      print('[RoutineScreen] 유효한 루틴 ID들: $validRoutineIds');
      print(
        '[RoutineScreen] 삭제된 루틴 ID들: ${routineIds.difference(validRoutineIds)}',
      );

      // 유효하지 않은 루틴 ID가 있으면 상태에서 제거
      // 단, API 호출이 실패한 경우가 아닌 경우에만 제거
      if (validRoutineIds.length != routineIds.length &&
          allRoutines.isNotEmpty) {
        final selectedDate = _getSelectedDate();
        final dateKey = _formatDateKey(selectedDate);
        _RoutineScreenStateManager.setSelectedRoutinesForDate(
          dateKey,
          validRoutineIds,
        );
        print(
          '[RoutineScreen] 상태에서 삭제된 루틴 ID 제거: ${routineIds.difference(validRoutineIds)}',
        );
      }

      final selectedRoutines = allRoutines
          .where((r) => validRoutineIds.contains(r.id))
          .toList();

      print('[RoutineScreen] 최종 표시할 루틴 수: ${selectedRoutines.length}');
      print(
        '[RoutineScreen] 최종 표시할 루틴 이름들: ${selectedRoutines.map((r) => r.name).toList()}',
      );

      // 선택된 날짜의 키
      final selectedDate = _getSelectedDate();
      final dateKey = _formatDateKey(selectedDate);

      // ViewAllRoutineItem을 화면에 표시할 형식으로 변환
      // MONTHLY 루틴은 맨 뒤로 정렬
      var todos = selectedRoutines.map((routine) {
        // isDoneToday가 true인데 completedCount가 0이면 1로 설정
        int completedCount = routine.completedCount;
        if (routine.isDoneToday && completedCount == 0) {
          completedCount = 1;
          print(
            '[RoutineScreen] 루틴 ${routine.name}이 체크되어 있지만 completedCount가 0이므로 1로 설정',
          );
        }

        // 설정값에 따라 예상 횟수 계산
        // WEEKLY: 주당 횟수 (scheduleFrequency)
        // MONTHLY: 월당 횟수 (scheduleFrequency)
        // DAILY: 일당 횟수 * 이번 달 일수
        final scheduleFrequency = routine.scheduleFrequency > 0
            ? routine.scheduleFrequency
            : 1;
        int expectedCount = 0;

        if (routine.scheduleType == 'WEEKLY') {
          // 주 N회이면 주당 N회 (월 기준으로 변환하지 않음)
          expectedCount = scheduleFrequency;
        } else if (routine.scheduleType == 'MONTHLY') {
          // 월 N회이면 월당 N회
          expectedCount = scheduleFrequency;
        } else if (routine.scheduleType == 'DAILY') {
          // 일 N회이면 이번 달에 (월 일수) * N회
          final now = DateTime.now();
          final currentMonthStart = DateTime(now.year, now.month, 1);
          final currentMonthEnd = DateTime(now.year, now.month + 1, 0);
          final daysInMonth =
              currentMonthEnd.difference(currentMonthStart).inDays + 1;
          expectedCount = daysInMonth * scheduleFrequency;
        } else {
          // 기타 타입은 기본값
          expectedCount = scheduleFrequency;
        }

        // category에 숫자 추가 (completedCount/expectedCount 형식)
        String category;
        if (routine.scheduleType == 'WEEKLY' ||
            routine.scheduleType == 'MONTHLY') {
          // WEEKLY/MONTHLY: completedCount / scheduleFrequency (설정값 그대로)
          category = '$completedCount/$expectedCount';
        } else {
          // DAILY 등은 시간 정보와 숫자를 공백으로 구분하여 한 줄로 표시
          final timeDisplay = routine.getTimeDisplay();
          category = '$timeDisplay  $completedCount/$expectedCount';
        }

        return {
          'title': routine.name,
          'category': category, // 시간 + 숫자 포함
          'isHighlighted': true,
          'checkType': routine.isDoneToday ? 'done' : 'none',
          'routineId': routine.id,
          'scheduleType': routine.scheduleType, // 정렬을 위해 추가
          'completedCount': completedCount, // 완료 횟수 (체크 상태와 일치하도록 수정)
          'scheduleFrequency': routine.scheduleFrequency, // 목표 횟수 추가
          'runMinutes': routine.runMinutes, // 실행 시간 추가
        };
      }).toList();

      // MONTHLY 루틴을 맨 뒤로 정렬
      todos.sort((a, b) {
        final aIsMonthly =
            (a['scheduleType'] as String? ?? '').toUpperCase() == 'MONTHLY';
        final bIsMonthly =
            (b['scheduleType'] as String? ?? '').toUpperCase() == 'MONTHLY';
        if (aIsMonthly && !bIsMonthly) return 1; // MONTHLY는 뒤로
        if (!aIsMonthly && bIsMonthly) return -1; // 일반 루틴은 앞으로
        return 0; // 같은 타입이면 순서 유지
      });

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

      // 유효하지 않은 루틴이 있으면 빈 배열로 설정
      if (selectedRoutines.isEmpty && routineIds.isNotEmpty) {
        print('[RoutineScreen] 경고: 선택된 루틴 ID가 있지만 API에서 반환된 루틴이 없음');
        print('[RoutineScreen] 선택된 루틴 ID들: $routineIds');
        print(
          '[RoutineScreen] API에서 받은 루틴 ID들: ${allRoutines.map((r) => r.id).toList()}',
        );

        // 상태에서도 완전히 제거
        _RoutineScreenStateManager.setSelectedRoutinesForDate(dateKey, <int>{});

        setState(() {
          _todosByDate[dateKey] = [];
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _todosByDate[dateKey] = todos;
        _isLoading = false;

        // 저장된 체크 상태 복원 또는 isDoneToday 상태 반영
        for (var todo in todos) {
          final key = _getTodoKey(todo);
          final savedState = _RoutineScreenStateManager.getCheckState(key);

          // 저장된 체크 상태가 있으면 사용, 없으면 isDoneToday 상태 사용
          if (savedState != null) {
            todo['checkType'] = savedState;
          } else {
            // isDoneToday가 true면 자동으로 체크 상태로 설정
            final routineId = todo['routineId'] as int?;
            if (routineId != null) {
              final routine = selectedRoutines.firstWhere(
                (r) => r.id == routineId,
                orElse: () => selectedRoutines.first,
              );
              if (routine.isDoneToday) {
                todo['checkType'] = 'done';
                // 체크 상태 저장
                _RoutineScreenStateManager.setCheckState(key, 'done');
                print(
                  '[RoutineScreen] 루틴 ${routine.name}이 isDoneToday=true이므로 자동 체크 상태로 설정',
                );
              }
            }
          }
        }

        // 완료된 루틴도 리스트에 유지 (1/1이 되어도 제거하지 않음)
        // todos 리스트에서 완료된 항목을 필터링하지 않음
      });
    } catch (e) {
      print('Error loading selected routines: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 특정 날짜의 루틴 데이터를 API에서 가져오기
  Future<void> _loadRoutinesForDate(
    DateTime date, {
    bool forceRefresh = false,
  }) async {
    final dateKey = _formatDateKey(date);

    // 이미 로드된 데이터가 있고 강제 새로고침이 아니면 스킵
    if (_todosByDate.containsKey(dateKey) && !forceRefresh) {
      return;
    }

    // 해당 날짜에 선택된 루틴이 있으면 선택된 루틴을 로드
    final dateSelectedRoutines =
        _RoutineScreenStateManager.getSelectedRoutinesForDate(dateKey);

    if (dateSelectedRoutines != null && dateSelectedRoutines.isNotEmpty) {
      await _loadSelectedRoutines(
        dateSelectedRoutines,
        forceRefresh: forceRefresh,
      );
      return;
    }

    // viewall에서 설정한 적 없는 날짜는 API에서 해당 날짜의 루틴을 가져옴
    setState(() {
      _isLoading = true;
    });

    try {
      final dateStr = dateKey; // 이미 YYYY-MM-DD 형식
      final routines = await RoutineService.getRoutinesByDate(date: dateStr);

      // RoutineItem을 화면에 표시할 형식으로 변환
      var todos = routines.map((routine) {
        return {
          'title': routine.name,
          'category': routine.getCategoryDisplay(),
          'isHighlighted': true,
          'checkType': routine.done ? 'done' : 'none',
          'routineId': routine.routineId,
          'scheduleType': routine.scheduleType, // 정렬을 위해 추가
        };
      }).toList();

      // MONTHLY 루틴을 맨 뒤로 정렬
      todos.sort((a, b) {
        final aIsMonthly =
            (a['scheduleType'] as String? ?? '').toUpperCase() == 'MONTHLY';
        final bIsMonthly =
            (b['scheduleType'] as String? ?? '').toUpperCase() == 'MONTHLY';
        if (aIsMonthly && !bIsMonthly) return 1; // MONTHLY는 뒤로
        if (!aIsMonthly && bIsMonthly) return -1; // 일반 루틴은 앞으로
        return 0; // 같은 타입이면 순서 유지
      });

      setState(() {
        _todosByDate[dateKey] = todos;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading routines for date: $e');
      setState(() {
        _todosByDate[dateKey] = [];
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _dateScrollController = ScrollController();
    WidgetsBinding.instance.addObserver(this); // 생명주기 관찰자 등록

    // 저장된 날짜 인덱스로 복원 (항상 최신 상태 사용)
    _selectedDateIndex = _RoutineScreenStateManager.selectedDateIndex;

    print(
      '[RoutineScreen] initState - _selectedDateIndex: $_selectedDateIndex',
    );
    print(
      '[RoutineScreen] initState - _RoutineScreenStateManager.selectedDateIndex: ${_RoutineScreenStateManager.selectedDateIndex}',
    );

    // 초기 스크롤 위치를 선택된 날짜로 설정 (중앙에 오도록)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 다시 한 번 최신 상태 확인
      final latestDateIndex = _RoutineScreenStateManager.selectedDateIndex;
      if (mounted) {
        setState(() {
          _selectedDateIndex = latestDateIndex;
        });
        _scrollToSelectedDate(context);
        _refreshCurrentDate();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 날짜 인덱스가 변경되었는지 확인하고 업데이트
    final latestDateIndex = _RoutineScreenStateManager.selectedDateIndex;
    if (_selectedDateIndex != latestDateIndex && mounted) {
      setState(() {
        _selectedDateIndex = latestDateIndex;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToSelectedDate(context);
          _refreshCurrentDate();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 다시 활성화될 때 선택된 날짜 유지하고 데이터 새로고침
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        setState(() {
          // 선택된 날짜 인덱스 유지 (오늘 날짜로 강제 설정하지 않음)
          _selectedDateIndex = _RoutineScreenStateManager.selectedDateIndex;
        });
        _scrollToSelectedDate(context);
        _refreshCurrentDate();
      }
    }
  }

  /// 현재 날짜의 데이터를 강제로 새로고침
  void _refreshCurrentDate() {
    final selectedDate = _getSelectedDate();
    final dateKey = _formatDateKey(selectedDate);

    print('[RoutineScreen] _refreshCurrentDate 호출: $dateKey');

    // 캐시된 데이터 완전히 삭제
    _todosByDate.remove(dateKey);
    print('[RoutineScreen] 캐시 삭제 완료');

    final dateSelectedRoutines =
        _RoutineScreenStateManager.getSelectedRoutinesForDate(dateKey);

    print('[RoutineScreen] 저장된 선택된 루틴 ID들: $dateSelectedRoutines');

    if (dateSelectedRoutines != null && dateSelectedRoutines.isNotEmpty) {
      print('[RoutineScreen] 선택된 루틴이 있음, _loadSelectedRoutines 호출');
      _loadSelectedRoutines(dateSelectedRoutines, forceRefresh: true);
    } else {
      print('[RoutineScreen] 선택된 루틴이 없음, _loadRoutinesForDate 호출');
      _loadRoutinesForDate(selectedDate, forceRefresh: true);
    }
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
          final aCompleted =
              a['checkType'] == 'done' || a['checkType'] == 'failed';
          final bCompleted =
              b['checkType'] == 'done' || b['checkType'] == 'failed';
          if (aCompleted == bCompleted) return 0;
          return aCompleted ? 1 : -1;
        }

        final aIndex = priorityOrder.indexOf(aRoutineId);
        final bIndex = priorityOrder.indexOf(bRoutineId);

        // 우선순위 순서에 없는 항목은 뒤로
        if (aIndex == -1 && bIndex == -1) {
          final aCompleted =
              a['checkType'] == 'done' || a['checkType'] == 'failed';
          final bCompleted =
              b['checkType'] == 'done' || b['checkType'] == 'failed';
          if (aCompleted == bCompleted) return 0;
          return aCompleted ? 1 : -1;
        }
        if (aIndex == -1) return 1;
        if (bIndex == -1) return -1;

        // 같은 우선순위 내에서는 체크 상태 기준 정렬
        if (aIndex == bIndex) {
          final aCompleted =
              a['checkType'] == 'done' || a['checkType'] == 'failed';
          final bCompleted =
              b['checkType'] == 'done' || b['checkType'] == 'failed';
          if (aCompleted == bCompleted) return 0;
          return aCompleted ? 1 : -1;
        }

        return aIndex.compareTo(bIndex);
      });

      // 체크된 항목을 하단으로 이동 (우선순위 순서는 유지)
      // 'done'과 'failed' 모두 체크된 것으로 간주
      final unchecked = todosList
          .where(
            (todo) =>
                todo['checkType'] != 'done' && todo['checkType'] != 'failed',
          )
          .toList();
      final checked = todosList
          .where(
            (todo) =>
                todo['checkType'] == 'done' || todo['checkType'] == 'failed',
          )
          .toList();

      return [...unchecked, ...checked];
    }

    // 우선순위 순서가 없으면 기존 로직 사용
    // 'done'과 'failed' 모두 체크된 것으로 간주
    final unchecked = _todos
        .where(
          (todo) =>
              todo['checkType'] != 'done' && todo['checkType'] != 'failed',
        )
        .toList();
    final checked = _todos
        .where(
          (todo) =>
              todo['checkType'] == 'done' || todo['checkType'] == 'failed',
        )
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

  void _toggleCheck(int index) async {
    final todos = _todos; // 현재 날짜의 할 일 목록
    final routineId = todos[index]['routineId'] as int?;
    final currentState = todos[index]['checkType'] as String;
    final newState = currentState == 'done' ? 'none' : 'done';

    // 먼저 UI 업데이트 (즉시 반응)
    setState(() {
      todos[index]['checkType'] = newState;

      // 체크할 때 완료 횟수 증가 (로컬에서 즉시 업데이트)
      if (newState == 'done') {
        final currentCount = todos[index]['completedCount'] as int? ?? 0;
        final frequency = todos[index]['scheduleFrequency'] as int? ?? 1;
        final newCount = currentCount + 1;
        todos[index]['completedCount'] = newCount;

        // category 업데이트 (숫자 부분만 변경)
        final currentCategory = todos[index]['category'] as String;
        final scheduleType = todos[index]['scheduleType'] as String? ?? 'DAILY';

        if (scheduleType == 'WEEKLY' || scheduleType == 'MONTHLY') {
          // WEEKLY/MONTHLY: category가 이미 "숫자/숫자" 형식이므로 교체
          final categoryParts = currentCategory.split('\n');
          if (categoryParts.length >= 2) {
            // 시간 부분은 유지하고 숫자 부분만 업데이트
            todos[index]['category'] =
                '${categoryParts[0]}\n$newCount/$frequency';
          } else {
            // 숫자만 있는 경우
            todos[index]['category'] = '$newCount/$frequency';
          }
        } else {
          // DAILY: category에 숫자 추가 또는 업데이트
          final categoryParts = currentCategory.split('\n');
          if (categoryParts.length >= 2) {
            // 이미 숫자가 있으면 업데이트
            todos[index]['category'] =
                '${categoryParts[0]}\n$newCount/$frequency';
          } else {
            // 숫자가 없으면 추가
            todos[index]['category'] = '$currentCategory\n$newCount/$frequency';
          }
        }

        print('[RoutineScreen] 로컬 완료 횟수 증가: ${currentCount} -> $newCount');
      } else {
        // 체크 해제 시 숫자 감소
        final currentCount = todos[index]['completedCount'] as int? ?? 0;
        final frequency = todos[index]['scheduleFrequency'] as int? ?? 1;
        final newCount = currentCount > 0 ? currentCount - 1 : 0;
        todos[index]['completedCount'] = newCount;

        // category 업데이트
        final currentCategory = todos[index]['category'] as String;
        final scheduleType = todos[index]['scheduleType'] as String? ?? 'DAILY';

        if (scheduleType == 'WEEKLY' || scheduleType == 'MONTHLY') {
          final categoryParts = currentCategory.split('\n');
          if (categoryParts.length >= 2) {
            todos[index]['category'] =
                '${categoryParts[0]}\n$newCount/$frequency';
          } else {
            todos[index]['category'] = '$newCount/$frequency';
          }
        } else {
          final categoryParts = currentCategory.split('\n');
          if (categoryParts.length >= 2) {
            todos[index]['category'] =
                '${categoryParts[0]}\n$newCount/$frequency';
          } else {
            todos[index]['category'] = '$currentCategory\n$newCount/$frequency';
          }
        }
      }

      // 날짜별 할 일 목록 업데이트
      final selectedDate = _getSelectedDate();
      final dateKey = _formatDateKey(selectedDate);
      _todosByDate[dateKey] = todos;
      // 체크 상태 저장
      final key = _getTodoKey(todos[index]);
      _RoutineScreenStateManager.setCheckState(key, newState);
    });

    // 체크할 때만 실행 API 호출 (체크 해제 시에는 호출하지 않음)
    if (newState == 'done' && routineId != null) {
      // 루틴 실행 API 호출 (백그라운드에서 실행)
      RoutineService.executeRoutine(
            routineId: routineId,
            userId: 1, // TODO: 실제 user_id 사용
            runTime: todos[index]['runMinutes'] as int?,
          )
          .then((success) {
            if (!success) {
              print('[RoutineScreen] 루틴 실행 API 호출 실패: routineId=$routineId');
              // 실패 시 체크 해제 및 숫자 되돌리기
              if (mounted) {
                setState(() {
                  final selectedDate = _getSelectedDate();
                  final dateKey = _formatDateKey(selectedDate);
                  final currentTodos = _todosByDate[dateKey] ?? [];
                  final todoIndex = currentTodos.indexWhere(
                    (t) => t['routineId'] == routineId,
                  );
                  if (todoIndex != -1) {
                    currentTodos[todoIndex]['checkType'] = 'none';
                    final currentCount =
                        currentTodos[todoIndex]['completedCount'] as int? ?? 0;
                    if (currentCount > 0) {
                      currentTodos[todoIndex]['completedCount'] =
                          currentCount - 1;
                    }
                    _todosByDate[dateKey] = currentTodos;
                    final key = _getTodoKey(currentTodos[todoIndex]);
                    _RoutineScreenStateManager.setCheckState(key, 'none');
                  }
                });
              }
            } else {
              print('[RoutineScreen] 루틴 실행 성공: routineId=$routineId');
              // 성공 시에는 이미 로컬에서 업데이트했으므로 추가 작업 불필요
              // 루틴 목록을 다시 로드하지 않아서 루틴이 사라지지 않음
            }
          })
          .catchError((error) {
            print('[RoutineScreen] 루틴 실행 API 에러: $error');
            // 에러 시 체크 해제 및 숫자 되돌리기
            if (mounted) {
              setState(() {
                final selectedDate = _getSelectedDate();
                final dateKey = _formatDateKey(selectedDate);
                final currentTodos = _todosByDate[dateKey] ?? [];
                final todoIndex = currentTodos.indexWhere(
                  (t) => t['routineId'] == routineId,
                );
                if (todoIndex != -1) {
                  currentTodos[todoIndex]['checkType'] = 'none';
                  final currentCount =
                      currentTodos[todoIndex]['completedCount'] as int? ?? 0;
                  if (currentCount > 0) {
                    currentTodos[todoIndex]['completedCount'] =
                        currentCount - 1;
                  }
                  _todosByDate[dateKey] = currentTodos;
                  final key = _getTodoKey(currentTodos[todoIndex]);
                  _RoutineScreenStateManager.setCheckState(key, 'none');
                }
              });
            }
          });
    }
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
                        // 현재 선택된 탭을 다시 누르면 오늘 날짜로 이동
                        if (index == _selectedTabIndex) {
                          setRoutineScreenToToday(); // 오늘 날짜로 설정
                          setState(() {
                            _selectedDateIndex = 15; // 오늘 날짜 (인덱스 15)
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

      // 디버그: 인덱스 15가 오늘 날짜인지 확인
      if (index == 15) {
        print(
          '[RoutineScreen] _buildDateCalendar - 인덱스 15의 날짜: ${date.year}-${date.month}-${date.day}, 오늘: ${today.year}-${today.month}-${today.day}',
        );
        if (date.day != today.day) {
          print('[RoutineScreen] ⚠️ 경고: 인덱스 15의 날짜가 오늘 날짜와 일치하지 않습니다!');
        }
      }

      return {
        'day': date.day,
        'label': weekdays[date.weekday - 1], // weekday는 1-7
        'date': date,
      };
    });

    // 날짜 선택은 자유롭게 허용 (강제로 15로 리셋하지 않음)

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
              // 날짜 인덱스 업데이트 (사용자가 다른 날짜를 선택할 수 있음)
              setState(() {
                _selectedDateIndex = index;
                _RoutineScreenStateManager.selectedDateIndex = index;
              });

              // 날짜 변경 시 즉시 새로고침 (캐시 삭제 후 최신 데이터 로드)
              _refreshCurrentDate();

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
                            _sortedTodos[index - 1]['checkType'] != 'failed' &&
                            (todo['checkType'] == 'done' ||
                                todo['checkType'] == 'failed');

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
                              onView: () async {
                                // View 버튼 클릭 시 루틴 수정 화면으로 이동
                                final routineId = todo['routineId'] as int?;
                                if (routineId != null) {
                                  try {
                                    // 루틴 데이터 가져오기
                                    final allRoutines =
                                        await RoutineService.getAllRoutines();
                                    final routine = allRoutines.firstWhere(
                                      (r) => r.id == routineId,
                                      orElse: () =>
                                          throw Exception('루틴을 찾을 수 없습니다'),
                                    );
                                    if (mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ViewSaveScreen(routine: routine),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    print('[RoutineScreen] 루틴 데이터 로드 실패: $e');
                                  }
                                }
                              },
                              onFail: () async {
                                // Fail 버튼 클릭 시 루틴을 실패 상태로 표시
                                final routineId = todo['routineId'] as int?;
                                if (routineId != null) {
                                  final selectedDate = _getSelectedDate();
                                  final dateKey = _formatDateKey(selectedDate);
                                  final key = _getTodoKey(todo);

                                  // 먼저 UI 업데이트 (즉시 반응)
                                  setState(() {
                                    final currentTodos =
                                        _todosByDate[dateKey] ?? [];
                                    final todoIndex = currentTodos.indexWhere(
                                      (t) => t['routineId'] == routineId,
                                    );
                                    if (todoIndex != -1) {
                                      currentTodos[todoIndex]['checkType'] =
                                          'failed';
                                      _todosByDate[dateKey] = currentTodos;
                                    }
                                  });

                                  // 체크 상태 저장
                                  _RoutineScreenStateManager.setCheckState(
                                    key,
                                    'failed',
                                  );

                                  // 백엔드 API 호출 (status: 3 = failed)
                                  final success =
                                      await RoutineService.executeRoutine(
                                        routineId: routineId,
                                        userId: 1, // TODO: 실제 user_id 사용
                                        runTime: todo['runMinutes'] as int?,
                                        status: 3, // 3=failed (실패)
                                      );

                                  if (!success) {
                                    print(
                                      '[RoutineScreen] 루틴 실패 API 호출 실패: routineId=$routineId',
                                    );
                                    // 실패 시 UI 되돌리기
                                    if (mounted) {
                                      setState(() {
                                        final currentTodos =
                                            _todosByDate[dateKey] ?? [];
                                        final todoIndex = currentTodos
                                            .indexWhere(
                                              (t) =>
                                                  t['routineId'] == routineId,
                                            );
                                        if (todoIndex != -1) {
                                          currentTodos[todoIndex]['checkType'] =
                                              'none';
                                          _todosByDate[dateKey] = currentTodos;
                                        }
                                      });
                                      _RoutineScreenStateManager.setCheckState(
                                        key,
                                        'none',
                                      );
                                    }
                                  } else {
                                    // 스와이프 상태 초기화
                                    SwipeStateManager().clearSwipedCard();
                                  }
                                }
                              },
                              onDelete: () {
                                // Delete 버튼 클릭 시 해당 날짜의 루틴 목록에서 제거
                                final routineId = todo['routineId'] as int?;
                                if (routineId != null) {
                                  final selectedDate = _getSelectedDate();
                                  final dateKey = _formatDateKey(selectedDate);

                                  // 날짜별 선택된 루틴 ID 목록에서 제거
                                  final dateSelectedRoutines =
                                      _RoutineScreenStateManager.getSelectedRoutinesForDate(
                                        dateKey,
                                      );
                                  if (dateSelectedRoutines != null) {
                                    dateSelectedRoutines.remove(routineId);
                                    _RoutineScreenStateManager.setSelectedRoutinesForDate(
                                      dateKey,
                                      dateSelectedRoutines,
                                    );
                                  }

                                  // 화면에서도 제거
                                  setState(() {
                                    _todosByDate[dateKey] =
                                        _todosByDate[dateKey]!
                                            .where(
                                              (t) =>
                                                  t['routineId'] != routineId,
                                            )
                                            .toList();
                                  });
                                }
                              },
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
