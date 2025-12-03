import 'package:flutter/material.dart';
import 'Screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ❗ 여기서는 const 빼고 일반 MaterialApp 사용
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // 폰트 설정 (다음 서비스부터 적용)
      // theme: ThemeData(
      //   fontFamily: 'CustomFont', // pubspec.yaml에 설정한 폰트 패밀리 이름
      // ),
      home: const HomeScreen(),
    );
  }
}
