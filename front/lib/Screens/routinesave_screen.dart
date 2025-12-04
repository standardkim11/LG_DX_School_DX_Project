import 'package:flutter/material.dart';
import '../components/app_colors.dart';

class ViewSaveScreen extends StatefulWidget {
  const ViewSaveScreen({super.key});

  @override
  State<ViewSaveScreen> createState() => _ViewSaveScreenState();
}

class _ViewSaveScreenState extends State<ViewSaveScreen> {
  bool _isWaterCleaningEnabled = false;
  String _selectedFrequency = '매주'; // 기본값: 매주

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

  static const _subtitleTextStyle = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontFamily: 'LG Smart_H',
    fontWeight: FontWeight.w400,
    height: 1.33,
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
                      // 뒤로 가기 기능 (Navigator.pop 등으로 구현 가능)
                    },
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textSelected,
                      size: 24,
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
          child: Text('', style: _inputTextStyle),
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
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '4',
                      style: _titleTextStyle.copyWith(
                        color: AppColors.textSelected,
                      ),
                    ),
                    TextSpan(
                      text: ' 번',
                      style: _titleTextStyle.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
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
          Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('지금 물청소를 할까요?', style: _bodyTextStyle),
              _buildToggleSwitch(),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: _buildGrayContainerDecoration(),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildTimeOption('09:30', 'assets/viewsave_screen/Time.png'),
                _buildTimeOption('매일', 'assets/viewsave_screen/Bell.png'),
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
          _isWaterCleaningEnabled = !_isWaterCleaningEnabled;
        });
      },
      child: Container(
        width: 48,
        height: 28,
        decoration: ShapeDecoration(
          color: _isWaterCleaningEnabled ? AppColors.textAccent : Colors.grey,
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
              left: _isWaterCleaningEnabled ? 22 : 2,
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

  Widget _buildTimeOption(String label, String? imagePath) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (imagePath != null)
          Image.asset(imagePath, width: 20, height: 20, fit: BoxFit.contain)
        else
          const SizedBox(width: 20, height: 20),
        const SizedBox(width: 4),
        Text(label, style: _bodyTextStyle),
      ],
    );
  }

  Widget _buildDeviceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _buildCardDecoration(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            padding: EdgeInsets.zero,
            decoration: ShapeDecoration(
              color: AppColors.backgroundGray,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Image.asset(
              'assets/viewsave_screen/robot.png',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('로봇청소기', style: _titleTextStyle),
              Text('물걸레 청소 시작', style: _subtitleTextStyle),
            ],
          ),
        ],
      ),
    );
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
    return _buildRoundedButton(
      text: '조건 추가',
      backgroundColor: AppColors.backgroundWhite,
      textStyle: _titleTextStyle,
      shadows: [_cardShadow],
    );
  }

  Widget _buildSaveButton() {
    return _buildRoundedButton(
      text: '루틴 저장',
      backgroundColor: AppColors.textAccent,
      textStyle: _buttonTextStyle,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }
}
