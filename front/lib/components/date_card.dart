// 캘린더

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class DateCard extends StatelessWidget {
  final int day;
  final String label;
  final bool isSelected;
  final bool isToday;

  const DateCard({
    super.key,
    required this.day,
    required this.label,
    this.isSelected = false,
    this.isToday = false,
  });

  Color _getLabelColor() {
    if (label == 'SAT') {
      // 토요일: 파란색
      return const Color(0xFF4B57BB);
    } else if (label == 'SUN') {
      // 일요일: 빨간색
      return const Color(0xFFE63946);
    }
    // 평일: 기본 색상
    return isSelected ? AppColors.textSelected : AppColors.textUnselected;
  }

  @override
  Widget build(BuildContext context) {
    final labelColor = _getLabelColor();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          width: isSelected ? 2 : 1,
          color: isSelected ? AppColors.textAccent : AppColors.borderGray,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '$day',
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.dateNumber(context, isSelected: isSelected),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.dateLabel(
              context,
              isSelected: isSelected,
            ).copyWith(color: labelColor),
          ),
        ],
      ),
    );
  }
}
