// 공통되는 문구에 대한 스타일을 모아둔 곳

import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  // 인사말
  static TextStyle greetingTitle(BuildContext context) {
    return TextStyle(
      color: AppColors.textPrimary,
      fontSize: 24,
      fontFamily: 'LG Smart_H',
      fontWeight: FontWeight.w600,
      height: 1.33,
    );
  }

  static TextStyle greetingSubtitle(BuildContext context) {
    return TextStyle(
      color: AppColors.textSecondary,
      fontSize: 18,
      fontFamily: 'LG Smart_H',
      fontWeight: FontWeight.w400,
      height: 1.43,
    );
  }

  // 탭
  static TextStyle tabSelected(BuildContext context) {
    return TextStyle(
      color: AppColors.textAccent,
      fontSize: 16,
      fontFamily: 'LG Smart_H',
      fontWeight: FontWeight.w700,
      height: 1.43,
    );
  }

  static TextStyle tabUnselected(BuildContext context) {
    return TextStyle(
      color: AppColors.textSecondary,
      fontSize: 16,
      fontFamily: 'LG Smart_H',
      fontWeight: FontWeight.w400,
      height: 1.43,
    );
  }

  // 날짜 카드
  static TextStyle dateNumber(BuildContext context, {bool isSelected = false}) {
    return TextStyle(
      color: isSelected ? AppColors.textAccent : AppColors.textSelected,
      fontSize: 24,
      fontFamily: 'LG Smart_H',
      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
      height: 1.20,
    );
  }

  static TextStyle dateLabel(BuildContext context, {bool isSelected = false}) {
    return TextStyle(
      color: isSelected ? AppColors.textAccent : AppColors.backgroundBlue,
      fontSize: 13,
      fontFamily: 'LG Smart_H',
      fontWeight: FontWeight.w700,
      height: 1.60,
      letterSpacing: 1,
    );
  }

  // 할 일
  static TextStyle todoTitle(
    BuildContext context, {
    bool isHighlighted = false,
  }) {
    return TextStyle(
      color: isHighlighted ? AppColors.textAccent : AppColors.textSecondary,
      fontSize: 16,
      fontFamily: 'LG Smart_H',
      fontWeight: FontWeight.w600,
      height: 1.43,
    );
  }

  static TextStyle todoCategory(BuildContext context) {
    return TextStyle(
      color: AppColors.textSecondary,
      fontSize: 14,
      fontFamily: 'LG Smart_H',
      fontWeight: FontWeight.w400,
      height: 1.33,
    );
  }

  // 오늘 할 일
  static TextStyle sectionTitle(BuildContext context) {
    return TextStyle(
      color: AppColors.textPrimary,
      fontSize: 16,
      fontFamily: 'LG Smart_H',
      fontWeight: FontWeight.w400,
      height: 1.43,
    );
  }

  // VIEW ALL
  static TextStyle viewAll(BuildContext context) {
    return TextStyle(
      color: AppColors.textAccent,
      fontSize: 13,
      fontFamily: 'LG Smart_H',
      fontWeight: FontWeight.w700,
      height: 1.60,
      letterSpacing: 1,
    );
  }

  // 하단 네비게이션
  static TextStyle bottomNav(BuildContext context, {bool isSelected = false}) {
    return TextStyle(
      color: isSelected ? AppColors.textSelected : AppColors.textUnselected,
      fontSize: 10,
      fontFamily: 'LG Smart_H',
      fontWeight: FontWeight.w400,
      height: 2.40,
    );
  }
}
