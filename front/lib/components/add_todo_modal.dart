// 일정 추가하기 모달

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AddTodoModal extends StatefulWidget {
  const AddTodoModal({super.key});

  @override
  State<AddTodoModal> createState() => _AddTodoModalState();
}

class _AddTodoModalState extends State<AddTodoModal> {
  final TextEditingController _titleController = TextEditingController();
  String? _selectedTime;
  String? _selectedCategory;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // 드래그 핸들
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 24),
            width: 82,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목
                  Text(
                    '새로운 일정 생성',
                    style: AppTextStyles.sectionTitle(
                      context,
                    ).copyWith(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 24),

                  // 일정 제목 입력 필드
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.borderLight,
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _titleController,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontFamily: 'LG Smart_H',
                        fontWeight: FontWeight.w400,
                        height: 1.43,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '일정 제목을 입력하세요',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                          fontFamily: 'LG Smart_H',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 시간 지정하기
                  Text('시간 지정하기', style: AppTextStyles.sectionTitle(context)),
                  const SizedBox(height: 12),

                  // 시간 선택 버튼
                  GestureDetector(
                    onTap: () {
                      // 시간 선택 로직 추가
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundWhite,
                        border: Border.all(
                          color: AppColors.borderLight,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedTime ?? '시간 선택',
                            style: TextStyle(
                              color: _selectedTime != null
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontSize: 16,
                              fontFamily: 'LG Smart_H',
                              fontWeight: FontWeight.w400,
                              height: 1.43,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 카테고리
                  Text('카테고리', style: AppTextStyles.sectionTitle(context)),
                  const SizedBox(height: 12),

                  // 카테고리 선택 버튼
                  GestureDetector(
                    onTap: () {
                      // 카테고리 선택 로직 추가
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundWhite,
                        border: Border.all(
                          color: AppColors.borderLight,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedCategory ?? '카테고리 선택',
                            style: TextStyle(
                              color: _selectedCategory != null
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontSize: 16,
                              fontFamily: 'LG Smart_H',
                              fontWeight: FontWeight.w400,
                              height: 1.43,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // 일정 추가하기 버튼
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.textAccent,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // 일정 추가 로직
                  if (_titleController.text.isNotEmpty) {
                    Navigator.pop(context, {
                      'title': _titleController.text,
                      'time': _selectedTime,
                      'category': _selectedCategory ?? '기타',
                    });
                  }
                },
                borderRadius: BorderRadius.circular(30),
                child: const Center(
                  child: Text(
                    '일정 추가하기',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontFamily: 'LG Smart_H',
                      fontWeight: FontWeight.w600,
                      height: 1.43,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
