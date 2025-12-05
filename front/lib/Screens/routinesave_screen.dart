import 'package:flutter/material.dart';
import '../components/app_colors.dart';
import 'viewall_screen.dart';
import '../Services/routine_service.dart';

class ViewSaveScreen extends StatefulWidget {
  const ViewSaveScreen({super.key});

  @override
  State<ViewSaveScreen> createState() => _ViewSaveScreenState();
}

class _ViewSaveScreenState extends State<ViewSaveScreen> {
  final TextEditingController _routineNameController = TextEditingController();
  final TextEditingController _notificationController = TextEditingController();
  int _selectedGoal = 4; // 기본값: 4
  String _selectedFrequency = '매주'; // 기본값: 매주
  String? _selectedTime; // 선택된 시간
  String? _selectedDay; // 선택된 요일 (월화수목금토일)
  bool _isNotificationEnabled = false; // 알림 켜기/끄기
  String? _selectedDevice; // 선택된 가전 (로봇청소기, 세탁기, 정수기)

  static const _cardShadow = BoxShadow(
    color: Color(0x0F222C5C),
    blurRadius: 68,
    offset: Offset(58, 26),
    spreadRadius: 0,
  );

  static const _labelStyle = TextStyle(
    color: AppColors.textSelected,
    fontSize: 14,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w700,
    height: 1.60,
    letterSpacing: 1,
  );

  static const _inputTextStyle = TextStyle(
    color: AppColors.textSelected,
    fontSize: 18,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w400,
    height: 1.33,
  );

  static const _bodyTextStyle = TextStyle(
    color: AppColors.textSelected,
    fontSize: 14,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w400,
    height: 1.33,
  );

  static const _titleTextStyle = TextStyle(
    color: AppColors.textSelected,
    fontSize: 14,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w400,
    height: 1.43,
  );

  static const _buttonTextStyle = TextStyle(
    color: AppColors.backgroundWhite,
    fontSize: 14,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w500,
    height: 1.43,
  );

  static const _grayBackgroundColor = Color(0xFFF3F4F6);
  static const _borderColor = Color(0xFFCDCDD0);

  ShapeDecoration _buildCardDecoration() {
    return ShapeDecoration(
      color: AppColors.backgroundWhite,
      shape: RoundedRectangleBorder(
        side: const BorderSide(width: 1, color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(16),
      ),
      shadows: [_cardShadow],
    );
  }

  ShapeDecoration _buildGrayContainerDecoration() {
    return ShapeDecoration(
      color: _grayBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildPrimaryIcon({required bool isSelected, double size = 12}) {
    final icon = Image.asset(
      'assets/viewsave_screen/primary.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
    return isSelected
        ? ColorFiltered(
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            child: icon,
          )
        : icon;
  }

  @override
  void initState() {
    super.initState();
    // 시간 초기값 설정 (00:00)
    _selectedTime = '00:00';
    // 요일 초기값 설정 (월)
    _selectedDay = '월';
  }

  @override
  void dispose() {
    _routineNameController.dispose();
    _notificationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildRoutineNameSection(),
                    const SizedBox(height: 20),
                    _buildGoalSection(),
                    const SizedBox(height: 20),
                    _buildActionSection(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: _buildSaveButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      width: double.infinity,
      height: 102,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(color: AppColors.backgroundWhite),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 47,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Image.asset(
                      'assets/lgrouthinq/Back_icon.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.arrow_back,
                          color: AppColors.textSelected,
                          size: 24,
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '루틴',
                    textAlign: TextAlign.center,
                    style: _labelStyle.copyWith(fontSize: 20, height: 1),
                  ),
                ),
                const SizedBox(width: 44), // 오른쪽 균형을 위한 공간
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineNameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('루틴명', style: _labelStyle),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.backgroundGray,
            border: Border(bottom: BorderSide(width: 1, color: _borderColor)),
          ),
          child: TextField(
            controller: _routineNameController,
            style: _inputTextStyle,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('목표', style: _labelStyle),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: _buildCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 드롭다운으로 목표 횟수 선택 (1-30)
                  DropdownButton<int>(
                    value: _selectedGoal,
                    underline: Container(),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.textSelected,
                    ),
                    items: List.generate(30, (index) => index + 1)
                        .map(
                          (value) => DropdownMenuItem<int>(
                            value: value,
                            child: Text(
                              '$value',
                              style: _titleTextStyle.copyWith(
                                color: AppColors.textSelected,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedGoal = value;
                        });
                      }
                    },
                  ),
                  Text(
                    ' 번',
                    style: _titleTextStyle.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: _buildGrayContainerDecoration(),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildFrequencyOption('매일'),
                    _buildFrequencyOption('매주'),
                    _buildFrequencyOption('매달'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFrequencyOption(String label) {
    final isSelected = _selectedFrequency == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFrequency = label;
        });
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            isSelected
                ? 'assets/routine_screen/Goal_bold.png'
                : 'assets/routine_screen/Goal.png',
            width: 16,
            height: 16,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 16,
                height: 16,
                decoration: ShapeDecoration(
                  color: isSelected
                      ? AppColors.textAccent
                      : AppColors.backgroundWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Center(child: _buildPrimaryIcon(isSelected: isSelected)),
              );
            },
          ),
          const SizedBox(width: 4),
          Text(label, style: _bodyTextStyle),
        ],
      ),
    );
  }

  Widget _buildActionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('무엇을 할까요?', style: _labelStyle),
        const SizedBox(height: 4),
        _buildActionCard(),
        const SizedBox(height: 8),
        _buildDeviceCard(),
        const SizedBox(height: 8),
        _buildAddConditionButton(),
      ],
    );
  }

  Widget _buildActionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 알림 내용 입력 필드와 토글 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: TextField(
                  controller: _notificationController,
                  style: _bodyTextStyle,
                  decoration: InputDecoration(
                    hintText: '알림 내용을 입력하세요',
                    hintStyle: _bodyTextStyle.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              _buildToggleSwitch(),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: _buildGrayContainerDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 시간 선택 드롭다운
                _buildTimeDropdown(),
                const SizedBox(height: 8),
                // 요일 선택 (나란히 버튼)
                Row(
                  children: [
                    Image.asset(
                      'assets/routine_screen/Bell.png',
                      width: 20,
                      height: 20,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(width: 20, height: 20);
                      },
                    ),
                    const SizedBox(width: 4),
                    Expanded(child: _buildDayButtons()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleSwitch() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isNotificationEnabled = !_isNotificationEnabled;
        });
      },
      child: Container(
        width: 48,
        height: 28,
        decoration: ShapeDecoration(
          color: _isNotificationEnabled ? AppColors.textAccent : Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
          ),
          shadows: [_cardShadow],
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              left: _isNotificationEnabled ? 22 : 2,
              top: 2,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x330B2B51),
                      blurRadius: 6,
                      offset: Offset(0, 3),
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeDropdown() {
    // 시간 목록 생성 (00:00 ~ 23:30, 30분 간격)
    final timeOptions = <String>[];
    for (int hour = 0; hour < 24; hour++) {
      for (int minute = 0; minute < 60; minute += 30) {
        final timeStr =
            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        timeOptions.add(timeStr);
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/routine_screen/Time.png',
          width: 20,
          height: 20,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox(width: 20, height: 20);
          },
        ),
        const SizedBox(width: 4),
        DropdownButton<String>(
          value: _selectedTime,
          underline: Container(),
          icon: const Icon(
            Icons.arrow_drop_down,
            size: 20,
            color: AppColors.textSelected,
          ),
          items: timeOptions.map((time) {
            return DropdownMenuItem<String>(
              value: time,
              child: Text(time, style: _bodyTextStyle),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedTime = value;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildDayButtons() {
    final days = ['월', '화', '수', '목', '금', '토', '일'];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: days.map((day) {
        final isSelected = _selectedDay == day;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDay = day;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.textAccent
                  : AppColors.backgroundWhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                width: 1,
                color: isSelected
                    ? AppColors.textAccent
                    : AppColors.borderLight,
              ),
            ),
            child: Text(
              day,
              style: _bodyTextStyle.copyWith(
                color: isSelected ? Colors.white : AppColors.textSelected,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDeviceCard() {
    // 로봇청소기 아이콘 제거 - 카드 자체를 제거하거나 빈 위젯으로 변경
    return const SizedBox.shrink();
  }

  Widget _buildRoundedButton({
    required String text,
    required Color backgroundColor,
    required TextStyle textStyle,
    EdgeInsetsGeometry? padding,
    List<BoxShadow>? shadows,
  }) {
    return Container(
      width: double.infinity,
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: ShapeDecoration(
        color: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        shadows: shadows,
      ),
      child: Center(
        child: Text(text, textAlign: TextAlign.center, style: textStyle),
      ),
    );
  }

  Widget _buildAddConditionButton() {
    return GestureDetector(
      onTap: _showDeviceSelectionDialog,
      child: _buildRoundedButton(
        text: '조건 추가',
        backgroundColor: AppColors.backgroundWhite,
        textStyle: _titleTextStyle,
        shadows: [_cardShadow],
      ),
    );
  }

  void _showDeviceSelectionDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.backgroundWhite,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '가전을 선택하세요',
                  style: _labelStyle.copyWith(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildDeviceOption(
                      '로봇청소기',
                      'assets/viewsave_screen/robot.png',
                    ),
                    _buildDeviceOption(
                      '세탁기',
                      'assets/priority_screen/washing.png',
                    ),
                    _buildDeviceOption(
                      '정수기',
                      'assets/viewsave_screen/robot.png',
                    ), // 정수기 아이콘은 임시로 robot.png 사용
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeviceOption(String deviceName, String iconPath) {
    final isSelected = _selectedDevice == deviceName;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDevice = isSelected ? null : deviceName;
        });
        Navigator.pop(context); // 다이얼로그 닫기
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.textAccent : AppColors.backgroundGray,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              iconPath,
              width: 40,
              height: 40,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundGray,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.devices, size: 24),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              deviceName,
              style: _bodyTextStyle.copyWith(
                color: isSelected ? Colors.white : AppColors.textSelected,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _onSaveRoutine,
      child: _buildRoundedButton(
        text: '루틴 저장',
        backgroundColor: AppColors.textAccent,
        textStyle: _buttonTextStyle,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  Future<void> _onSaveRoutine() async {
    // 루틴명이 입력되었는지 확인
    if (_routineNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('루틴명을 입력해주세요.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 스케줄 타입 변환
    String scheduleType = 'DAILY';
    if (_selectedFrequency == '매일') {
      scheduleType = 'DAILY';
    } else if (_selectedFrequency == '매주') {
      scheduleType = 'WEEKLY';
    } else if (_selectedFrequency == '매달') {
      scheduleType = 'MONTHLY';
    }

    // 목표 값 가져오기
    final goalValue = _selectedGoal;

    // 로딩 표시 (선택사항)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 백엔드 API 호출하여 루틴 저장
      final result = await RoutineService.createRoutine(
        name: _routineNameController.text.trim(),
        scheduleType: scheduleType,
        preferredTime: _selectedTime,
        runMinutes: goalValue,
        routineType: 'CLEANING', // 로봇청소기이므로 CLEANING
      );

      // 로딩 닫기
      if (mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기
      }

      if (result != null) {
        // 저장 성공 시 viewall 화면으로 이동
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const ViewAllScreen(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
            (route) => false, // 모든 이전 화면 제거
          );
        }
      } else {
        // 저장 실패 시 에러 메시지 표시
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('루틴 저장에 실패했습니다. 다시 시도해주세요.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // 로딩 닫기
      if (mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기
      }

      // 에러 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
