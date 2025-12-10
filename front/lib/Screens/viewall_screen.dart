import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
import '../Services/config.dart';

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

  Future<void> _showWeatherWarningDialog(
    List<ViewAllRoutineItem> selectedRoutines,
  ) async {
    // 선택된 루틴의 우선순위 점수를 계산하여 가장 높은 루틴 추천
    String weatherMessage = '오늘 날씨는 맑음이에요.';

    try {
      if (selectedRoutines.isEmpty) {
        weatherMessage = '오늘 날씨는 맑음이에요.';
      } else {
        // 선택된 루틴의 우선순위 점수 계산
        final routineIds = selectedRoutines.map((r) => r.id).toList();

        List<String> urlsToTry = [
          ApiConfig.getBaseUrl(
            isWeb: kIsWeb,
            isAndroid: !kIsWeb && Platform.isAndroid,
            isIOS: !kIsWeb && Platform.isIOS,
          ),
        ];
        if (!kIsWeb && Platform.isAndroid && ApiConfig.useEmulator == null) {
          urlsToTry = ApiConfig.getAndroidBaseUrls();
        }

        Map<int, double>? scores;
        for (final url in urlsToTry) {
          try {
            final uri = Uri.parse('$url/recommend/priority/selected');
            final response = await http
                .post(
                  uri,
                  headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                  },
                  body: jsonEncode({'user_id': 1, 'routine_ids': routineIds}),
                )
                .timeout(
                  const Duration(seconds: 10),
                  onTimeout: () {
                    throw Exception('요청 시간 초과');
                  },
                );

            if (response.statusCode == 200) {
              final data = jsonDecode(utf8.decode(response.bodyBytes)) as List;
              scores = {};
              for (final item in data) {
                final routineId = item['routine_id'] as int;
                final score = (item['pred_priority_score'] as num).toDouble();
                scores[routineId] = score;
              }
              break;
            }
          } catch (e) {
            print('[ViewAllScreen] 우선순위 점수 API 호출 실패 ($url): $e');
            continue;
          }
        }

        // 우선순위 점수가 가장 높은 루틴 찾기
        if (scores != null && scores.isNotEmpty) {
          ViewAllRoutineItem? bestRoutine;
          double bestScore = -1.0;

          for (final routine in selectedRoutines) {
            final score = scores[routine.id] ?? 0.0;
            if (score > bestScore) {
              bestScore = score;
              bestRoutine = routine;
            }
          }

          if (bestRoutine != null) {
            // 날씨 정보 가져오기
            int? weatherCode;
            List<String> weatherUrlsToTry = [
              ApiConfig.getBaseUrl(
                isWeb: kIsWeb,
                isAndroid: !kIsWeb && Platform.isAndroid,
                isIOS: !kIsWeb && Platform.isIOS,
              ),
            ];
            if (!kIsWeb &&
                Platform.isAndroid &&
                ApiConfig.useEmulator == null) {
              weatherUrlsToTry = ApiConfig.getAndroidBaseUrls();
            }

            for (final url in weatherUrlsToTry) {
              try {
                final uri = Uri.parse('$url/recommend/weather?user_id=1');
                final response = await http
                    .get(
                      uri,
                      headers: {
                        'Content-Type': 'application/json',
                        'Accept': 'application/json',
                      },
                    )
                    .timeout(
                      const Duration(seconds: 10),
                      onTimeout: () {
                        throw Exception('요청 시간 초과');
                      },
                    );

                if (response.statusCode == 200) {
                  final data =
                      jsonDecode(utf8.decode(response.bodyBytes))
                          as Map<String, dynamic>;
                  weatherCode = data['weather_code'] as int?;
                  break;
                }
              } catch (e) {
                continue;
              }
            }

            // 한국어 조사 처리
            String particle = '';
            final routineName = bestRoutine.name;
            final lastChar = routineName.runes.last;
            if (lastChar >= 0xAC00 && lastChar <= 0xD7A3) {
              final hasFinalConsonant = (lastChar - 0xAC00) % 28 != 0;
              particle = hasFinalConsonant ? '을' : '를';
            } else {
              particle = '을';
            }

            // 날씨에 따른 추천 메시지 생성
            if (weatherCode == 2) {
              // 비
              weatherMessage =
                  '비가와서 $routineName$particle 추천드려요.\n날씨, 온도, 습도, 시간 등 요소를 고려했어요.';
            } else if (weatherCode == 3) {
              // 눈
              weatherMessage =
                  '눈이와서 $routineName$particle 추천드려요.\n날씨, 온도, 습도, 시간 등 요소를 고려했어요.';
            } else if (weatherCode == 1) {
              // 흐림
              weatherMessage =
                  '흐려서 $routineName$particle 추천드려요.\n날씨, 온도, 습도, 시간 등 요소를 고려했어요.';
            } else {
              // 맑음
              weatherMessage =
                  '맑아서 $routineName$particle 하기에 좋은 날이에요.\n날씨, 온도, 습도, 시간 등 요소를 고려했어요.';
            }
          }
        }
      }
    } catch (e) {
      print('[ViewAllScreen] 추천 메시지 생성 중 예외 발생: $e');
      weatherMessage = '오늘 날씨는 맑음이에요.';
    }

    // 날씨 정보를 로드한 후 다이얼로그 표시 (API 실패해도 기본값으로 표시)
    if (!mounted) return;

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
                      weatherMessage,
                      style: AppTextStyles.sectionTitle(
                        context,
                      ).copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              setState(() {
                                selectedButton = true;
                              });
                              Future.delayed(
                                const Duration(milliseconds: 150),
                                () async {
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    // YES: 세탁기가 없으면 추가
                                    final hasWashingRoutine = selectedRoutines
                                        .any(
                                          (routine) =>
                                              routine.name
                                                  .toLowerCase()
                                                  .contains('세탁') ||
                                              routine.name
                                                  .toLowerCase()
                                                  .contains('빨래') ||
                                              routine.routineType
                                                  .toLowerCase()
                                                  .contains('wash'),
                                        );

                                    List<ViewAllRoutineItem> finalRoutines =
                                        List.from(selectedRoutines);

                                    if (!hasWashingRoutine) {
                                      // 세탁기 루틴 찾기
                                      try {
                                        final washingRoutine = _allRoutines
                                            .firstWhere(
                                              (routine) =>
                                                  routine.name
                                                      .toLowerCase()
                                                      .contains('세탁') ||
                                                  routine.name
                                                      .toLowerCase()
                                                      .contains('빨래') ||
                                                  routine.routineType
                                                      .toLowerCase()
                                                      .contains('wash'),
                                            );

                                        // 세탁기 루틴이 존재하면 추가
                                        finalRoutines.add(washingRoutine);
                                        // 선택된 루틴 ID에도 추가
                                        _selectedRoutineIds.add(
                                          washingRoutine.id,
                                        );
                                      } catch (e) {
                                        // 세탁기 루틴이 없으면 추가하지 않음
                                        print(
                                          '[ViewAllScreen] 세탁기 루틴을 찾을 수 없습니다: $e',
                                        );
                                      }
                                    }

                                    _navigateToPriorityScreen(finalRoutines);
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
                                    // NO: 체크된 루틴만 그대로 전달 (세탁기 추가하지 않음)
                                    _navigateToPriorityScreen(selectedRoutines);
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

  /// 삭제 확인 다이얼로그 표시
  Future<void> _showDeleteConfirmDialog(ViewAllRoutineItem routine) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.backgroundWhite,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('루틴 삭제', style: AppTextStyles.todoTitle(context)),
                const SizedBox(height: 16),
                Text(
                  '${routine.name} 루틴을 삭제하시겠습니까?',
                  style: AppTextStyles.todoCategory(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop(false); // 취소
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.backgroundGray,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '취소',
                            style: TextStyle(
                              color: AppColors.textSecondary,
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
                          Navigator.of(context).pop(true); // 삭제
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '삭제',
                            style: TextStyle(
                              color: Colors.white,
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

    if (result == true) {
      // 삭제 확인
      await _deleteRoutine(routine);
    }
  }

  /// 루틴 삭제 실행
  Future<void> _deleteRoutine(ViewAllRoutineItem routine) async {
    print('[ViewAllScreen] 루틴 삭제 시작: ${routine.id}');

    final success = await RoutineService.deleteRoutine(routineId: routine.id);

    if (success) {
      print('[ViewAllScreen] 루틴 삭제 성공: ${routine.id}');
      // 선택된 루틴 ID에서도 제거
      _selectedRoutineIds.remove(routine.id);
      // 루틴 목록 새로고침
      await _loadAllRoutines();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${routine.name} 루틴이 삭제되었습니다.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      print('[ViewAllScreen] 루틴 삭제 실패: ${routine.id}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('루틴 삭제에 실패했습니다.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                  const CustomBottomNavigation(currentScreen: 'viewall'),
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
            // 삭제 버튼 (연필 아이콘 위에 배치)
            Positioned(
              right: 8,
              bottom: 40, // 연필 아이콘 위에 배치
              child: GestureDetector(
                onTap: () {
                  // 삭제 확인 다이얼로그 표시
                  _showDeleteConfirmDialog(routine);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
            // 수정 버튼 (연필 아이콘)
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
