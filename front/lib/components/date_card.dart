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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
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
            style: AppTextStyles.dateNumber(context, isSelected: isSelected),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.dateLabel(context, isSelected: isSelected),
          ),
        ],
      ),
    );
  }
}
