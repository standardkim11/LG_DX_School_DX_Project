// routine_screen.dart에 나오는 세부

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'check_icon.dart';

class HabitCard extends StatelessWidget {
  final String subtitle;
  final String title;
  final double progress; // 0~1
  final String runnerIcon;

  const HabitCard({
    super.key,
    required this.subtitle,
    required this.title,
    required this.progress,
    this.runnerIcon = 'assets/routine_screen/human.png',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 120), // 높이 증가
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(width: 1, color: AppColors.borderLight),
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
        clipBehavior: Clip.none,
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
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF9FA7B9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textAccent,
                      ),
                    ),
                    const SizedBox(height: 32), // 제목과 캐릭터/바 사이 여백 증가
                    _buildProgressBar(progress),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
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
              // 캐릭터 아이콘 (제목과 진행률 바 사이 여백 공간에 배치)
              Positioned(
                left: (runnerPosition - 10).clamp(0.0, progressBarWidth - 20),
                top: -28, // 진행률 바 위쪽 24px 여백 공간 중간에 배치
                child: Image.asset(runnerIcon, width: 20, height: 20),
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

class TodoItemCard extends StatelessWidget {
  final String title;
  final String category;
  final bool isHighlighted;
  final String checkType;
  final String? friendIcon; // null이면 표시하지 않음
  final Map<String, double>? friendIconSizes; // 각 아이콘별 크기 설정 (키: 아이콘 경로, 값: 크기)
  final double? iconSpacing; // 아이콘과 체크박스 사이 간격 (기본값: 12)
  final VoidCallback? onCheckChanged; // 체크 상태 변경 콜백

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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 88, // HabitCard와 높이 통일
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(width: 1, color: AppColors.borderLight),
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
                  title,
                  style: AppTextStyles.todoTitle(
                    context,
                    isHighlighted: checkType == 'done'
                        ? false // 체크됨: textSecondary 색상 (다이소에서 신상키링 사기)
                        : true, // 체크 안됨: textAccent 색상 (피그마 복습하기)
                  ),
                ),
                const SizedBox(height: 4),
                Text(category, style: AppTextStyles.todoCategory(context)),
              ],
            ),
          ),
          // 오른쪽 영역: 사람 아이콘(있는 경우) + 체크박스
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 사람 아이콘 (friendIcon이 있을 때만 표시)
              if (friendIcon != null) ...[
                Image.asset(
                  friendIcon!,
                  width: friendIconSizes?[friendIcon] ?? 24,
                  height: friendIconSizes?[friendIcon] ?? 24,
                ),
                SizedBox(width: iconSpacing ?? 12),
              ],
              // 기존 체크박스 위젯
              CheckIcon(type: checkType, onTap: onCheckChanged),
            ],
          ),
        ],
      ),
    );
  }
}
