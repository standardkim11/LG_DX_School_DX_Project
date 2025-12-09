import 'package:flutter/material.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/tab_bar.dart';
import '../components/bottom_navigation.dart';
import '../components/habit_card.dart';
import '../services/dashboard_service.dart';
import '../models/dashboard_response.dart';
import 'todo_screen.dart';
import 'routine_screen.dart';

// 상수
class _DashboardConstants {
  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x0F222C5C),
    blurRadius: 68,
    offset: Offset(58, 26),
    spreadRadius: 0,
  );
}

// 통계 카드 위젯
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final double? labelFontSize;
  final double? valueFontSize;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.labelFontSize,
    this.valueFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textUnselected,
              fontSize: labelFontSize ?? 10,
              fontFamily: 'LG Smart_H',
              fontWeight: FontWeight.w700,
              height: 2.40,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textSecondary,
              fontSize: valueFontSize ?? 20,
              fontFamily: 'LG Smart_H',
              fontWeight: FontWeight.w400,
              height: 1.20,
            ),
          ),
        ],
      ),
    );
  }
}

// 경쟁 카드 위젯
class CompetitionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress;
  final int participantCount;
  final String? friendImagePath;

  const CompetitionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.participantCount,
    this.friendImagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: ShapeDecoration(
        color: AppColors.textSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontFamily: 'LG Smart_H',
                  fontWeight: FontWeight.w700,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'LG Smart_H',
                  fontWeight: FontWeight.w400,
                  height: 1.50,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 4,
                decoration: ShapeDecoration(
                  color: AppColors.textSelected,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 4,
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (friendImagePath != null)
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: ShapeDecoration(
                    image: DecorationImage(
                      image: AssetImage(friendImagePath!),
                      fit: BoxFit.cover,
                    ),
                    shape: OvalBorder(
                      side: const BorderSide(width: 1, color: Colors.white),
                    ),
                  ),
                ),
              Text(
                '친구 $participantCount명이 참여 중',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'LG Smart_H',
                  fontWeight: FontWeight.w400,
                  height: 1.20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedTabIndex = 2;
  DashboardResponse? _dashboardData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    print('[Dashboard] 데이터 로딩 시작');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('[Dashboard] API 호출 시작...');
      final data = await DashboardService.getDashboardData().timeout(
        const Duration(seconds: 35),
        onTimeout: () {
          print('[Dashboard] 타임아웃 발생 (35초 초과)');
          throw Exception('요청 시간 초과 - 백엔드 서버가 실행 중인지 확인해주세요');
        },
      );

      print('[Dashboard] API 응답 받음: ${data != null ? "성공" : "null"}');

      if (data != null) {
        setState(() {
          _dashboardData = data;
          _isLoading = false;
        });
        print('[Dashboard] 데이터 로딩 완료');
      } else {
        setState(() {
          _errorMessage = '데이터를 불러올 수 없습니다.';
          _isLoading = false;
        });
        print('[Dashboard] 데이터가 null입니다');
      }
    } catch (e, stackTrace) {
      print('[Dashboard] 에러 발생: $e');
      print('[Dashboard] Stack trace: $stackTrace');
      setState(() {
        _errorMessage = '오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  void _onTabChanged(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const TodoScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const RoutineScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } else {
      setState(() {
        _selectedTabIndex = index;
      });
    }
  }

  String _formatSuccessRate(double rate) {
    return '${(rate * 100).toInt()}%';
  }

  int _calculateRemainingDays(double progressRate) {
    // progress_rate가 0.75라면 25% 남았으므로, 21일 목표 기준으로 약 5일 남음
    // 하지만 정확한 계산을 위해서는 goal_days가 필요하므로, 임시로 계산
    // progress_rate가 0.75면 75% 완료, 25% 남음
    // 21일 목표 기준: 21 * 0.25 = 5.25일 → 약 5일
    // 더 정확한 계산을 위해서는 API에서 remaining_days를 제공해야 함
    if (progressRate >= 1.0) return 0;
    // 임시 계산: 21일 목표 기준으로 가정
    const goalDays = 21;
    final remaining = (goalDays * (1.0 - progressRate)).ceil();
    return remaining > 0 ? remaining : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadDashboardData,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadDashboardData,
                child: SingleChildScrollView(
                  physics:
                      const AlwaysScrollableScrollPhysics(), // RefreshIndicator를 위해 필요
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 20, top: 50),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '지현님, 반가워요!',
                                style: AppTextStyles.greetingTitle(context),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '오늘도 함께 습관을 만들어봐요',
                                style: AppTextStyles.greetingSubtitle(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        child: CustomTabBar(
                          selectedIndex: _selectedTabIndex,
                          onTabChanged: _onTabChanged,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: ShapeDecoration(
                            color: AppColors.backgroundWhite,
                            shape: RoundedRectangleBorder(
                              side: const BorderSide(
                                width: 1,
                                color: AppColors.borderLight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            shadows: [_DashboardConstants.cardShadow],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '12월 루틴 진행 사항',
                                style: AppTextStyles.tabUnselected(
                                  context,
                                ).copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 12),
                              if (_dashboardData != null)
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        StatCard(
                                          label: '성공률',
                                          value: _formatSuccessRate(
                                            _dashboardData!.successRate,
                                          ),
                                          labelFontSize: 15,
                                          valueFontSize: 24,
                                        ),
                                        StatCard(
                                          label: '완료한 루틴 수',
                                          value: _dashboardData!.completedCount
                                              .toString(),
                                          labelFontSize: 15,
                                          valueFontSize: 24,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        StatCard(
                                          label: '미룬 루틴 수',
                                          value: _dashboardData!.pendingCount
                                              .toString(),
                                          labelFontSize: 15,
                                          valueFontSize: 24,
                                        ),
                                        StatCard(
                                          label: '실패한 루틴 수',
                                          value: _dashboardData!.failedCount
                                              .toString(),
                                          valueColor: const Color(0xFFFF3132),
                                          labelFontSize: 15,
                                          valueFontSize: 24,
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              else
                                const Text('데이터가 없습니다.'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 메인 습관 카드
                      if (_dashboardData?.mainHabit != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: HabitCard(
                            subtitle:
                                '습관 형성까지 ${_dashboardData!.mainHabit!.remainingDays ?? _calculateRemainingDays(_dashboardData!.mainHabit!.progressRate)}일 남았어요',
                            title: '${_dashboardData!.mainHabit!.name}💧',
                            progress: _dashboardData!.mainHabit!.progressRate,
                            enableSwipe: false, // Dashboard에서는 스와이프 비활성화
                          ),
                        ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '누가 더 루틴을 잘 지키나 경쟁해요',
                                    style: AppTextStyles.sectionTitle(
                                      context,
                                    ).copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => Scaffold(
                                          appBar: AppBar(
                                            title: const Text('VIEW ALL'),
                                          ),
                                          body: const Center(
                                            child: Text('경쟁 목록 화면'),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'VIEW ALL',
                                    style: AppTextStyles.viewAll(context),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 140,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  CompetitionCard(
                                    title: '미라클모닝',
                                    subtitle: '6시 전에 정수기 사용하기',
                                    progress: 0.19,
                                    participantCount: 2,
                                    friendImagePath:
                                        'assets/routine_screen/friends1.png',
                                  ),
                                  const SizedBox(width: 12),
                                  CompetitionCard(
                                    title: '뽀득뽀득 우리집',
                                    subtitle: '주 3회 물청소하기',
                                    progress: 0.55,
                                    participantCount: 1,
                                    friendImagePath:
                                        'assets/routine_screen/friends2.png',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: CustomBottomNavigation(currentScreen: 'dashboard'),
    );
  }
}
