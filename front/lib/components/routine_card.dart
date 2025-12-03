import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class RoutineCard extends StatelessWidget {
  final String title;
  final String time;
  final String? topBadgeText;
  final String? bottomBadgeText;
  final Color? topBadgeColor;
  final Color? bottomBadgeColor;
  final double left;
  final double top;
  final bool isChecked;

  const RoutineCard({
    super.key,
    required this.title,
    required this.time,
    this.topBadgeText,
    this.bottomBadgeText,
    this.topBadgeColor,
    this.bottomBadgeColor,
    required this.left,
    required this.top,
    this.isChecked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: 167,
        height: 98,
        decoration: ShapeDecoration(
          color: AppColors.backgroundWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 17, 17, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: ShapeDecoration(
                          color: isChecked
                              ? AppColors.textAccent
                              : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              width: isChecked ? 0 : 1,
                              color: isChecked
                                  ? AppColors.textAccent
                                  : AppColors.textUnselected,
                            ),
                          ),
                        ),
                        child: isChecked
                            ? const Center(
                                child: Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: AppTextStyles.todoTitle(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Text(
                      time,
                      style: AppTextStyles.todoCategory(context),
                    ),
                  ),
                ],
              ),
            ),
            if (topBadgeText != null)
              Positioned(
                left: 130,
                top: 3,
                child: _Badge(
                  text: topBadgeText!,
                  color: topBadgeColor ?? const Color(0xFF6065BB),
                  width: 38,
                  height: 13,
                ),
              ),
            if (bottomBadgeText != null)
              Positioned(
                left: 117,
                top: 68,
                child: _Badge(
                  text: bottomBadgeText!,
                  color: bottomBadgeColor ?? const Color(0xFF6065BB),
                  width: 51,
                  height: 17,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final double width;
  final double height;

  const _Badge({
    required this.text,
    required this.color,
    this.width = 51,
    this.height = 17,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: ShapeDecoration(
        color: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontFamily: 'LG Smart_H',
            fontWeight: FontWeight.w400,
            height: 2.50,
          ),
        ),
      ),
    );
  }
}
