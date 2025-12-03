// 상단바 todo, routine, dashboard 모아둔 곳

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class CustomTabBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabChanged;

  const CustomTabBar({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5), // 위아래 간격
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildTab(context, 'to-do', 0),
          _buildTab(context, 'routine', 1),
          _buildTab(context, 'dashboard', 2),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, String label, int index) {
    final isSelected = selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTabChanged(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.backgroundGray
                : AppColors.backgroundWhite,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: isSelected
                ? AppTextStyles.tabSelected(context)
                : AppTextStyles.tabUnselected(context),
          ),
        ),
      ),
    );
  }
}
