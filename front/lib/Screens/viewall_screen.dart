import 'package:flutter/material.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/tab_bar.dart';
import '../components/bottom_navigation.dart';
import 'routine_screen.dart';
import 'todo_screen.dart';
import 'dashboard_screen.dart';
import 'priority.dart';
import 'routinesave_screen.dart';
import '../Services/routine_service.dart';

class ViewAllScreen extends StatefulWidget {
  final String? selectedDateKey; // 선택된 날짜 키 (YYYY-MM-DD 형식)

  const ViewAllScreen({super.key, this.selectedDateKey});

  @override
  State<ViewAllScreen> createState() => _ViewAllScreenState();
}

class _ViewAllScreenState extends State<ViewAllScreen>
    with WidgetsBindingObserver {
  int _selectedTabIndex = 1; // routine 탭이 선택된 상태
  bool _isLoading = true;
  List<ViewAllRoutineItem> _allRoutines = [];
  Set<int> _selectedRoutineIds = {}; // 체크된 루틴 ID들

  @override
  void initState() {
    super.initState();
    _loadAllRoutines();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 다시 활성화될 때 데이터 새로고침
    if (state == AppLifecycleState.resumed) {
      print('[ViewAllScreen] 앱이 다시 활성화됨, 루틴 목록 새로고침');
      _loadAllRoutines();
    }
  }

  Future<void> _loadAllRoutines() async {
    print('[ViewAllScreen] _loadAllRoutines 호출');
    setState(() {
      _isLoading = true;
    });

    try {
      final routines = await RoutineService.getAllRoutines();
      print('[ViewAllScreen] API에서 받은 루틴 수: ${routines.length}');
      print(
        '[ViewAllScreen] API에서 받은 루틴 ID들: ${routines.map((r) => r.id).toList()}',
      );
      print(
        '[ViewAllScreen] API에서 받은 루틴 이름들: ${routines.map((r) => r.name).toList()}',
      );

      setState(() {
        _allRoutines = routines;
        _isLoading = false;
      });

      print('[ViewAllScreen] 화면 업데이트 완료, 표시할 루틴 수: ${_allRoutines.length}');
    } catch (e) {
      print('[ViewAllScreen] Error loading all routines: $e');
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
                                    } else {
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
                                        (route) => false,
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

    // 세탁기 관련 루틴이 있는지 확인
    final hasWashingRoutine = selectedRoutines.any(
      (routine) =>
          routine.name.toLowerCase().contains('세탁') ||
          routine.name.toLowerCase().contains('빨래') ||
          routine.routineType.toLowerCase().contains('wash'),
    );

    // 세탁기 관련 루틴이 있으면 팝업 표시
    if (hasWashingRoutine) {
      _showWeatherWarningDialog(selectedRoutines);
    } else {
      // 세탁기 관련 루틴이 없으면 바로 PriorityScreen으로 이동
      _navigateToPriorityScreen(selectedRoutines);
    }
  }

  void _showWeatherWarningDialog(List<ViewAllRoutineItem> selectedRoutines) {
    showDialog(
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
                      '비가 예정된 오늘,\n세탁기를 돌리실 건가요?',
                      style: AppTextStyles.sectionTitle(
                        context,
                      ).copyWith(fontSize: 18, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
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
                                    Navigator.pop(context);
                                    // YES: 세탁기 포함하여 전달
                                    _navigateToPriorityScreen(selectedRoutines);
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
                                    Navigator.pop(context);
                                    // NO: 세탁기 관련 루틴 제외
                                    final routinesWithoutWashing =
                                        selectedRoutines
                                            .where(
                                              (routine) =>
                                                  !routine.name
                                                      .toLowerCase()
                                                      .contains('세탁') &&
                                                  !routine.name
                                                      .toLowerCase()
                                                      .contains('빨래') &&
                                                  !routine.routineType
                                                      .toLowerCase()
                                                      .contains('wash'),
                                            )
                                            .toList();
                                    _navigateToPriorityScreen(
                                      routinesWithoutWashing,
                                    );
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
  }

  void _navigateToPriorityScreen(List<ViewAllRoutineItem> selectedRoutines) {
    // 체크된 루틴 ID들을 전역 상태 관리자에 저장
    setSelectedRoutineIds(_selectedRoutineIds);

    // PriorityScreen으로 이동하면서 선택된 루틴들과 날짜 정보 전달
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PriorityScreen(
          selectedRoutines: selectedRoutines,
          selectedDateKey: widget.selectedDateKey,
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
                      onTabChanged: (index) {
                        // routine 탭(index 1)을 클릭한 경우
                        if (index == 1) {
                          // 선택 중인 루틴이 있으면 확인 팝업 표시
                          if (_selectedRoutineIds.isNotEmpty) {
                            _showConfirmDialog(
                              onConfirm: () {
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
                              },
                            );
                          } else {
                            // 선택 중인 루틴이 없으면 바로 routine 화면으로 이동
                            Navigator.pushAndRemoveUntil(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        const RoutineScreen(),
                                transitionDuration: Duration.zero,
                                reverseTransitionDuration: Duration.zero,
                              ),
                              (route) => false, // 모든 이전 화면 제거
                            );
                          }
                          return;
                        }

                        // 다른 탭(todo, dashboard)을 클릭한 경우
                        if (index == _selectedTabIndex) {
                          return;
                        }

                        // 선택 중인 루틴이 있으면 확인 팝업 표시
                        if (_selectedRoutineIds.isNotEmpty) {
                          _showConfirmDialog(
                            onConfirm: () {
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
                            },
                          );
                        } else {
                          // 선택 중인 루틴이 없으면 바로 이동
                          if (index == 0) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        const TodoScreen(),
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
                                    (context, animation, secondaryAnimation) =>
                                        const DashboardScreen(),
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
              child: GestureDetector(
                onTap: () {
                  // 수정 버튼 클릭 시 루틴 수정 페이지로 이동 (루틴 데이터 전달)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ViewSaveScreen(routine: routine),
                    ),
                  );
                },
                behavior: HitTestBehavior.opaque, // 클릭 영역 확보
                child: Image.asset(
                  'assets/viewsave_screen/Edit_icon.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
