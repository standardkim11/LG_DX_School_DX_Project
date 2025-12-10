// 미완료 체크박스

import 'package:flutter/material.dart';

class CheckIcon extends StatelessWidget {
  final String type;
  final VoidCallback? onTap;

  const CheckIcon({super.key, this.type = 'none', this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            width: 1,
            color: type == 'done'
                ? const Color(0xFFE6E6E6) // 체크됨: 회색
                : type == 'failed'
                ? Colors
                      .red // 실패: 빨간색
                : const Color(0xFF4B57BB), // 체크 안됨: 앱의 accent 색상
          ),
        ),
        child: Center(
          child: type == 'done'
              ? const Text('✔️', style: TextStyle(fontSize: 14))
              : type == 'failed'
              ? const Icon(
                  Icons.close,
                  size: 18,
                  color: Colors.red,
                ) // 실패: 빨간색 X
              : null, // 체크 안됨: 빈 박스
        ),
      ),
    );
  }
}
