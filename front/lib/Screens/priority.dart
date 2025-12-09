import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/bottom_navigation.dart';
import '../Services/routine_service.dart';
import '../Services/config.dart';
import 'viewall_screen.dart';
import 'routine_screen.dart';

class PriorityScreen extends StatefulWidget {
  final List<ViewAllRoutineItem> selectedRoutines;
  final String? selectedDateKey; // 선택된 날짜 키 (YYYY-MM-DD 형식)
  final bool shouldLoadRoutines; // 루틴을 자동으로 로드할지 여부

  const PriorityScreen({
    super.key,
    required this.selectedRoutines,
    this.selectedDateKey,
    this.shouldLoadRoutines = false,
  });

  @override
  State<PriorityScreen> createState() => _PriorityScreenState();
}

class _PriorityScreenState extends State<PriorityScreen> {
  List<Map<String, dynamic>> _routines = [];
  String _weatherMessage = '오늘 날씨 정보를 불러오는 중...';

  // API 베이스 URL
  static String get baseUrl {
    return ApiConfig.getBaseUrl(
      isWeb: kIsWeb,
      isAndroid: !kIsWeb && Platform.isAndroid,
      isIOS: !kIsWeb && Platform.isIOS,
    );
  }

  static const int userId = 1;

  @override
  void initState() {
    super.initState();
    if (widget.shouldLoadRoutines && widget.selectedRoutines.isEmpty) {
      // 루틴을 자동으로 로드해야 하는 경우
      _loadAllRoutines();
    } else {
      // 이미 루틴이 전달된 경우
      _loadPriorityScores();
    }
    _loadWeatherInfo();
  }

  Future<void> _loadAllRoutines() async {
    try {
      final allRoutines = await RoutineService.getAllRoutines();
      if (mounted) {
        // 로드한 루틴으로 selectedRoutines 업데이트 후 점수 로드
        setState(() {
          // selectedRoutines는 final이므로 새로운 위젯으로 교체해야 하지만,
          // 대신 _loadPriorityScores를 호출할 때 allRoutines를 사용
        });
        // 임시로 루틴을 저장하고 점수 로드
        _loadPriorityScoresWithRoutines(allRoutines);
      }
    } catch (e) {
      print('[PriorityScreen] 루틴 로딩 실패: $e');
      if (mounted) {
        setState(() {
          // 에러 발생 시 빈 상태로 표시
        });
      }
    }
  }

  Future<void> _loadPriorityScoresWithRoutines(
    List<ViewAllRoutineItem> routines,
  ) async {
    if (routines.isEmpty) {
      return;
    }

    try {
      // 우선순위 점수 API 호출
      final routineIds = routines.map((r) => r.id).toList();

      // Android인 경우 여러 URL 시도
      List<String> urlsToTry = [baseUrl];
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
                body: jsonEncode({
                  'user_id': userId,
                  'routine_ids': routineIds,
                }),
              )
              .timeout(
                const Duration(seconds: 120), // 실제 기기 네트워크 고려하여 120초로 증가
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
            break; // 성공하면 종료
          }
        } catch (e) {
          print('[PriorityScreen] $url 연결 실패: $e');
          continue;
        }
      }

      // MONTHLY 루틴과 그 외 루틴 분리
      final monthlyRoutines = <ViewAllRoutineItem>[];
      final otherRoutines = <ViewAllRoutineItem>[];

      for (final routine in routines) {
        if (routine.scheduleType.toUpperCase() == 'MONTHLY') {
          monthlyRoutines.add(routine);
        } else {
          otherRoutines.add(routine);
        }
      }

      // 그 외 루틴은 점수 기준 내림차순 정렬
      otherRoutines.sort((a, b) {
        final scoreA = scores?[a.id] ?? 0.0;
        final scoreB = scores?[b.id] ?? 0.0;
        if (scoreA != scoreB) {
          return scoreB.compareTo(scoreA);
        }
        return _compareByTime(a, b);
      });

      // MONTHLY 루틴도 점수 기준 내림차순 정렬
      monthlyRoutines.sort((a, b) {
        final scoreA = scores?[a.id] ?? 0.0;
        final scoreB = scores?[b.id] ?? 0.0;
        if (scoreA != scoreB) {
          return scoreB.compareTo(scoreA);
        }
        return _compareByTime(a, b);
      });

      // 최종 리스트: 그 외 루틴 + MONTHLY 루틴
      final finalRoutines = [...otherRoutines, ...monthlyRoutines];

      // 전달받은 루틴들을 화면에서 사용할 형식으로 변환
      _routines = finalRoutines.asMap().entries.map((entry) {
        final routine = entry.value;
        final score = scores?[routine.id];
        return {
          'key': ValueKey('routine_${routine.id}'),
          'title': routine.name,
          'time': routine.getTimeDisplay(),
          'iconSize': _getIconSize(routine.routineType),
          'hasUrgentBadge': false,
          'imagePath': _getImagePath(routine.routineType),
          'routineId': routine.id,
          'preferredTime': routine.preferredTime,
          'priorityScore': score,
          'scheduleType': routine.scheduleType,
        };
      }).toList();

      if (mounted) {
        setState(() {
          // 점수 로딩 완료
        });
      }
    } catch (e) {
      print('[PriorityScreen] 우선순위 점수 로딩 실패: $e');
      // 에러 발생 시 점수 없이 표시
      final monthlyRoutines = <ViewAllRoutineItem>[];
      final otherRoutines = <ViewAllRoutineItem>[];

      for (final routine in routines) {
        if (routine.scheduleType.toUpperCase() == 'MONTHLY') {
          monthlyRoutines.add(routine);
        } else {
          otherRoutines.add(routine);
        }
      }

      otherRoutines.sort((a, b) {
        return _compareByTime(a, b);
      });

      monthlyRoutines.sort((a, b) {
        return _compareByTime(a, b);
      });

      final finalRoutines = [...otherRoutines, ...monthlyRoutines];

      _routines = finalRoutines.asMap().entries.map((entry) {
        final routine = entry.value;
        return {
          'key': ValueKey('routine_${routine.id}'),
          'title': routine.name,
          'time': routine.getTimeDisplay(),
          'iconSize': _getIconSize(routine.routineType),
          'hasUrgentBadge': false,
          'imagePath': _getImagePath(routine.routineType),
          'routineId': routine.id,
          'preferredTime': routine.preferredTime,
          'priorityScore': null,
          'scheduleType': routine.scheduleType,
        };
      }).toList();

      if (mounted) {
        setState(() {
          // 점수 로딩 완료
        });
      }
    }
  }

  Future<void> _loadWeatherInfo() async {
    try {
      // 날씨 정보 API 호출
      List<String> urlsToTry = [baseUrl];
      if (!kIsWeb && Platform.isAndroid && ApiConfig.useEmulator == null) {
        urlsToTry = ApiConfig.getAndroidBaseUrls();
      }

      String? weatherMessage;
      print('[PriorityScreen] 날씨 정보 로딩 시작: ${urlsToTry.length}개 URL');
      for (int i = 0; i < urlsToTry.length; i++) {
        final url = urlsToTry[i];
        print('[PriorityScreen] 날씨 정보 시도 ${i + 1}/${urlsToTry.length}: $url');
        try {
          final uri = Uri.parse('$url/recommend/weather');
          final response = await http
              .get(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              )
              .timeout(
                const Duration(seconds: 10), // 실제 기기에서는 빠른 실패로 다음 URL 시도
                onTimeout: () {
                  throw Exception('요청 시간 초과');
                },
              );

          if (response.statusCode == 200) {
            final data =
                jsonDecode(utf8.decode(response.bodyBytes))
                    as Map<String, dynamic>;
            final recommendationMessage =
                data['recommendation_message'] as String?;
            if (recommendationMessage != null &&
                recommendationMessage.isNotEmpty) {
              weatherMessage = recommendationMessage;
            } else {
              // 날씨 정보는 있지만 추천 메시지가 없는 경우
              final weatherLabel = data['weather_label'] as String? ?? '맑음';
              weatherMessage = '오늘 날씨는 $weatherLabel이에요.';
            }
            print('[PriorityScreen] 날씨 정보 로딩 성공: $url');
            break; // 성공하면 종료
          } else {
            // HTTP 에러
            print(
              '[PriorityScreen] 날씨 정보 HTTP 에러 ($url): ${response.statusCode}',
            );
            continue;
          }
        } catch (e) {
          // 모든 URL 시도 실패 시 로그 출력
          print('[PriorityScreen] 날씨 정보 로딩 실패 ($url): $e');
          if (i == urlsToTry.length - 1) {
            // 마지막 URL도 실패
            print('[PriorityScreen] 날씨 정보 로딩 실패 - 모든 URL 시도 완료');
          }
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _weatherMessage = weatherMessage ?? '오늘 날씨는 맑음이에요.';
        });
      }
    } catch (e) {
      // 날씨 정보 로딩 실패 시 로그 출력
      print('[PriorityScreen] 날씨 정보 로딩 중 예외 발생: $e');
      if (mounted) {
        setState(() {
          _weatherMessage = '오늘 날씨는 맑음이에요.';
        });
      }
    }
  }

  Future<void> _loadPriorityScores() async {
    if (widget.selectedRoutines.isEmpty) {
      return;
    }

    try {
      // 우선순위 점수 API 호출
      final routineIds = widget.selectedRoutines.map((r) => r.id).toList();

      // Android인 경우 여러 URL 시도
      List<String> urlsToTry = [baseUrl];
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
                body: jsonEncode({
                  'user_id': userId,
                  'routine_ids': routineIds,
                }),
              )
              .timeout(
                const Duration(seconds: 120), // 실제 기기 네트워크 고려하여 120초로 증가
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
            break; // 성공하면 종료
          }
        } catch (e) {
          print('[PriorityScreen] $url 연결 실패: $e');
          continue;
        }
      }

      // 전달받은 루틴들을 정렬 (MONTHLY는 마지막에)
      final sortedRoutines = List<ViewAllRoutineItem>.from(
        widget.selectedRoutines,
      );

      // MONTHLY 루틴과 그 외 루틴 분리
      final monthlyRoutines = <ViewAllRoutineItem>[];
      final otherRoutines = <ViewAllRoutineItem>[];

      for (final routine in sortedRoutines) {
        if (routine.scheduleType.toUpperCase() == 'MONTHLY') {
          monthlyRoutines.add(routine);
        } else {
          otherRoutines.add(routine);
        }
      }

      // 그 외 루틴은 점수 기준 내림차순 정렬
      otherRoutines.sort((a, b) {
        final scoreA = scores?[a.id] ?? 0.0;
        final scoreB = scores?[b.id] ?? 0.0;
        // 점수가 높은 순서로 정렬 (내림차순)
        if (scoreA != scoreB) {
          return scoreB.compareTo(scoreA);
        }
        // 점수가 같으면 시간 순서로 정렬
        return _compareByTime(a, b);
      });

      // MONTHLY 루틴도 점수 기준 내림차순 정렬
      monthlyRoutines.sort((a, b) {
        final scoreA = scores?[a.id] ?? 0.0;
        final scoreB = scores?[b.id] ?? 0.0;
        // 점수가 높은 순서로 정렬 (내림차순)
        if (scoreA != scoreB) {
          return scoreB.compareTo(scoreA);
        }
        // 점수가 같으면 시간 순서로 정렬
        return _compareByTime(a, b);
      });

      // 최종 리스트: 그 외 루틴 + MONTHLY 루틴
      final finalRoutines = [...otherRoutines, ...monthlyRoutines];

      // 전달받은 루틴들을 화면에서 사용할 형식으로 변환
      _routines = finalRoutines.asMap().entries.map((entry) {
        final routine = entry.value;
        final score = scores?[routine.id];
        return {
          'key': ValueKey('routine_${routine.id}'),
          'title': routine.name,
          'time': routine.getTimeDisplay(),
          'iconSize': _getIconSize(routine.routineType),
          'hasUrgentBadge': false,
          'imagePath': _getImagePath(routine.routineType),
          'routineId': routine.id,
          'preferredTime': routine.preferredTime,
          'priorityScore': score, // 우선순위 점수 추가
          'scheduleType': routine.scheduleType, // 스케줄 타입 저장
        };
      }).toList();

      if (mounted) {
        setState(() {
          // 점수 로딩 완료
        });
      }
    } catch (e) {
      print('[PriorityScreen] 우선순위 점수 로딩 실패: $e');
      // 에러 발생 시 점수 없이 표시 (MONTHLY는 뒤로)
      final sortedRoutines = List<ViewAllRoutineItem>.from(
        widget.selectedRoutines,
      );

      // MONTHLY 루틴과 그 외 루틴 분리
      final monthlyRoutines = <ViewAllRoutineItem>[];
      final otherRoutines = <ViewAllRoutineItem>[];

      for (final routine in sortedRoutines) {
        if (routine.scheduleType.toUpperCase() == 'MONTHLY') {
          monthlyRoutines.add(routine);
        } else {
          otherRoutines.add(routine);
        }
      }

      // 시간 순서로 정렬
      otherRoutines.sort((a, b) {
        return _compareByTime(a, b);
      });

      monthlyRoutines.sort((a, b) {
        return _compareByTime(a, b);
      });

      final finalRoutines = [...otherRoutines, ...monthlyRoutines];

      _routines = finalRoutines.asMap().entries.map((entry) {
        final routine = entry.value;
        return {
          'key': ValueKey('routine_${routine.id}'),
          'title': routine.name,
          'time': routine.getTimeDisplay(),
          'iconSize': _getIconSize(routine.routineType),
          'hasUrgentBadge': false,
          'imagePath': _getImagePath(routine.routineType),
          'routineId': routine.id,
          'preferredTime': routine.preferredTime,
          'priorityScore': null,
          'scheduleType': routine.scheduleType,
        };
      }).toList();

      if (mounted) {
        setState(() {
          // 점수 로딩 완료
        });
      }
    }
  }

  /// 시간을 기준으로 루틴을 비교하는 함수
  int _compareByTime(ViewAllRoutineItem a, ViewAllRoutineItem b) {
    // preferredTime이 있는 경우 시간 순서로 정렬
    final timeA = _parseTime(a.preferredTime);
    final timeB = _parseTime(b.preferredTime);

    // 시간이 있는 경우 시간 순서로 정렬
    if (timeA != null && timeB != null) {
      return timeA.compareTo(timeB);
    }
    // 한쪽만 시간이 있는 경우 시간이 있는 것을 앞으로
    if (timeA != null) return -1;
    if (timeB != null) return 1;
    // 둘 다 시간이 없으면 이름 순서로 정렬
    return a.name.compareTo(b.name);
  }

  /// preferredTime 문자열을 분 단위로 변환 (06:00 = 360, 14:30 = 870)
  int? _parseTime(String? preferredTime) {
    if (preferredTime == null || preferredTime.isEmpty) {
      return null;
    }

    try {
      // "HH:MM" 형식 파싱
      final parts = preferredTime.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        // 06:00부터 시작하는 시간 체계 (06:00 = 0, 23:59 = 1079, 00:00 = 1080, 05:59 = 1439)
        if (hour >= 6) {
          return hour * 60 + minute; // 06:00 ~ 23:59
        } else {
          return (hour + 24) * 60 + minute; // 00:00 ~ 05:59 (다음날로 간주)
        }
      }
    } catch (e) {
      print('Error parsing time: $preferredTime, error: $e');
    }
    return null;
  }

  /// 루틴 타입에 따른 아이콘 크기 반환
  double _getIconSize(String routineType) {
    // 루틴 타입에 따라 다른 크기 반환 가능
    if (routineType.toLowerCase().contains('robot')) {
      return 45.0;
    }
    return 40.0;
  }

  /// 루틴 타입에 따른 이미지 경로 반환
  String _getImagePath(String routineType) {
    // 루틴 타입에 따라 다른 이미지 반환
    final type = routineType.toLowerCase();
    if (type.contains('robot') || type.contains('로봇')) {
      return 'assets/priority_screen/robot.png';
    } else if (type.contains('wash') ||
        type.contains('세탁') ||
        type.contains('건조')) {
      return 'assets/priority_screen/washing.png';
    }
    // 기본 이미지
    return 'assets/priority_screen/washing.png';
  }

  static const _cardShadow = BoxShadow(
    color: Color(0x0F222C5C),
    blurRadius: 68,
    offset: Offset(58, 26),
    spreadRadius: 0,
  );

  static const _bannerTitleStyle = TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w600,
    height: 1,
  );

  static const _bannerTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 15,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w700,
    height: 1.52,
  );

  static const _cardTitleStyle = TextStyle(
    color: Colors.black,
    fontSize: 15,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w300,
    height: 1.33,
  );

  static const _cardTimeStyle = TextStyle(
    color: Colors.black,
    fontSize: 13,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w400,
    height: 0.5,
  );

  static const _urgentBadgeStyle = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w600,
    height: 1.23,
  );

  static const _buttonTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w400,
    height: 1.43,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: SafeArea(
        child: Stack(
          children: [
            // 메인 콘텐츠
            Column(
              children: [
                // 상단 제목과 배너 영역 (흰색 배경)
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      // 상단 제목
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 47,
                          left: 30,
                          right: 20,
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder:
                                        (
                                          context,
                                          animation,
                                          secondaryAnimation,
                                        ) => const ViewAllScreen(),
                                    transitionDuration: Duration.zero,
                                    reverseTransitionDuration: Duration.zero,
                                  ),
                                );
                              },
                              child: Image.asset(
                                'assets/lgrouthinq/Back_icon.png',
                                width: 24,
                                height: 24,
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  '우선순위 설정',
                                  style: AppTextStyles.sectionTitle(context)
                                      .copyWith(
                                        fontSize: 24,
                                        height: 1,
                                        fontWeight: FontWeight.w500,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 24, // 오른쪽 공간 (뒤로가기 버튼과 대칭)
                            ),
                          ],
                        ),
                      ),

                      // 보라색 배너
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Container(
                          width: double.infinity,
                          height: 140,
                          padding: const EdgeInsets.all(16),
                          decoration: ShapeDecoration(
                            color: AppColors.textAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(50),
                                topRight: Radius.circular(50),
                              ),
                            ),
                            shadows: [_cardShadow],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '지현님이 선택한 루틴',
                                        style: _bannerTitleStyle.copyWith(
                                          fontSize: 20,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _weatherMessage,
                                        style: _bannerTextStyle.copyWith(
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 20,
                                  right: 20,
                                ),
                                child: Container(
                                  width: 67,
                                  height: 67,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFE8E8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/routine_screen/jiheon_human.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 루틴 리스트
                Expanded(
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 20,
                      ),
                      child: ClipRect(
                        child: ReorderableListView(
                          physics: const ClampingScrollPhysics(),
                          buildDefaultDragHandles: false,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              // 인덱스 범위 검증
                              if (oldIndex < 0 || oldIndex >= _routines.length)
                                return;
                              if (newIndex < 0) newIndex = 0;
                              if (newIndex >= _routines.length)
                                newIndex = _routines.length - 1;

                              if (newIndex > oldIndex) {
                                newIndex -= 1;
                              }

                              // 범위 재검증
                              if (newIndex < 0) newIndex = 0;
                              if (newIndex >= _routines.length)
                                newIndex = _routines.length - 1;

                              final item = _routines.removeAt(oldIndex);
                              _routines.insert(newIndex, item);
                            });
                          },
                          children: _routines.asMap().entries.map((entry) {
                            final index = entry.key;
                            final routine = entry.value;

                            return Padding(
                              key: routine['key'] as Key,
                              padding: EdgeInsets.only(
                                bottom: index < _routines.length - 1 ? 12 : 0,
                              ),
                              child: ReorderableDragStartListener(
                                index: index,
                                child: _PriorityCard(
                                  title: routine['title'] as String,
                                  time: routine['time'] as String,
                                  iconSize: (routine['iconSize'] as num)
                                      .toDouble(),
                                  hasUrgentBadge:
                                      routine['hasUrgentBadge'] as bool? ??
                                      false,
                                  imagePath: routine['imagePath'] as String,
                                  orderNumber: index + 1,
                                  priorityScore:
                                      routine['priorityScore'] as double?,
                                  scheduleType:
                                      routine['scheduleType'] as String? ?? '',
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),

                // 우선순위 설정 버튼
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: GestureDetector(
                    onTap: () {
                      // 현재 순서대로 루틴 ID 순서 저장
                      final routineOrder = _routines
                          .map((r) => r['routineId'] as int)
                          .toList();

                      final selectedRoutineIds = widget.selectedRoutines
                          .map((r) => r.id)
                          .toSet();

                      // 날짜별로 저장
                      if (widget.selectedDateKey != null) {
                        setPriorityOrderForDate(
                          widget.selectedDateKey!,
                          routineOrder,
                        );
                        setSelectedRoutinesForDate(
                          widget.selectedDateKey!,
                          selectedRoutineIds,
                        );
                      } else {
                        // 날짜 정보가 없으면 기존 방식 사용
                        setPriorityOrder(routineOrder);
                        setSelectedRoutineIds(selectedRoutineIds);
                      }

                      // 날짜가 있으면 날짜 인덱스 복원
                      if (widget.selectedDateKey != null) {
                        // dateKey를 DateTime으로 파싱하여 날짜 인덱스 계산
                        try {
                          final parts = widget.selectedDateKey!.split('-');
                          if (parts.length == 3) {
                            final date = DateTime(
                              int.parse(parts[0]),
                              int.parse(parts[1]),
                              int.parse(parts[2]),
                            );

                            // 날짜 인덱스 계산: 기준일(12일 금요일)로부터의 차이
                            final now = DateTime.now();
                            final baseDate = DateTime(now.year, now.month, 12);
                            final currentWeekday = baseDate.weekday;
                            final daysUntilFriday =
                                (5 - currentWeekday + 7) % 7;
                            final referenceDate = baseDate.add(
                              Duration(days: daysUntilFriday),
                            );
                            final daysDiff = date
                                .difference(referenceDate)
                                .inDays;
                            final dateIndex = 15 + daysDiff; // 15는 기준 인덱스

                            // 날짜 인덱스 저장
                            setRoutineScreenDate(dateIndex.clamp(0, 30));
                          }
                        } catch (e) {
                          print('Error parsing dateKey: $e');
                        }
                      }

                      // RoutineScreen으로 이동
                      Navigator.pushAndRemoveUntil(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const RoutineScreen(),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                        ),
                        (route) => false,
                      );
                    },
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
                      child: Center(
                        child: Text(
                          '우선순위 설정',
                          style: _buttonTextStyle.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 하단 네비게이션
                const CustomBottomNavigation(currentScreen: 'priority'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityCard extends StatelessWidget {
  final String title;
  final String time;
  final double iconSize;
  final bool hasUrgentBadge;
  final String imagePath;
  final int orderNumber; // 순서 번호 추가
  final double? priorityScore; // 우선순위 점수
  final String scheduleType; // 스케줄 타입

  const _PriorityCard({
    required this.title,
    required this.time,
    required this.iconSize,
    this.hasUrgentBadge = false,
    required this.imagePath,
    required this.orderNumber,
    this.priorityScore,
    required this.scheduleType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 80,
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: AppColors.backgroundWhite,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: AppColors.backgroundGray),
          borderRadius: BorderRadius.circular(16),
        ),
        shadows: [_PriorityScreenState._cardShadow],
      ),
      child: Row(
        children: [
          // 순서 번호 배지
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.textAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$orderNumber',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textAccent,
                  fontFamily: 'LG Smart_H',
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: title == '로봇청소기 물청소하기' ? 4 : 0),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: _PriorityScreenState._cardTitleStyle
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (priorityScore != null) ...[
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${priorityScore!.toStringAsFixed(2)}점',
                                  style: _PriorityScreenState._cardTimeStyle
                                      .copyWith(
                                        color: AppColors.textAccent,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                ),
                                if (scheduleType.toUpperCase() ==
                                    'MONTHLY') ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '월간',
                                    style: _PriorityScreenState._cardTimeStyle
                                        .copyWith(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w400,
                                          fontSize: 13,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  if (hasUrgentBadge)
                    Positioned(
                      right: 10,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 7,
                        ),
                        decoration: ShapeDecoration(
                          color: AppColors.backgroundBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          shadows: [_PriorityScreenState._cardShadow],
                        ),
                        child: Text(
                          '긴급',
                          style: _PriorityScreenState._urgentBadgeStyle
                              .copyWith(fontSize: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10), // 드래그 핸들과 긴급 배지 사이 간격
          Center(
            child: Icon(
              Icons.drag_handle,
              color: AppColors.textAccent,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}
