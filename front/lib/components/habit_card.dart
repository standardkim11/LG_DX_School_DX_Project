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
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF9FA7B9),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3843FF),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildProgressBar(progress),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
          // human.png를 Progress Bar 위에 배치
          Positioned(
            right: 100,
            bottom: 25,
            child: Image.asset(runnerIcon, width: 20, height: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return Container(
      height: 20, // 14 → 20으로 증가 (원하는 크기로 조정 가능)
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF4FA5), Color(0xFFFF7EC6)],
                ),
                borderRadius: BorderRadius.circular(12), // borderRadius 동일하게 조정
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 12, // 10 → 12로 증가 (박스 크기에 맞춰 조정)
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 루틴 생성하기 바

class RoutineCreateBar extends StatelessWidget {
  final double bottomNavHeight;

  const RoutineCreateBar({super.key, required this.bottomNavHeight});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 10,
      right: 10,
      bottom: bottomNavHeight - 10,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          image: const DecorationImage(
            image: AssetImage('assets/routine_screen/routine_bar.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: const Center(
          child: Text(
            '루틴 생성하기',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
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

  const TodoItemCard({
    super.key,
    required this.title,
    required this.category,
    this.isHighlighted = false,
    this.checkType = 'none',
    this.friendIcon,
    this.friendIconSizes,
    this.iconSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              children: [
                Text(
                  title,
                  style: AppTextStyles.todoTitle(
                    context,
                    isHighlighted: isHighlighted,
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
              CheckIcon(type: checkType),
            ],
          ),
        ],
      ),
    );
  }
}
