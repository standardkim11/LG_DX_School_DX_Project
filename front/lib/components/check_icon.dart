// 미완료 체크박스

import 'package:flutter/material.dart';

class CheckIcon extends StatelessWidget {
  final String type;

  const CheckIcon({super.key, this.type = 'none'});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(width: 1, color: const Color(0xFFE6E6E6)),
      ),
      child: Center(
        child: Image.asset(
          type == 'done'
              ? 'assets/todo_screen/button2.png'
              : 'assets/todo_screen/button1.png',
          width: 38,
          height: 38,
        ),
      ),
    );
  }
}
