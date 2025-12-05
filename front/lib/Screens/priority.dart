import 'package:flutter/material.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/bottom_navigation.dart';
import '../Services/routine_service.dart';
import 'viewall_screen.dart';
import 'routine_screen.dart';

class PriorityScreen extends StatefulWidget {
  final List<ViewAllRoutineItem> selectedRoutines;
  final String? selectedDateKey; // 선택된 날짜 키 (YYYY-MM-DD 형식)

  const PriorityScreen({
    super.key,
    required this.selectedRoutines,
    this.selectedDateKey,
  });

  @override
  State<PriorityScreen> createState() => _PriorityScreenState();
}

class _PriorityScreenState extends State<PriorityScreen> {
  late List<Map<String, dynamic>> _routines;

  @override
  void initState() {
    super.initState();
    // 전달받은 루틴들을 화면에서 사용할 형식으로 변환
    _routines = widget.selectedRoutines.map((routine) {
      return {
        'key': ValueKey('routine_${routine.id}'), // routineId 기반 key로 변경
        'title': routine.name,
        'time': routine.getTimeDisplay(),
        'iconSize': _getIconSize(routine.routineType),
        'hasUrgentBadge': false, // 필요시 로직 추가
        'imagePath': _getImagePath(routine.routineType),
        'routineId': routine.id,
        'preferredTime': routine.preferredTime, // 정렬을 위해 추가
      };
    }).toList();

    // 시간 기반으로 정렬
    _routines.sort((a, b) {
      final timeA = _parseTimeToMinutes(a['preferredTime'] as String?);
      final timeB = _parseTimeToMinutes(b['preferredTime'] as String?);
      return timeA.compareTo(timeB);
    });

    // 화면이 로드되면 날씨 팝업 표시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWeatherDialog();
    });
  }

  /// 날씨 다이얼로그 표시
  Future<void> _showWeatherDialog() async {
    await showDialog<bool>(
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
                      '오늘 오전에 비가 와요.',
                      style: AppTextStyles.sectionTitle(
                        context,
                      ).copyWith(fontSize: 18, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '세탁기 돌리기를 내일로 미룰까요?',
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
  }

  /// preferredTime을 분(minutes) 단위로 변환하여 정렬에 사용
  /// 반환값: 오늘 00:00부터의 분 수 (0-1439)
  int _parseTimeToMinutes(String? preferredTime) {
    if (preferredTime == null || preferredTime.isEmpty) {
      return 1440; // 시간이 없으면 맨 뒤로
    }

    // "HH:MM" 형식인 경우
    if (preferredTime.contains(':')) {
      try {
        final parts = preferredTime.split(':');
        if (parts.length >= 2) {
          final hour = int.parse(parts[0].trim());
          // 분 부분 파싱 (숫자만 추출)
          final minuteStr = parts[1].trim();
          final minute = int.parse(minuteStr.split(RegExp(r'[^\d]'))[0]);
          if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
            return hour * 60 + minute;
          }
        }
      } catch (e) {
        // 파싱 실패 시 시간대 이름으로 처리
      }
    }

    // 시간대 이름인 경우 (MORNING, AFTERNOON 등)
    final upperTime = preferredTime.toUpperCase();
    switch (upperTime) {
      case 'DAWN':
        return 180; // 3:00 (새벽 3시)
      case 'MORNING':
        return 480; // 8:00 (아침 8시)
      case 'AFTERNOON':
        return 780; // 13:00 (오후 1시)
      case 'EVENING':
        return 1140; // 19:00 (저녁 7시)
      case 'NIGHT':
        return 1260; // 21:00 (밤 9시)
      default:
        return 1440; // 알 수 없는 값은 맨 뒤로
    }
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
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontFamily: 'LG Smart_H',
                                          fontWeight: FontWeight.w600,
                                          height: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '오전에 비가 예정된 오늘,\n세탁기는 오후에 돌리길 추천드립니다.',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontFamily: 'LG Smart_H',
                                          fontWeight: FontWeight.w700,
                                          height: 1.52,
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
                              // ReorderableListView의 onReorder 동작:
                              // oldIndex < newIndex: 아래로 이동할 때, newIndex는 제거 후 기준이므로 1을 빼야 함
                              // oldIndex > newIndex: 위로 이동할 때, newIndex는 그대로 사용
                              final adjustedNewIndex = oldIndex < newIndex
                                  ? newIndex - 1
                                  : newIndex;

                              // 같은 위치면 변경하지 않음
                              if (oldIndex == adjustedNewIndex) {
                                return;
                              }

                              // 범위 검증
                              if (oldIndex < 0 ||
                                  oldIndex >= _routines.length ||
                                  adjustedNewIndex < 0 ||
                                  adjustedNewIndex >= _routines.length) {
                                return;
                              }

                              // 아이템 이동
                              final item = _routines.removeAt(oldIndex);
                              _routines.insert(adjustedNewIndex, item);
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
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),

                // 하단 네비게이션
                const CustomBottomNavigation(currentScreen: 'routine'),
              ],
            ),

            // 우선순위 설정 버튼
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
                          final daysUntilFriday = (5 - currentWeekday + 7) % 7;
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
                        pageBuilder: (context, animation, secondaryAnimation) =>
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

  const _PriorityCard({
    required this.title,
    required this.time,
    required this.iconSize,
    this.hasUrgentBadge = false,
    required this.imagePath,
    required this.orderNumber,
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
                      Text(
                        title,
                        style: _PriorityScreenState._cardTitleStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(time, style: _PriorityScreenState._cardTimeStyle),
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
