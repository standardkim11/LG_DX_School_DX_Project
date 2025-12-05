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
import '../Services/routine_service.dart';

class ViewAllScreen extends StatefulWidget {
  final String? selectedDateKey; // 선택된 날짜 키 (YYYY-MM-DD 형식)

  const ViewAllScreen({super.key, this.selectedDateKey});

  @override
  State<ViewAllScreen> createState() => _ViewAllScreenState();
}

class _ViewAllScreenState extends State<ViewAllScreen> {
  int _selectedTabIndex = 1; // routine 탭이 선택된 상태
  bool _isLoading = true;
  List<ViewAllRoutineItem> _allRoutines = [];
  Set<int> _selectedRoutineIds = {}; // 체크된 루틴 ID들
  int _selectedDateIndex = 15; // 기본 날짜 인덱스 (12일 금요일)
  ScrollController? _dateScrollController;

  @override
  void initState() {
    super.initState();
    _dateScrollController = ScrollController();

    // selectedDateKey로부터 초기 날짜 인덱스 설정
    if (widget.selectedDateKey != null) {
      _selectedDateIndex = _getDateIndexFromKey(widget.selectedDateKey);
    }

    _loadAllRoutines();

    // 초기 스크롤 위치 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate(context);
    });
  }

  @override
  void dispose() {
    _dateScrollController?.dispose();
    super.dispose();
  }

  Future<void> _loadAllRoutines() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final routines = await RoutineService.getAllRoutines();
      setState(() {
        _allRoutines = routines;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading all routines: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleRoutineSelection(int routineId) {
    setState(() {
      if (_selectedRoutineIds.contains(routineId)) {
        _selectedRoutineIds.remove(routineId);
      } else {
        _selectedRoutineIds.add(routineId);
      }
    });
  }

  Future<bool> _showConfirmDialog({VoidCallback? onConfirm}) async {
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

  Future<bool> _onWillPop() async {
    if (_selectedRoutineIds.isNotEmpty) {
      return await _showConfirmDialog();
    }
    return true;
  }

  void _onSelectComplete() {
    if (_selectedRoutineIds.isEmpty) {
      return; // 선택된 루틴이 없으면 아무것도 하지 않음
    }

    // 체크된 루틴 ID들에 해당하는 루틴 객체들을 추출
    final selectedRoutines = _allRoutines
        .where((routine) => _selectedRoutineIds.contains(routine.id))
        .toList();

    // 체크된 루틴 ID들을 전역 상태 관리자에 저장
    setSelectedRoutineIds(_selectedRoutineIds);

    // 현재 선택된 날짜 키 계산
    final selectedDate = _getSelectedDate();
    final currentDateKey = _formatDateKey(selectedDate);

    // PriorityScreen으로 이동하면서 선택된 루틴들과 날짜 정보 전달
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PriorityScreen(
          selectedRoutines: selectedRoutines,
          selectedDateKey: currentDateKey,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
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
          child: GestureDetector(
            onTap: () {
              // 선택 중일 때 빈 공간을 눌렀을 때 확인 팝업 표시
              if (_selectedRoutineIds.isNotEmpty) {
                _showConfirmDialog();
              }
            },
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildGreeting(context),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      child: CustomTabBar(
                        selectedIndex: _selectedTabIndex,
                        onTabChanged: (index) async {
                          // routine 탭(index 1)을 클릭한 경우
                          if (index == 1) {
                            // 선택 중인 루틴이 있으면 확인 팝업 표시
                            if (_selectedRoutineIds.isNotEmpty) {
                              final confirmed = await _showConfirmDialog();
                              // NO를 선택하면 아무것도 하지 않음 (탭 이동 안 함)
                              if (!confirmed) return;

                              // YES를 선택했을 때만 화면 이동
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
                            } else {
                              // 선택 중인 루틴이 없으면 바로 routine 화면으로 이동
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
                            }
                            return;
                          }

                          // 다른 탭(todo, dashboard)을 클릭한 경우
                          // 같은 탭을 다시 클릭한 경우에도 선택 중인 루틴이 있으면 확인 팝업 표시
                          if (index == _selectedTabIndex &&
                              _selectedRoutineIds.isEmpty) {
                            return;
                          }

                          // 선택 중인 루틴이 있으면 확인 팝업 표시
                          if (_selectedRoutineIds.isNotEmpty) {
                            final confirmed = await _showConfirmDialog();
                            // NO를 선택하면 아무것도 하지 않음 (탭 이동 안 함)
                            if (!confirmed) return;

                            // YES를 선택했을 때만 화면 이동
                            if (index == 0) {
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
                                (route) => false,
                              );
                            } else if (index == 2) {
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
                                (route) => false,
                              );
                            }
                          } else {
                            // 선택 중인 루틴이 없으면 바로 이동
                            if (index == 0) {
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
                                (route) => false,
                              );
                            } else if (index == 2) {
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
                                (route) => false,
                              );
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 날짜 캘린더
                    _buildDateCalendar(context),
                    const SizedBox(height: 15),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildRoutineGrid(),
                    ),
                    const CustomBottomNavigation(currentScreen: 'routine'),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 60 + MediaQuery.of(context).padding.bottom,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppColors.backgroundGray,
                    ),
                    child: GestureDetector(
                      onTap: _onSelectComplete,
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        decoration: ShapeDecoration(
                          color: AppColors.textAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            '선택 완료',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'LG Smart_H',
                              fontWeight: FontWeight.w700,
                              height: 1.43,
                              color: Colors.white,
                            ),
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

  Widget _buildRoutineGrid() {
    if (_allRoutines.isEmpty) {
      return Center(
        child: Text(
          '등록된 루틴이 없습니다.',
          style: AppTextStyles.todoCategory(context),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('나의 루틴 목록', style: AppTextStyles.sectionTitle(context)),
          const SizedBox(height: 15),
          // 그리드 레이아웃: 2열
          _buildGridItems(),
        ],
      ),
    );
  }

  Widget _buildGridItems() {
    // 2열 그리드를 위한 행 생성
    final List<Widget> rows = [];
    for (int i = 0; i < _allRoutines.length; i += 2) {
      final rowItems = <Widget>[];

      // 첫 번째 아이템
      rowItems.add(Expanded(child: _buildRoutineCard(_allRoutines[i])));

      // 두 번째 아이템 (있으면)
      if (i + 1 < _allRoutines.length) {
        rowItems.add(const SizedBox(width: 8));
        rowItems.add(Expanded(child: _buildRoutineCard(_allRoutines[i + 1])));
      } else {
        // 홀수 개일 때 빈 공간
        rowItems.add(const Expanded(child: SizedBox()));
      }

      rows.add(
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: rowItems),
      );

      if (i + 2 < _allRoutines.length) {
        rows.add(const SizedBox(height: 12));
      }
    }

    return Column(children: rows);
  }

  Widget _buildRoutineCard(ViewAllRoutineItem routine) {
    final isChecked = _selectedRoutineIds.contains(routine.id);

    return GestureDetector(
      onTap: () => _toggleRoutineSelection(routine.id),
      child: Container(
        width: double.infinity,
        height: 88,
        decoration: ShapeDecoration(
          color: AppColors.backgroundWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
                          routine.name,
                          style: AppTextStyles.todoTitle(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Text(
                      routine.getTimeDisplay(),
                      style: AppTextStyles.todoCategory(context),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: ShapeDecoration(
                  color: const Color(0xFF4B57BB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  '수정',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
      ),
    );
  }

  // 날짜 인덱스 계산 (selectedDateKey 기반)
  int _getDateIndexFromKey(String? dateKey) {
    if (dateKey == null) return 15; // 기본값

    try {
      final parts = dateKey.split('-');
      if (parts.length == 3) {
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );

        // 기준일(12일 금요일) 계산
        final now = DateTime.now();
        final baseDate = DateTime(now.year, now.month, 12);
        final currentWeekday = baseDate.weekday;
        final daysUntilFriday = (5 - currentWeekday + 7) % 7;
        final referenceDate = baseDate.add(Duration(days: daysUntilFriday));

        // 날짜 차이 계산
        final daysDiff = date.difference(referenceDate).inDays;
        return (15 + daysDiff).clamp(0, 30); // 0~30 범위로 제한
      }
    } catch (e) {
      print('Error parsing dateKey: $e');
    }
    return 15;
  }

  // 날짜를 키 형식으로 변환
  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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

  // 날짜 스크롤 위치로 이동
  void _scrollToSelectedDate(BuildContext context) {
    if (_dateScrollController == null || !_dateScrollController!.hasClients)
      return;

    final screenWidth = MediaQuery.of(context).size.width;
    const cardWidth = 64.0; // DateCard 너비 (60 + margin 2*2)
    final scrollPosition =
        (_selectedDateIndex * cardWidth) - (screenWidth / 2) + (cardWidth / 2);
    _dateScrollController!.animateTo(
      scrollPosition.clamp(
        0.0,
        _dateScrollController!.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _buildDateCalendar(BuildContext context) {
    // 기준일: 12일 금요일 찾기
    final now = DateTime.now();
    final baseDate = DateTime(now.year, now.month, 12);
    final currentWeekday = baseDate.weekday;
    final daysUntilFriday = (5 - currentWeekday + 7) % 7;
    final referenceDate = baseDate.add(Duration(days: daysUntilFriday));

    // 앞뒤로 15일씩만 생성 (총 31일: 15일 전부터 15일 후까지)
    final dates = List.generate(31, (index) {
      final date = referenceDate.add(Duration(days: index - 15));
      final weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
      return {
        'day': date.day,
        'label': weekdays[date.weekday - 1],
        'date': date,
      };
    });

    return SizedBox(
      height: 80,
      child: ListView.builder(
        controller: _dateScrollController ?? ScrollController(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 1),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = index == _selectedDateIndex;
          return GestureDetector(
            onTap: () {
              // 선택 중인 루틴이 있으면 확인 팝업 표시
              if (_selectedRoutineIds.isNotEmpty) {
                _showConfirmDialog(
                  onConfirm: () {
                    // 선택 해제 후 날짜 변경
                    setState(() {
                      _selectedRoutineIds.clear();
                      _selectedDateIndex = index;
                    });
                    _scrollToSelectedDate(context);
                  },
                );
              } else {
                // 선택 중인 루틴이 없으면 날짜만 변경
                setState(() {
                  _selectedDateIndex = index;
                });
                _scrollToSelectedDate(context);
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
}
