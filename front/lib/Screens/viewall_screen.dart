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
      // 선택된 날짜가 있으면 해당 날짜 사용, 없으면 오늘 날짜
      final targetDate = widget.selectedDateKey ?? 
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
      
      print('[ViewAllScreen] 조회할 날짜: $targetDate');
      final routines = await RoutineService.getAllRoutines(date: targetDate);
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

  void _toggleRoutineSelection(int routineId) async {
    // 체크 상태 변경
    final wasChecked = _selectedRoutineIds.contains(routineId);
    setState(() {
      if (wasChecked) {
        _selectedRoutineIds.remove(routineId);
      } else {
        _selectedRoutineIds.add(routineId);
      }
    });

    // 체크할 때만 todo 일정과의 시간 충돌 확인
    if (!wasChecked) {
      final routine = _allRoutines.firstWhere(
        (r) => r.id == routineId,
        orElse: () => _allRoutines.first,
      );

      // preferredTime이 있는 경우에만 확인
      if (routine.preferredTime != null && routine.preferredTime!.isNotEmpty) {
        final hasConflict = await _checkTimeConflictWithTodos(routine.preferredTime!);
        if (hasConflict && mounted) {
          _showTimeConflictDialog(routine);
        }
      }
    }
  }

  /// 오늘 todo 일정과의 시간 충돌 확인
  Future<bool> _checkTimeConflictWithTodos(String routineTime) async {
    try {
      // 오늘 날짜 가져오기
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // 오늘 todo 목록 가져오기
      final todos = getTodosForDate(todayStr);

      // 루틴 시간을 분 단위로 변환
      final routineMinutes = _timeToMinutes(routineTime);
      if (routineMinutes == null) return false;

      // 각 todo의 시간과 비교 (todo 제목에서 시간 추출)
      for (final todo in todos) {
        final title = todo['title'] as String? ?? '';
        // 제목에서 시간 추출 (예: "18:30 장보기" -> "18:30")
        final timeMatch = RegExp(r'^(\d{2}:\d{2})').firstMatch(title);
        if (timeMatch != null) {
          final todoTime = timeMatch.group(1)!;
          final todoMinutes = _timeToMinutes(todoTime);
          if (todoMinutes != null) {
            // 시간 차이가 1시간(60분) 이내인지 확인
            final timeDiff = (routineMinutes - todoMinutes).abs();
            if (timeDiff <= 60) {
              return true; // 충돌 발견
            }
          }
        }
      }

      return false; // 충돌 없음
    } catch (e) {
      print('[ViewAllScreen] 시간 충돌 확인 중 오류: $e');
      return false; // 오류 발생 시 충돌 없음으로 처리
    }
  }

  /// 시간 문자열을 분 단위로 변환 (예: "19:00" -> 1140)
  int? _timeToMinutes(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return hour * 60 + minute;
      }
    } catch (e) {
      print('[ViewAllScreen] 시간 파싱 오류: $timeStr, $e');
    }
    return null;
  }

  /// 시간 충돌 팝업 표시
  void _showTimeConflictDialog(ViewAllRoutineItem routine) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '시간 충돌',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: 'LG Smart_H',
            ),
          ),
          content: const Text(
            '일정과 루틴의 수행시간이 비슷해요.\n오늘만 루틴 시간을 변경할 수 있어요.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              fontFamily: 'LG Smart_H',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                '확인',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'LG Smart_H',
                  color: Color(0xFF8863EF),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _showTimeEditDialog(routine);
              },
              child: const Text(
                '수정하기',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'LG Smart_H',
                  color: Color(0xFF8863EF),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 오늘만 루틴 시간 수정 다이얼로그
  void _showTimeEditDialog(ViewAllRoutineItem routine) {
    int? selectedHour;
    int? selectedMinute;

    // 현재 시간 파싱 (override_time이 있으면 우선, 없으면 preferred_time)
    final currentTime = routine.overrideTime ?? routine.preferredTime;
    if (currentTime != null && currentTime.contains(':')) {
      try {
        final parts = currentTime.split(':');
        if (parts.length >= 2) {
          selectedHour = int.parse(parts[0]);
          final parsedMinute = int.parse(parts[1]);
          // 가장 가까운 5분 단위로 반올림
          selectedMinute = (parsedMinute / 5).round() * 5;
          if (selectedMinute == 60) selectedMinute = 0; // 60분은 0분으로
        }
      } catch (e) {
        selectedHour = 19;
        selectedMinute = 0;
      }
    } else {
      selectedHour = 19;
      selectedMinute = 0;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            // 시간 옵션 (0-23)
            final hourOptions = List.generate(24, (i) => i);
            // 분 옵션 (0, 5, 10, ..., 55)
            final minuteOptions = List.generate(12, (i) => i * 5);

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                '오늘만 시간 변경',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'LG Smart_H',
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${routine.name}의 오늘 시간을 변경하세요.',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'LG Smart_H',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 시간 선택
                      SizedBox(
                        width: 80,
                        child: DropdownButton<int>(
                          value: selectedHour,
                          isExpanded: true,
                          items: hourOptions.map((hour) {
                            return DropdownMenuItem<int>(
                              value: hour,
                              child: Text(
                                hour.toString().padLeft(2, '0'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'LG Smart_H',
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (int? newHour) {
                            if (newHour != null) {
                              setDialogState(() {
                                selectedHour = newHour;
                              });
                            }
                          },
                        ),
                      ),
                      const Text(
                        ' : ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'LG Smart_H',
                        ),
                      ),
                      // 분 선택
                      SizedBox(
                        width: 80,
                        child: DropdownButton<int>(
                          value: selectedMinute,
                          isExpanded: true,
                          items: minuteOptions.map((minute) {
                            return DropdownMenuItem<int>(
                              value: minute,
                              child: Text(
                                minute.toString().padLeft(2, '0'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'LG Smart_H',
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (int? newMinute) {
                            if (newMinute != null) {
                              setDialogState(() {
                                selectedMinute = newMinute;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text(
                    '취소',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'LG Smart_H',
                      color: Colors.grey,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    if (selectedHour != null && selectedMinute != null) {
                      final newTime =
                          '${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}';
                      await _saveTimeOverride(routine.id, newTime);
                      Navigator.of(dialogContext).pop();
                      // 루틴 목록 새로고침
                      _loadAllRoutines();
                    }
                  },
                  child: const Text(
                    '저장',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'LG Smart_H',
                      color: Color(0xFF8863EF),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 오늘 날짜의 루틴 시간 오버라이드 저장
  Future<void> _saveTimeOverride(int routineId, String overrideTime) async {
    try {
      // 오늘 날짜 가져오기
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // API 호출
      List<String> urlsToTry = [ApiConfig.getBaseUrl(
        isWeb: kIsWeb,
        isAndroid: !kIsWeb && Platform.isAndroid,
        isIOS: !kIsWeb && Platform.isIOS,
      )];
      if (!kIsWeb && Platform.isAndroid && ApiConfig.useEmulator == null) {
        urlsToTry = ApiConfig.getAndroidBaseUrls();
      }

      for (final url in urlsToTry) {
        try {
          final uri = Uri.parse('$url/routine-time-override');
          final response = await http
              .post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                body: jsonEncode({
                  'routine_id': routineId,
                  'override_date': todayStr,
                  'override_time': overrideTime,
                }),
              )
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  throw Exception('요청 시간 초과');
                },
              );

          if (response.statusCode == 200) {
            print('[ViewAllScreen] 루틴 시간 오버라이드 저장 성공: $url');
            return;
          } else {
            print(
              '[ViewAllScreen] 루틴 시간 오버라이드 저장 실패: HTTP ${response.statusCode}',
            );
          }
        } catch (e) {
          print('[ViewAllScreen] 루틴 시간 오버라이드 저장 실패 ($url): $e');
          continue;
        }
      }
    } catch (e) {
      print('[ViewAllScreen] 루틴 시간 오버라이드 저장 중 오류: $e');
    }
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

  Future<void> _onSelectComplete() async {
    if (_selectedRoutineIds.isEmpty) {
      return; // 선택된 루틴이 없으면 아무것도 하지 않음
    }

    // 체크된 루틴 ID들에 해당하는 루틴 객체들을 추출
    final selectedRoutines = _allRoutines
        .where((routine) => _selectedRoutineIds.contains(routine.id))
        .toList();

    // 모든 루틴의 우선순위 점수 계산
    final allRoutineIds = _allRoutines.map((r) => r.id).toList();

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

    Map<int, double>? allScores;
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
              body: jsonEncode({'user_id': 1, 'routine_ids': allRoutineIds}),
            )
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception('요청 시간 초과');
              },
            );

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes)) as List;
          allScores = {};
          for (final item in data) {
            final routineId = item['routine_id'] as int;
            final score = (item['pred_priority_score'] as num).toDouble();
            allScores[routineId] = score;
          }
          break;
        }
      } catch (e) {
        print('[ViewAllScreen] 우선순위 점수 API 호출 실패 ($url): $e');
        continue;
      }
    }

    // 우선순위 점수가 가장 높은 루틴 찾기 (모든 루틴 중)
    if (allScores != null && allScores.isNotEmpty) {
      int? bestRoutineId;
      double bestScore = double.negativeInfinity;

      for (final entry in allScores.entries) {
        if (entry.value > bestScore) {
          bestScore = entry.value;
          bestRoutineId = entry.key;
        }
      }

      // 가장 높은 점수의 루틴이 선택된 루틴 목록에 포함되어 있는지 확인
      if (bestRoutineId != null &&
          _selectedRoutineIds.contains(bestRoutineId)) {
        // 선택된 루틴 중에 가장 우선순위가 높은 루틴이 있으면 바로 priority screen으로 이동
        print(
          '[ViewAllScreen] 가장 우선순위가 높은 루틴이 선택되어 있음: routineId=$bestRoutineId, score=$bestScore',
        );
        _navigateToPriorityScreen(selectedRoutines);
        return;
      } else {
        // 가장 우선순위가 높은 루틴이 선택되지 않았으면 추천 팝업 표시
        print(
          '[ViewAllScreen] 가장 우선순위가 높은 루틴이 선택되지 않음: routineId=$bestRoutineId, score=$bestScore',
        );
        _showRecommendationDialog(selectedRoutines, bestRoutineId, allScores);
        return;
      }
    }

    // 우선순위 점수를 가져올 수 없으면 기본 동작 (바로 priority screen으로 이동)
    print('[ViewAllScreen] 우선순위 점수를 가져올 수 없어서 기본 동작 수행');
    _navigateToPriorityScreen(selectedRoutines);
  }

  Future<void> _showRecommendationDialog(
    List<ViewAllRoutineItem> selectedRoutines,
    int? bestRoutineId,
    Map<int, double> allScores,
  ) async {
    // 추천할 루틴 찾기
    ViewAllRoutineItem? bestRoutine;
    if (bestRoutineId != null) {
      try {
        bestRoutine = _allRoutines.firstWhere(
          (routine) => routine.id == bestRoutineId,
        );
      } catch (e) {
        print('[ViewAllScreen] 추천 루틴을 찾을 수 없음: $e');
      }
    }

    if (bestRoutine == null) {
      // 추천 루틴을 찾을 수 없으면 바로 priority screen으로 이동
      _navigateToPriorityScreen(selectedRoutines);
      return;
    }

    // 날씨 정보 가져오기
    int? weatherCode;
    List<String> weatherUrlsToTry = [
      ApiConfig.getBaseUrl(
        isWeb: kIsWeb,
        isAndroid: !kIsWeb && Platform.isAndroid,
        isIOS: !kIsWeb && Platform.isIOS,
      ),
    ];
    if (!kIsWeb && Platform.isAndroid && ApiConfig.useEmulator == null) {
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
    String weatherMessage;
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

    // 팝업 표시
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
                                    // YES: 추천 루틴을 선택된 루틴 목록에 추가
                                    List<ViewAllRoutineItem> finalRoutines =
                                        List.from(selectedRoutines);

                                    // 추천 루틴이 이미 선택되어 있지 않으면 추가
                                    if (bestRoutine != null &&
                                        !_selectedRoutineIds.contains(
                                          bestRoutine.id,
                                        )) {
                                      finalRoutines.add(bestRoutine);
                                      _selectedRoutineIds.add(bestRoutine.id);
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
                                    // NO: 체크된 루틴만 그대로 전달
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '나의 루틴 목록',
            style: AppTextStyles.sectionTitle(context).copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
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
        rowItems.add(const SizedBox(width: 12));
        rowItems.add(Expanded(child: _buildRoutineCard(_allRoutines[i + 1])));
      } else {
        // 홀수 개일 때 빈 공간
        rowItems.add(const Expanded(child: SizedBox()));
      }

      rows.add(
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: rowItems),
      );

      if (i + 2 < _allRoutines.length) {
        rows.add(const SizedBox(height: 16));
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
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isChecked ? AppColors.textAccent : AppColors.borderLight,
            width: isChecked ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isChecked
                              ? AppColors.textAccent
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: isChecked ? 0 : 2,
                            color: isChecked
                                ? AppColors.textAccent
                                : AppColors.textUnselected,
                          ),
                        ),
                        child: isChecked
                            ? const Center(
                                child: Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          routine.name,
                          style: AppTextStyles.todoTitle(context).copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isChecked
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: Text(
                      routine.getTimeDisplay(),
                      style: AppTextStyles.todoCategory(context).copyWith(
                        fontSize: 13,
                        color: AppColors.textSecondary.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 삭제 버튼 (연필 아이콘 위에 배치)
            Positioned(
              right: 12,
              top: 12,
              child: GestureDetector(
                onTap: () {
                  // 삭제 확인 다이얼로그 표시
                  _showDeleteConfirmDialog(routine);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundGray,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: Color(0xFF4B57BB),
                  ),
                ),
              ),
            ),
            // 수정 버튼 (연필 아이콘)
            Positioned(
              right: 12,
              bottom: 12,
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
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundGray,
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'assets/viewsave_screen/Edit_icon.png',
                    width: 16,
                    height: 16,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.edit,
                        size: 16,
                        color: Color(0xFF4B57BB),
                      );
                    },
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
