// 일정 추가하기 모달

import 'package:flutter/material.dart';

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
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
      ),
      child: Column(
        children: [
          // 드래그 핸들
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            width: 82,
            height: 1,
            decoration: ShapeDecoration(
              shape: RoundedRectangleBorder(
                side: const BorderSide(
                  width: 1,
                  strokeAlign: BorderSide.strokeAlignCenter,
                  color: Color(0xFFD9D9D9),
                ),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 새로운 일정 생성
                  Text(
                    '새로운 일정 생성',
                    style: TextStyle(
                      color: const Color(0xFF9B9BA1),
                      fontSize: 10,
                      fontFamily: 'LG Smart_H',
                      fontWeight: FontWeight.w700,
                      height: 1.60,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 일정 제목 입력 필드
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(
                      top: 6,
                      left: 3,
                      right: 3,
                      bottom: 2,
                    ),
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(
                          width: 2,
                          color: Color(0xFF8863EF), // 컬러-서브-블루보라
                        ),
                      ),
                    ),
                    child: TextField(
                      controller: _titleController,
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 14,
                        fontFamily: 'LG Smart_H',
                        fontWeight: FontWeight.w400,
                        height: 1.71,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.only(
                          left: 0,
                          right: 0,
                          top: 0,
                          bottom: 0,
                        ),
                        hintText: '일정 제목을 입력하세요',
                        hintStyle: TextStyle(
                          color: Color(0xFF9B9BA1),
                          fontSize: 14,
                          fontFamily: 'LG Smart_H',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // 시간 지정하기
                  Text(
                    '시간 지정하기',
                    style: TextStyle(
                      color: const Color(0xFF9B9BA1),
                      fontSize: 10,
                      fontFamily: 'LG Smart_H',
                      fontWeight: FontWeight.w700,
                      height: 1.60,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 시간 선택 버튼
                  GestureDetector(
                    onTap: () {
                      // 시간 선택 로직 추가
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFEAECF0),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedTime ?? '시간 선택',
                            style: TextStyle(
                              color: _selectedTime != null
                                  ? const Color(0xFF111111)
                                  : const Color(0xFF9B9BA1),
                              fontSize: 14,
                              fontFamily: 'LG Smart_H',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: Color(0xFF9B9BA1),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // 카테고리
                  Text(
                    '카테고리',
                    style: TextStyle(
                      color: const Color(0xFF9B9BA1),
                      fontSize: 10,
                      fontFamily: 'LG Smart_H',
                      fontWeight: FontWeight.w700,
                      height: 1.60,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 카테고리 선택 버튼
                  GestureDetector(
                    onTap: () {
                      // 카테고리 선택 로직 추가
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFEAECF0),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedCategory ?? '카테고리 선택',
                            style: TextStyle(
                              color: _selectedCategory != null
                                  ? const Color(0xFF111111)
                                  : const Color(0xFF9B9BA1),
                              fontSize: 14,
                              fontFamily: 'LG Smart_H',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: Color(0xFF9B9BA1),
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
            margin: const EdgeInsets.fromLTRB(7, 0, 7, 0),
            width: double.infinity,
            height: 60,
            decoration: ShapeDecoration(
              gradient: const LinearGradient(
                begin: Alignment(-0.00, -1.44),
                end: Alignment(1.07, 1.73),
                colors: [
                  Color(0xFFE756B3), // 컬러-서브-진달래
                  Color(0xFF8863EF), // 컬러-서브-블루보라
                  Color(0xFFFFE6CD), // 컬러-서브-아이보리
                ],
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              shadows: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                  spreadRadius: 0,
                ),
              ],
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
                borderRadius: BorderRadius.circular(16),
                child: const Center(
                  child: Text(
                    '일정 추가하기',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'LG Smart_H',
                      fontWeight: FontWeight.w700,
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
