import 'package:flutter/material.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/bottom_navigation.dart';
import 'routine_screen.dart';

class RobotPushScreen extends StatefulWidget {
  final int? routineId; // 로봇청소기 루틴 ID

  const RobotPushScreen({super.key, this.routineId});

  @override
  State<RobotPushScreen> createState() => _RobotPushScreenState();
}

class _RobotPushScreenState extends State<RobotPushScreen> {
  bool _isPopupClosed = false;
  bool _isSkipped = false; // 오늘 건너뛰기 여부
  String _bannerMessage =
      '로봇청소기를 안 돌린지 1시간이 넘었어요.\n깨끗한 집을 위해 지금 실행시켜주세요'; // 배너 메시지
  List<Map<String, dynamic>> _allRoutines = [
    {
      'key': ValueKey('robot'),
      'title': '로봇청소기 물청소하기',
      'time': '13:00(화, 목)',
      'imagePath': 'assets/priority_screen/robot.png',
      'orderNumber': 1,
    },
    {
      'key': ValueKey('washer'),
      'title': '세탁기 돌리기',
      'time': '2/4',
      'imagePath': 'assets/priority_screen/washing.png',
      'orderNumber': 2,
    },
    {
      'key': ValueKey('dryer'),
      'title': '건조기 돌리기',
      'time': '2/4',
      'imagePath': 'assets/priority_screen/washing.png',
      'orderNumber': 3,
    },
  ];

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

  static const _buttonTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w400,
    height: 1.43,
  );

  @override
  void initState() {
    super.initState();
    // 화면이 열리면 팝업 표시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showRobotPopup(context);
    });
  }

  /// 로봇청소기 루틴을 오늘 날짜의 우선순위 맨 위에 추가
  Future<void> _addToPriorityTop(int routineId) async {
    try {
      // 오늘 날짜 키 생성
      final now = DateTime.now();
      final dateKey =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // 기존 우선순위 순서 가져오기
      final existingOrder = getPriorityOrderForDate(dateKey) ?? [];
      final existingSelectedRoutines =
          getSelectedRoutinesForDate(dateKey) ?? <int>{};

      // 루틴 ID가 이미 있으면 제거 (맨 위에 다시 추가하기 위해)
      final newOrder = existingOrder.where((id) => id != routineId).toList();
      // 맨 위에 추가
      newOrder.insert(0, routineId);

      // 선택된 루틴 ID에도 추가
      final newSelectedRoutines = Set<int>.from(existingSelectedRoutines);
      newSelectedRoutines.add(routineId);

      // 우선순위 순서 저장
      setPriorityOrderForDate(dateKey, newOrder);
      setSelectedRoutinesForDate(dateKey, newSelectedRoutines);

      print(
        '[RobotPushScreen] 우선순위에 추가됨: routineId=$routineId, dateKey=$dateKey',
      );
      print('[RobotPushScreen] 새로운 우선순위 순서: $newOrder');

      // RoutineScreen으로 이동
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const RoutineScreen(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
          (route) => false, // 모든 이전 화면 제거
        );
      }
    } catch (e) {
      print('[RobotPushScreen] 우선순위 추가 실패: $e');
    }
  }

  void _showRobotPopup(BuildContext context) {
    String? selectedButton;

    showDialog(
      context: context,
      barrierDismissible: false, // 바깥을 클릭해도 닫히지 않도록
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundGray,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '로봇청소기 알림',
                      style: TextStyle(
                        fontSize: 20,
                        fontFamily: 'LG Smart_H',
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '로봇청소기를 안 돌린지 1시간이 넘었어요.\n깨끗한 집을 위해 지금 실행시켜주세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'LG Smart_H',
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTapDown: (_) {
                              setDialogState(() {
                                selectedButton = 'execute';
                              });
                            },
                            onTap: () async {
                              setDialogState(() {
                                selectedButton = 'execute';
                              });
                              Future.delayed(
                                const Duration(milliseconds: 300),
                                () async {
                                  if (dialogContext.mounted) {
                                    // 팝업만 닫기 (dialogContext 사용)
                                    Navigator.of(dialogContext).pop();
                                    if (mounted) {
                                      setState(() {
                                        _isPopupClosed = true;
                                        _bannerMessage =
                                            '로봇청소기를 실행하셨네요!\n깨끗한 집을 유지해주세요.';
                                      });

                                      // 로봇청소기 루틴 ID가 있으면 우선순위에 추가
                                      if (widget.routineId != null) {
                                        await _addToPriorityTop(
                                          widget.routineId!,
                                        );
                                      }
                                    }
                                  }
                                },
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: selectedButton == 'execute'
                                    ? const Color(0xFF4B57BB)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '실행하기',
                                  style: TextStyle(
                                    color: selectedButton == 'execute'
                                        ? Colors.white
                                        : Colors.black,
                                    fontSize: 14,
                                    fontFamily: 'LG Smart_H',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTapDown: (_) {
                              setDialogState(() {
                                selectedButton = 'skip';
                              });
                            },
                            onTap: () {
                              setDialogState(() {
                                selectedButton = 'skip';
                              });
                              Future.delayed(
                                const Duration(milliseconds: 300),
                                () {
                                  if (dialogContext.mounted) {
                                    // 팝업 닫기
                                    Navigator.of(dialogContext).pop();
                                  }
                                  // robotpush_screen 닫고 care_screen으로 돌아가기
                                  if (mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: selectedButton == 'skip'
                                    ? const Color(0xFF4B57BB)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '오늘 건너뛰기',
                                  style: TextStyle(
                                    color: selectedButton == 'skip'
                                        ? Colors.white
                                        : Colors.black,
                                    fontSize: 12,
                                    fontFamily: 'LG Smart_H',
                                    fontWeight: FontWeight.w700,
                                  ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: SafeArea(
        child: Stack(
          children: [
            // 메인 콘텐츠 (PriorityScreen 스타일 배경)
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
                              onTap: () => Navigator.pop(context),
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
                            const SizedBox(
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
                                        _bannerMessage,
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

                // 루틴 리스트 (팝업이 닫힌 후에만 표시)
                if (_isPopupClosed)
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
                        child: Builder(
                          builder: (context) {
                            // 오늘 건너뛰기를 눌렀으면 로봇청소기 제거
                            final filteredRoutines = _isSkipped
                                ? _allRoutines
                                      .where((r) => r['title'] != '로봇청소기 물청소하기')
                                      .toList()
                                : List<Map<String, dynamic>>.from(_allRoutines);

                            // 순서 번호 재정렬
                            final routinesWithOrder = filteredRoutines
                                .asMap()
                                .entries
                                .map((entry) {
                                  final routine = Map<String, dynamic>.from(
                                    entry.value,
                                  );
                                  routine['orderNumber'] = entry.key + 1;
                                  // key가 없으면 새로 생성
                                  if (routine['key'] == null) {
                                    routine['key'] = ValueKey(
                                      'routine_${entry.key}',
                                    );
                                  }
                                  return routine;
                                })
                                .toList();

                            return ClipRect(
                              child: ReorderableListView(
                                physics: const ClampingScrollPhysics(),
                                buildDefaultDragHandles: false,
                                onReorder: (oldIndex, newIndex) {
                                  setState(() {
                                    // 인덱스 범위 검증
                                    if (oldIndex < 0 ||
                                        oldIndex >= routinesWithOrder.length)
                                      return;
                                    if (newIndex < 0) newIndex = 0;
                                    if (newIndex >= routinesWithOrder.length)
                                      newIndex = routinesWithOrder.length - 1;

                                    if (newIndex > oldIndex) {
                                      newIndex -= 1;
                                    }

                                    // 범위 재검증
                                    if (newIndex < 0) newIndex = 0;
                                    if (newIndex >= routinesWithOrder.length)
                                      newIndex = routinesWithOrder.length - 1;

                                    // 필터링된 리스트에서 아이템 이동
                                    final item = routinesWithOrder.removeAt(
                                      oldIndex,
                                    );
                                    routinesWithOrder.insert(newIndex, item);

                                    // 원본 리스트 업데이트
                                    if (_isSkipped) {
                                      // 로봇청소기가 제거된 상태면 필터링된 리스트만 업데이트
                                      _allRoutines = _allRoutines
                                          .where(
                                            (r) => r['title'] != '로봇청소기 물청소하기',
                                          )
                                          .toList();
                                      for (
                                        int i = 0;
                                        i < routinesWithOrder.length;
                                        i++
                                      ) {
                                        final key = routinesWithOrder[i]['key'];
                                        final index = _allRoutines.indexWhere(
                                          (r) => r['key'] == key,
                                        );
                                        if (index != -1) {
                                          _allRoutines[index] =
                                              routinesWithOrder[i];
                                        }
                                      }
                                    } else {
                                      // 모든 루틴이 있는 상태면 전체 리스트 업데이트
                                      for (
                                        int i = 0;
                                        i < routinesWithOrder.length;
                                        i++
                                      ) {
                                        final key = routinesWithOrder[i]['key'];
                                        final index = _allRoutines.indexWhere(
                                          (r) => r['key'] == key,
                                        );
                                        if (index != -1) {
                                          _allRoutines[index] =
                                              routinesWithOrder[i];
                                        }
                                      }
                                    }

                                    // 순서 번호 재정렬
                                    for (
                                      int i = 0;
                                      i < _allRoutines.length;
                                      i++
                                    ) {
                                      _allRoutines[i]['orderNumber'] = i + 1;
                                    }
                                  });
                                },
                                children: routinesWithOrder.asMap().entries.map(
                                  (entry) {
                                    final index = entry.key;
                                    final routine = entry.value;

                                    return Padding(
                                      key:
                                          routine['key'] as Key? ??
                                          ValueKey('routine_$index'),
                                      padding: EdgeInsets.only(
                                        bottom:
                                            index < routinesWithOrder.length - 1
                                            ? 12
                                            : 0,
                                      ),
                                      child: ReorderableDragStartListener(
                                        index: index,
                                        child: _PriorityCard(
                                          title: routine['title'] as String,
                                          time: routine['time'] as String,
                                          imagePath:
                                              routine['imagePath'] as String,
                                          orderNumber:
                                              routine['orderNumber'] as int,
                                        ),
                                      ),
                                    );
                                  },
                                ).toList(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(child: Container(color: AppColors.backgroundGray)),

                // 우선순위 설정 버튼 (팝업이 닫힌 후에만 표시)
                if (_isPopupClosed)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
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
                const CustomBottomNavigation(currentScreen: 'robotpush'),
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
  final String imagePath;
  final int orderNumber;

  const _PriorityCard({
    required this.title,
    required this.time,
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
        shadows: [_RobotPushScreenState._cardShadow],
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
                        style: _RobotPushScreenState._cardTitleStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(time, style: _RobotPushScreenState._cardTimeStyle),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
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
