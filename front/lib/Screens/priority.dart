import 'package:flutter/material.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/bottom_navigation.dart';

class PriorityScreen extends StatelessWidget {
  static const _cardShadow = BoxShadow(
    color: Color(0x0F222C5C),
    blurRadius: 68,
    offset: Offset(58, 26),
    spreadRadius: 0,
  );

  static const _bannerTitleStyle = TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w600,
    height: 1,
  );

  static const _bannerTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 15,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w700,
    height: 1.52,
  );

  static const _cardTitleStyle = TextStyle(
    color: Colors.black,
    fontSize: 15,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w300,
    height: 1.33,
  );

  static const _cardTimeStyle = TextStyle(
    color: Colors.black,
    fontSize: 13,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w400,
    height: 0.5,
  );

  static const _urgentBadgeStyle = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w600,
    height: 1.23,
  );

  static const _buttonTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w400,
    height: 1.43,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: SafeArea(
        child: Stack(
          children: [
            // 메인 콘텐츠
            Column(
              children: [
                // 상단 제목
                Padding(
                  padding: const EdgeInsets.only(top: 47, left: 30, right: 20),
                  child: Row(
                    children: [
                      Transform.rotate(
                        angle: 3.14, // 180도 회전 (왼쪽 화살표)
                        child: Text(
                          '>',
                          style: AppTextStyles.sectionTitle(
                            context,
                          ).copyWith(fontSize: 20, height: 1),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '우선순위 설정',
                            style: AppTextStyles.sectionTitle(context).copyWith(
                              fontSize: 20,
                              height: 1,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 5, // 오른쪽 공간 (화살표와 대칭)
                      ),
                    ],
                  ),
                ),

                // 보라색 배너
                Padding(
                  padding: const EdgeInsets.only(top: 38),
                  child: Container(
                    width: double.infinity,
                    height: 116,
                    padding: const EdgeInsets.all(16),
                    decoration: ShapeDecoration(
                      color: AppColors.textAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(50),
                          topRight: Radius.circular(50),
                        ),
                      ),
                      shadows: [_cardShadow],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 20, top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('지현님이 선택한 루틴', style: _bannerTitleStyle),
                                const SizedBox(height: 12),
                                Text(
                                  '습도가 70%인 오늘,\n물청소를 완료해서 귀가 전 바닥 청소를 넘어갑니다.',
                                  style: _bannerTextStyle.copyWith(
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Container(
                            width: 67,
                            height: 67,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFE8E8),
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/routine_screen/jiheon_human.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 루틴 리스트
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 20,
                    ),
                    child: Column(
                      children: [
                        _PriorityCard(
                          title: '로봇청소기 물청소하기',
                          time: '13:00(화, 목)',
                          iconSize: 45,
                          hasUrgentBadge: true,
                          imagePath: 'assets/priority_screen/robot.png',
                          arrowDirection: 'down',
                        ),
                        const SizedBox(height: 12),
                        _PriorityCard(
                          title: '세탁기 돌리기',
                          time: '2/4',
                          iconSize: 40,
                          imagePath: 'assets/priority_screen/.png',
                          arrowDirection: 'up',
                        ),
                        const SizedBox(height: 12),
                        _PriorityCard(
                          title: '건조기 돌리기',
                          time: '2/4',
                          iconSize: 40,
                          imagePath: 'assets/priority_screen/.png',
                          arrowDirection: 'up',
                        ),
                      ],
                    ),
                  ),
                ),

                // 우선순위 설정 버튼
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    decoration: ShapeDecoration(
                      color: AppColors.textAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '우선순위 설정',
                        style: _buttonTextStyle.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),

                // 하단 네비게이션
                const CustomBottomNavigation(currentScreen: 'routine'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityCard extends StatelessWidget {
  final String title;
  final String time;
  final double iconSize;
  final bool hasUrgentBadge;
  final String imagePath;
  final String arrowDirection; // 'up' or 'down'

  const _PriorityCard({
    required this.title,
    required this.time,
    required this.iconSize,
    this.hasUrgentBadge = false,
    required this.imagePath,
    required this.arrowDirection,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 80,
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: AppColors.backgroundWhite,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: AppColors.backgroundGray),
          borderRadius: BorderRadius.circular(16),
        ),
        shadows: [PriorityScreen._cardShadow],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 55,
            decoration: const ShapeDecoration(
              color: AppColors.backgroundGray,
              shape: OvalBorder(),
            ),
            child: Center(
              child: Image.asset(
                imagePath,
                width: iconSize,
                height: iconSize,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: title == '로봇청소기 물청소하기' ? 4 : 0),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: PriorityScreen._cardTitleStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(time, style: PriorityScreen._cardTimeStyle),
                    ],
                  ),
                  if (hasUrgentBadge)
                    Positioned(
                      right: 10,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 7,
                        ),
                        decoration: ShapeDecoration(
                          color: AppColors.backgroundBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          shadows: [PriorityScreen._cardShadow],
                        ),
                        child: Text(
                          '긴급',
                          style: PriorityScreen._urgentBadgeStyle.copyWith(
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10), // 화살표와 긴급 배지 사이 간격
          Center(
            child: Transform.rotate(
              angle: arrowDirection == 'down'
                  ? 1.57
                  : -1.57, // 아래: 90도, 위: -90도
              child: Text(
                '>',
                style: PriorityScreen._cardTimeStyle.copyWith(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
