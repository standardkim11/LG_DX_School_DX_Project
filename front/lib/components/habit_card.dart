// routine_screen.dart에 나오는 세부

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'check_icon.dart';

// 스와이프 상태 전역 관리
class SwipeStateManager extends ChangeNotifier {
  static final SwipeStateManager _instance = SwipeStateManager._internal();
  factory SwipeStateManager() => _instance;
  SwipeStateManager._internal();

  String? _swipedCardKey;

  String? get swipedCardKey => _swipedCardKey;

  void setSwipedCard(String? key) {
    if (_swipedCardKey != key) {
      _swipedCardKey = key;
      notifyListeners();
    }
  }

  void clearSwipedCard() {
    if (_swipedCardKey != null) {
      _swipedCardKey = null;
      notifyListeners();
    }
  }

  bool isSwiped(String key) {
    return _swipedCardKey == key;
  }
}

class HabitCard extends StatefulWidget {
  final String subtitle;
  final String title;
  final double progress; // 0~1
  final String runnerIcon;
  final String cardKey; // 고유 키

  const HabitCard({
    super.key,
    required this.subtitle,
    required this.title,
    required this.progress,
    this.runnerIcon = 'assets/routine_screen/human.png',
    String? cardKey,
  }) : cardKey = cardKey ?? 'habit_${title}_${subtitle}';

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> {
  double _dragOffset = 0.0;
  String? _swipeState; // 'right' (핑크), 'left' (보라), null (원래)

  @override
  void initState() {
    super.initState();
    // 전역 상태 변경 리스너 추가
    SwipeStateManager().addListener(_onSwipeStateChanged);
  }

  @override
  void dispose() {
    SwipeStateManager().removeListener(_onSwipeStateChanged);
    super.dispose();
  }

  void _onSwipeStateChanged() {
    // 다른 카드가 스와이프되었을 때만 현재 카드를 리셋
    if (!SwipeStateManager().isSwiped(widget.cardKey) && _swipeState != null) {
      if (mounted) {
        setState(() {
          _swipeState = null;
          _dragOffset = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = _swipeState == 'right'
        ? const Color(0xFFFE3C7B) // 핑크
        : _swipeState == 'left'
        ? const Color(0xFF4B57BB) // 보라
        : AppColors.backgroundWhite; // 원래

    final textColor = _swipeState != null ? Colors.white : null;

    return GestureDetector(
      onTap: () {
        // 배경 탭 시 원래 상태로 복귀
        if (_swipeState != null) {
          setState(() {
            _swipeState = null;
            _dragOffset = 0.0;
          });
          SwipeStateManager().clearSwipedCard();
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 배경 버튼들
          if (_swipeState == 'right')
            // 오른쪽 스와이프: View 버튼 (왼쪽)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 88,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      width: 1,
                      color: const Color(0xFFEAECF0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x0F222C5C),
                        blurRadius: 68,
                        offset: const Offset(58, 26),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/viewsave_screen/View_icon.png',
                        width: 20,
                        height: 20,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'View',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF9B9BA1),
                          fontSize: 12,
                          fontFamily: 'LG Smart_H',
                          fontWeight: FontWeight.w400,
                          height: 1.33,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_swipeState == 'left')
            // 왼쪽 스와이프: Fail, Skip 버튼 (오른쪽)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  height: 88,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      width: 1,
                      color: const Color(0xFFEAECF0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x0F222C5C),
                        blurRadius: 68,
                        offset: const Offset(58, 26),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Fail 버튼
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Fail',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF9B9BA1),
                                fontSize: 12,
                                fontFamily: 'LG Smart_H',
                                fontWeight: FontWeight.w400,
                                height: 1.33,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12), // 버튼 사이 여백
                      // Skip 버튼
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.arrow_forward,
                                size: 14,
                                color: Color(0xFF9B9BA1),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Skip',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF9B9BA1),
                                fontSize: 12,
                                fontFamily: 'LG Smart_H',
                                fontWeight: FontWeight.w400,
                                height: 1.33,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // 카드
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _dragOffset += details.delta.dx;
                // 스와이프 임계값 설정
                if (_dragOffset > 80) {
                  _swipeState = 'right';
                  SwipeStateManager().setSwipedCard(widget.cardKey);
                } else if (_dragOffset < -80) {
                  _swipeState = 'left';
                  SwipeStateManager().setSwipedCard(widget.cardKey);
                } else {
                  _swipeState = null;
                  if (SwipeStateManager().isSwiped(widget.cardKey)) {
                    SwipeStateManager().clearSwipedCard();
                  }
                }
              });
            },
            onHorizontalDragEnd: (details) {
              // 드래그 종료 시 스냅
              if (_swipeState == 'right') {
                setState(() {
                  _dragOffset = 80;
                });
                SwipeStateManager().setSwipedCard(widget.cardKey);
              } else if (_swipeState == 'left') {
                setState(() {
                  _dragOffset = -80;
                });
                SwipeStateManager().setSwipedCard(widget.cardKey);
              } else {
                setState(() {
                  _dragOffset = 0.0;
                });
                SwipeStateManager().clearSwipedCard();
              }
            },
            child: Transform.translate(
              offset: Offset(_dragOffset.clamp(-80.0, 80.0), 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                constraints: const BoxConstraints(
                  minHeight: 88,
                ), // TodoItemCard와 높이 통일
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    width: 1,
                    color: _swipeState != null
                        ? Colors.transparent
                        : AppColors.borderLight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x0F222C5C),
                      blurRadius: 68,
                      offset: const Offset(58, 26),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: textColor ?? const Color(0xFF9FA7B9),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: textColor ?? AppColors.textAccent,
                                ),
                              ),
                              const SizedBox(height: 32), // 제목과 progress bar 사이 여백 증가 (24 -> 32)
                              _buildProgressBar(widget.progress),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 배경 버튼들 (카드 위에 표시되도록 나중에 선언)
          if (_swipeState == 'right')
            // 오른쪽 스와이프: View 버튼 (왼쪽)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 88,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      width: 1,
                      color: const Color(0xFFEAECF0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x0F222C5C),
                        blurRadius: 68,
                        offset: const Offset(58, 26),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/viewsave_screen/View_icon.png',
                        width: 20,
                        height: 20,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'View',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF9B9BA1),
                          fontSize: 12,
                          fontFamily: 'LG Smart_H',
                          fontWeight: FontWeight.w400,
                          height: 1.33,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_swipeState == 'left')
            // 왼쪽 스와이프: Fail, Skip 버튼 (오른쪽)
            Positioned(
              right:
                  8 +
                  (-_dragOffset.clamp(
                    -80.0,
                    0.0,
                  )), // 카드가 왼쪽으로 이동한 만큼 버튼도 오른쪽으로 이동
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  height: 88,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      width: 1,
                      color: const Color(0xFFEAECF0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x0F222C5C),
                        blurRadius: 68,
                        offset: const Offset(58, 26),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Fail 버튼
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Fail',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF9B9BA1),
                                fontSize: 12,
                                fontFamily: 'LG Smart_H',
                                fontWeight: FontWeight.w400,
                                height: 1.33,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12), // 버튼 사이 여백
                      // Skip 버튼
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.arrow_forward,
                                size: 14,
                                color: Color(0xFF9B9BA1),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Skip',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF9B9BA1),
                                fontSize: 12,
                                fontFamily: 'LG Smart_H',
                                fontWeight: FontWeight.w400,
                                height: 1.33,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final progressBarWidth = constraints.maxWidth;
        final clampedProgress = progress.clamp(0.0, 1.0);
        final runnerPosition = progressBarWidth * clampedProgress;

        return SizedBox(
          height: 16, // 진행률 바 높이 명시
          child: Stack(
            clipBehavior: Clip.none, // Stack 밖으로 나가는 요소를 허용
            children: [
              // 진행률 바 배경
              Container(
                width: double.infinity,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F1F1),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              // 진행률 바 채워진 부분
              FractionallySizedBox(
                widthFactor: clampedProgress,
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF4FA5), Color(0xFFFF7EC6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              // 진행률 퍼센트 텍스트 (채워진 부분의 오른쪽 끝에)
              if (clampedProgress > 0.05) // 5% 이상일 때 표시
                Positioned(
                  left: (runnerPosition - 25).clamp(8.0, progressBarWidth - 30),
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              // 진행률이 매우 낮을 때는 오른쪽에 표시
              if (clampedProgress <= 0.05)
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9FA7B9),
                      ),
                    ),
                  ),
                ),
              // 캐릭터 아이콘 (progress bar 위쪽 여백 공간에 배치, progress에 따라 움직임)
              Positioned(
                left: (runnerPosition - 10).clamp(0.0, progressBarWidth - 20),
                top: -24, // progress bar 위쪽 32px 여백 공간에 배치
                child: Image.asset(widget.runnerIcon, width: 20, height: 20),
              ),
            ],
          ),
        );
      },
    );
  }
}

// 루틴 생성하기 바

class RoutineCreateBar extends StatelessWidget {
  final double bottomNavHeight;

  const RoutineCreateBar({super.key, required this.bottomNavHeight});

  @override
  Widget build(BuildContext context) {
    // 일정 추가하기 버튼과 동일한 위치로 설정
    return Positioned(
      left: 0,
      right: 0,
      bottom: 60 + MediaQuery.of(context).padding.bottom,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(color: AppColors.backgroundGray),
        child: Container(
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            image: const DecorationImage(
              image: AssetImage('assets/routine_screen/routine_bar.png'),
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
    );
  }
}

// 할 일

class TodoItemCard extends StatefulWidget {
  final String title;
  final String category;
  final bool isHighlighted;
  final String checkType;
  final String? friendIcon; // null이면 표시하지 않음
  final Map<String, double>? friendIconSizes; // 각 아이콘별 크기 설정 (키: 아이콘 경로, 값: 크기)
  final double? iconSpacing; // 아이콘과 체크박스 사이 간격 (기본값: 12)
  final VoidCallback? onCheckChanged; // 체크 상태 변경 콜백
  final String cardKey; // 고유 키

  const TodoItemCard({
    super.key,
    required this.title,
    required this.category,
    this.isHighlighted = false,
    this.checkType = 'none',
    this.friendIcon,
    this.friendIconSizes,
    this.iconSpacing,
    this.onCheckChanged,
    String? cardKey,
  }) : cardKey = cardKey ?? 'todo_${title}_${category}';

  @override
  State<TodoItemCard> createState() => _TodoItemCardState();
}

class _TodoItemCardState extends State<TodoItemCard> {
  double _dragOffset = 0.0;
  String? _swipeState; // 'right' (핑크), 'left' (보라), null (원래)

  @override
  void initState() {
    super.initState();
    // 전역 상태 변경 리스너 추가
    SwipeStateManager().addListener(_onSwipeStateChanged);
  }

  @override
  void dispose() {
    SwipeStateManager().removeListener(_onSwipeStateChanged);
    super.dispose();
  }

  void _onSwipeStateChanged() {
    // 다른 카드가 스와이프되었을 때만 현재 카드를 리셋
    if (!SwipeStateManager().isSwiped(widget.cardKey) && _swipeState != null) {
      if (mounted) {
        setState(() {
          _swipeState = null;
          _dragOffset = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = _swipeState == 'right'
        ? const Color(0xFFFE3C7B) // 핑크
        : _swipeState == 'left'
        ? const Color(0xFF4B57BB) // 보라
        : AppColors.backgroundWhite; // 원래

    final textColor = _swipeState != null ? Colors.white : null;

    return GestureDetector(
      onTap: () {
        // 배경 탭 시 원래 상태로 복귀
        if (_swipeState != null) {
          setState(() {
            _swipeState = null;
            _dragOffset = 0.0;
          });
          SwipeStateManager().clearSwipedCard();
        }
      },
      child: Stack(
        children: [
          // 배경 버튼들
          if (_swipeState == 'right')
            // 오른쪽 스와이프: View 버튼 (왼쪽)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 88,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      width: 1,
                      color: const Color(0xFFEAECF0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x0F222C5C),
                        blurRadius: 68,
                        offset: const Offset(58, 26),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/viewsave_screen/View_icon.png',
                        width: 20,
                        height: 20,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'View',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF9B9BA1),
                          fontSize: 12,
                          fontFamily: 'LG Smart_H',
                          fontWeight: FontWeight.w400,
                          height: 1.33,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_swipeState == 'left')
            // 왼쪽 스와이프: Fail, Skip 버튼 (오른쪽)
            Positioned(
              right:
                  8 +
                  (-_dragOffset.clamp(
                    -80.0,
                    0.0,
                  )), // 카드가 왼쪽으로 이동한 만큼 버튼도 오른쪽으로 이동
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  height: 88,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      width: 1,
                      color: const Color(0xFFEAECF0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x0F222C5C),
                        blurRadius: 68,
                        offset: const Offset(58, 26),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Fail 버튼
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Fail',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF9B9BA1),
                                fontSize: 12,
                                fontFamily: 'LG Smart_H',
                                fontWeight: FontWeight.w400,
                                height: 1.33,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12), // 버튼 사이 여백
                      // Skip 버튼
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.arrow_forward,
                                size: 14,
                                color: Color(0xFF9B9BA1),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Skip',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF9B9BA1),
                                fontSize: 12,
                                fontFamily: 'LG Smart_H',
                                fontWeight: FontWeight.w400,
                                height: 1.33,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // 카드
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _dragOffset += details.delta.dx;
                // 스와이프 임계값 설정
                if (_dragOffset > 80) {
                  _swipeState = 'right';
                  SwipeStateManager().setSwipedCard(widget.cardKey);
                } else if (_dragOffset < -80) {
                  _swipeState = 'left';
                  SwipeStateManager().setSwipedCard(widget.cardKey);
                } else {
                  _swipeState = null;
                  if (SwipeStateManager().isSwiped(widget.cardKey)) {
                    SwipeStateManager().clearSwipedCard();
                  }
                }
              });
            },
            onHorizontalDragEnd: (details) {
              // 드래그 종료 시 스냅
              if (_swipeState == 'right') {
                setState(() {
                  _dragOffset = 80;
                });
                SwipeStateManager().setSwipedCard(widget.cardKey);
              } else if (_swipeState == 'left') {
                setState(() {
                  _dragOffset = -80;
                });
                SwipeStateManager().setSwipedCard(widget.cardKey);
              } else {
                setState(() {
                  _dragOffset = 0.0;
                });
                SwipeStateManager().clearSwipedCard();
              }
            },
            child: Transform.translate(
              offset: Offset(_dragOffset.clamp(-80.0, 80.0), 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                height: 88, // HabitCard와 높이 통일
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    width: 1,
                    color: _swipeState != null
                        ? Colors.transparent
                        : AppColors.borderLight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x0F222C5C),
                      blurRadius: 68,
                      offset: const Offset(58, 26),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center, // 세로 중앙 정렬
                        children: [
                          Text(
                            widget.title,
                            style: AppTextStyles.todoTitle(
                              context,
                              isHighlighted: widget.checkType == 'done'
                                  ? false // 체크됨: textSecondary 색상
                                  : true, // 체크 안됨: textAccent 색상
                            ).copyWith(color: textColor),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.category,
                            style: AppTextStyles.todoCategory(context).copyWith(
                              color: textColor ?? AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 오른쪽 영역: 사람 아이콘(있는 경우) + 체크박스
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 사람 아이콘 (friendIcon이 있을 때만 표시)
                        if (widget.friendIcon != null) ...[
                          Image.asset(
                            widget.friendIcon!,
                            width:
                                widget.friendIconSizes?[widget.friendIcon] ??
                                24,
                            height:
                                widget.friendIconSizes?[widget.friendIcon] ??
                                24,
                          ),
                          SizedBox(width: widget.iconSpacing ?? 12),
                        ],
                        // 기존 체크박스 위젯
                        if (_swipeState == null)
                          CheckIcon(
                            type: widget.checkType,
                            onTap: widget.onCheckChanged,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 배경 버튼들 (카드 위에 표시되도록 나중에 선언)
          if (_swipeState == 'right')
            // 오른쪽 스와이프: View 버튼 (왼쪽)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 88,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      width: 1,
                      color: const Color(0xFFEAECF0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x0F222C5C),
                        blurRadius: 68,
                        offset: const Offset(58, 26),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/viewsave_screen/View_icon.png',
                        width: 20,
                        height: 20,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'View',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF9B9BA1),
                          fontSize: 12,
                          fontFamily: 'LG Smart_H',
                          fontWeight: FontWeight.w400,
                          height: 1.33,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_swipeState == 'left')
            // 왼쪽 스와이프: Fail, Skip 버튼 (오른쪽)
            Positioned(
              right:
                  8 +
                  (-_dragOffset.clamp(
                    -80.0,
                    0.0,
                  )), // 카드가 왼쪽으로 이동한 만큼 버튼도 오른쪽으로 이동
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  height: 88,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      width: 1,
                      color: const Color(0xFFEAECF0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x0F222C5C),
                        blurRadius: 68,
                        offset: const Offset(58, 26),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Fail 버튼
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Fail',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF9B9BA1),
                                fontSize: 12,
                                fontFamily: 'LG Smart_H',
                                fontWeight: FontWeight.w400,
                                height: 1.33,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12), // 버튼 사이 여백
                      // Skip 버튼
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.arrow_forward,
                                size: 14,
                                color: Color(0xFF9B9BA1),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Skip',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF9B9BA1),
                                fontSize: 12,
                                fontFamily: 'LG Smart_H',
                                fontWeight: FontWeight.w400,
                                height: 1.33,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
