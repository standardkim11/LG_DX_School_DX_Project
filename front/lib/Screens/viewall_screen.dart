import 'package:flutter/material.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/tab_bar.dart';
import '../components/bottom_navigation.dart';
import 'routine_screen.dart';
import 'todo_screen.dart';
import 'dashboard_screen.dart';
import '../Services/routine_service.dart';

class ViewAllScreen extends StatefulWidget {
  const ViewAllScreen({super.key});

  @override
  State<ViewAllScreen> createState() => _ViewAllScreenState();
}

class _ViewAllScreenState extends State<ViewAllScreen> {
  int _selectedTabIndex = 1; // routine 탭이 선택된 상태
  bool _isLoading = true;
  List<ViewAllRoutineItem> _allRoutines = [];
  Set<int> _selectedRoutineIds = {}; // 체크된 루틴 ID들

  @override
  void initState() {
    super.initState();
    _loadAllRoutines();
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
    // 체크된 루틴 ID들을 전역 상태 관리자에 저장
    setSelectedRoutineIds(_selectedRoutineIds);
    
    // 메인 화면으로 이동
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const RoutineScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
      (route) => false,
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
                        if (index == _selectedTabIndex) {
                          return;
                        }
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
                            } else if (index == 1) {
                              // 루틴 탭 클릭 시 루틴 화면으로 이동
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundGray,
                  ),
                  child: GestureDetector(
                    onTap: _onSelectComplete,
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
}
