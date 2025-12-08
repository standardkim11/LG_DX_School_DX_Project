// 일정 추가하기 모달

import 'package:flutter/material.dart';
import 'app_colors.dart';

class AddTodoModal extends StatefulWidget {
  const AddTodoModal({super.key});

  @override
  State<AddTodoModal> createState() => _AddTodoModalState();
}

class _AddTodoModalState extends State<AddTodoModal> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _newCategoryController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _categoryFocusNode = FocusNode();
  final GlobalKey _hourKey = GlobalKey();
  final GlobalKey _minuteKey = GlobalKey();
  final GlobalKey _categoryKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  String? _selectedHour;
  String? _selectedMinute;
  String? _selectedCategory;
  List<String> _categories = ['친구', '공부', '취미', '직접입력'];
  bool _showHourDropdown = false;
  bool _showMinuteDropdown = false;
  bool _showCategoryDropdown = false;
  bool _showAddCategory = false;
  bool _showCustomCategoryInput = false;

  // 시간 목록 (06-05 순서)
  List<String> get _hourOptions {
    // 06부터 시작해서 23까지, 그 다음 00부터 05까지
    final hours = <String>[];
    for (int i = 6; i <= 23; i++) {
      hours.add(i.toString().padLeft(2, '0'));
    }
    for (int i = 0; i <= 5; i++) {
      hours.add(i.toString().padLeft(2, '0'));
    }
    return hours;
  }

  // 분 목록 (10분 단위: 0, 10, 20, 30, 40, 50)
  List<String> get _minuteOptions {
    return ['00', '10', '20', '30', '40', '50'];
  }

  String? get _selectedTime {
    if (_selectedHour != null && _selectedMinute != null) {
      return '$_selectedHour:$_selectedMinute';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _titleFocusNode.addListener(() {
      setState(() {});
      // 키보드가 올라올 때 입력 필드가 보이도록 스크롤
      if (_titleFocusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToField(_titleFocusNode);
        });
      }
    });
    _categoryFocusNode.addListener(() {
      setState(() {});
      // 키보드가 올라올 때 입력 필드가 보이도록 스크롤
      if (_categoryFocusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToField(_categoryFocusNode);
        });
      }
    });
    _titleController.addListener(() => setState(() {}));
  }

  void _scrollToField(FocusNode focusNode) {
    final context = focusNode.context;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _newCategoryController.dispose();
    _titleFocusNode.dispose();
    _categoryFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _saveAndClose() {
    if (_titleController.text.isNotEmpty) {
      Navigator.pop(context, {
        'title': _titleController.text,
        'time': _selectedTime,
        'category': _selectedCategory,
      });
    }
  }

  void _addNewCategory() {
    if (_newCategoryController.text.isNotEmpty) {
      setState(() {
        _categories.add(_newCategoryController.text);
        _selectedCategory = _newCategoryController.text;
        _newCategoryController.clear();
        _showAddCategory = false;
        _showCategoryDropdown = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 키보드 높이 감지 (스크롤 패딩용)
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    // 모달 높이는 고정 (Padding으로 키보드 위로 올라가므로 높이는 변경하지 않음)
    final screenHeight = MediaQuery.of(context).size.height;
    final modalHeight = screenHeight * 0.42; // 0.35 -> 0.42로 증가

    return GestureDetector(
      onTap: () {
        // 모달 외부 클릭 시 드롭다운 닫고 뒤로가기
        setState(() {
          _showHourDropdown = false;
          _showMinuteDropdown = false;
          _showCategoryDropdown = false;
          _showAddCategory = false;
        });
        FocusScope.of(context).unfocus();
        Navigator.pop(context);
      },
      child: Container(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {
            // 드롭다운이 열려있을 때는 닫기만 하고, 닫혀있을 때는 아무것도 하지 않음
            if (_showHourDropdown ||
                _showMinuteDropdown ||
                _showCategoryDropdown) {
              setState(() {
                _showHourDropdown = false;
                _showMinuteDropdown = false;
                _showCategoryDropdown = false;
              });
            }
          },
          child: Container(
            height: modalHeight,
            decoration: const BoxDecoration(
              color: Colors.white,
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
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SingleChildScrollView(
                        controller: _scrollController,
                        padding: EdgeInsets.only(
                          left: 14,
                          right: 14,
                          bottom:
                              100 +
                              keyboardHeight, // 저장 버튼 공간 + 키보드 높이 (80 -> 100으로 증가)
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 제목
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
                            GestureDetector(
                              onTap: () => _titleFocusNode.requestFocus(),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.only(
                                  top: 6,
                                  left: 3,
                                  right: 3,
                                  bottom: 2,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: const Color(0xFF8863EF),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: TextField(
                                  controller: _titleController,
                                  focusNode: _titleFocusNode,
                                  style: TextStyle(
                                    color: const Color(0xFF111111),
                                    fontSize: 14,
                                    fontFamily: 'LG Smart_H',
                                    fontWeight: FontWeight.w400,
                                    height: 1.71,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // 시간/카테고리 한 줄
                            Row(
                              children: [
                                // 시간 지정하기
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '시간',
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
                                      // 시간 선택 (시)
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _showHourDropdown =
                                                !_showHourDropdown;
                                            _showMinuteDropdown = false;
                                            _showCategoryDropdown = false;
                                          });
                                        },
                                        behavior: HitTestBehavior.opaque,
                                        child: Container(
                                          key: _hourKey,
                                          width: double.infinity,
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                            left: 3,
                                            right: 3,
                                            bottom: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color:
                                                    (_showHourDropdown ||
                                                        _selectedHour != null)
                                                    ? const Color(0xFF8863EF)
                                                    : Colors.transparent,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Text(
                                                _selectedHour ?? '',
                                                style: TextStyle(
                                                  color: _selectedHour != null
                                                      ? const Color(0xFF111111)
                                                      : const Color(0xFF9B9BA1),
                                                  fontSize: 14,
                                                  fontFamily: 'LG Smart_H',
                                                  fontWeight: FontWeight.w400,
                                                  height: 1.71,
                                                ),
                                              ),
                                              Builder(
                                                builder: (context) {
                                                  // 드롭다운이 실제로 렌더링되는지 확인
                                                  final renderBox =
                                                      _hourKey.currentContext
                                                              ?.findRenderObject()
                                                          as RenderBox?;
                                                  final stackBox =
                                                      context.findRenderObject()
                                                          as RenderBox?;
                                                  final isVisible =
                                                      _showHourDropdown &&
                                                      renderBox != null &&
                                                      stackBox != null;
                                                  return Icon(
                                                    isVisible
                                                        ? Icons
                                                              .keyboard_arrow_up
                                                        : Icons
                                                              .keyboard_arrow_down,
                                                    size: 20,
                                                    color: const Color(
                                                      0xFF9B9BA1,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // 분 선택
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 18), // 타이틀 높이 맞추기
                                      const SizedBox(height: 8),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _showMinuteDropdown =
                                                !_showMinuteDropdown;
                                            _showHourDropdown = false;
                                            _showCategoryDropdown = false;
                                          });
                                        },
                                        behavior: HitTestBehavior.opaque,
                                        child: Container(
                                          key: _minuteKey,
                                          width: double.infinity,
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                            left: 3,
                                            right: 3,
                                            bottom: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color:
                                                    (_showMinuteDropdown ||
                                                        _selectedMinute != null)
                                                    ? const Color(0xFF8863EF)
                                                    : Colors.transparent,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Text(
                                                _selectedMinute ?? '',
                                                style: TextStyle(
                                                  color: _selectedMinute != null
                                                      ? const Color(0xFF111111)
                                                      : const Color(0xFF9B9BA1),
                                                  fontSize: 14,
                                                  fontFamily: 'LG Smart_H',
                                                  fontWeight: FontWeight.w400,
                                                  height: 1.71,
                                                ),
                                              ),
                                              Builder(
                                                builder: (context) {
                                                  // 드롭다운이 실제로 렌더링되는지 확인
                                                  final renderBox =
                                                      _minuteKey.currentContext
                                                              ?.findRenderObject()
                                                          as RenderBox?;
                                                  final stackBox =
                                                      context.findRenderObject()
                                                          as RenderBox?;
                                                  final isVisible =
                                                      _showMinuteDropdown &&
                                                      renderBox != null &&
                                                      stackBox != null;
                                                  return Icon(
                                                    isVisible
                                                        ? Icons
                                                              .keyboard_arrow_up
                                                        : Icons
                                                              .keyboard_arrow_down,
                                                    size: 20,
                                                    color: const Color(
                                                      0xFF9B9BA1,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // 카테고리
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
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
                                      // 카테고리 선택 또는 직접입력
                                      Container(
                                        key: _categoryKey,
                                        width: double.infinity,
                                        padding: const EdgeInsets.only(
                                          top: 6,
                                          left: 3,
                                          right: 3,
                                          bottom: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color:
                                                  (_showCategoryDropdown ||
                                                      _selectedCategory !=
                                                          null ||
                                                      _showCustomCategoryInput)
                                                  ? const Color(0xFF8863EF)
                                                  : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        child:
                                            _showCustomCategoryInput &&
                                                _selectedCategory == '직접입력'
                                            ? TextField(
                                                controller:
                                                    _newCategoryController,
                                                focusNode: _categoryFocusNode,
                                                autofocus: true,
                                                style: TextStyle(
                                                  color: const Color(
                                                    0xFF111111,
                                                  ),
                                                  fontSize: 14,
                                                  fontFamily: 'LG Smart_H',
                                                  fontWeight: FontWeight.w400,
                                                  height: 1.71,
                                                ),
                                                decoration:
                                                    const InputDecoration(
                                                      border: InputBorder.none,
                                                    ),
                                                onChanged: (value) {
                                                  setState(() {
                                                    if (value.isNotEmpty) {
                                                      _selectedCategory = value;
                                                    } else {
                                                      _selectedCategory =
                                                          '직접입력';
                                                    }
                                                  });
                                                },
                                              )
                                            : GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _showCategoryDropdown =
                                                        !_showCategoryDropdown;
                                                    _showHourDropdown = false;
                                                    _showMinuteDropdown = false;
                                                  });
                                                },
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      _selectedCategory ?? '',
                                                      style: TextStyle(
                                                        color:
                                                            _selectedCategory !=
                                                                null
                                                            ? const Color(
                                                                0xFF111111,
                                                              )
                                                            : const Color(
                                                                0xFF9B9BA1,
                                                              ),
                                                        fontSize: 14,
                                                        fontFamily:
                                                            'LG Smart_H',
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        height: 1.71,
                                                      ),
                                                    ),
                                                    Builder(
                                                      builder: (context) {
                                                        // 드롭다운이 실제로 렌더링되는지 확인
                                                        final renderBox =
                                                            _categoryKey
                                                                    .currentContext
                                                                    ?.findRenderObject()
                                                                as RenderBox?;
                                                        final stackBox =
                                                            context.findRenderObject()
                                                                as RenderBox?;
                                                        final isVisible =
                                                            _showCategoryDropdown &&
                                                            renderBox != null &&
                                                            stackBox != null;
                                                        return Icon(
                                                          isVisible
                                                              ? Icons
                                                                    .keyboard_arrow_up
                                                              : Icons
                                                                    .keyboard_arrow_down,
                                                          size: 20,
                                                          color: const Color(
                                                            0xFF9B9BA1,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                      // 저장 버튼 - 하단에 고정
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: EdgeInsets.only(
                            left: 14,
                            right: 14,
                            top: 12,
                            bottom:
                                40 +
                                MediaQuery.of(
                                  context,
                                ).padding.bottom, // SafeArea 하단 패딩 추가
                          ),
                          child: Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8863EF),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF8863EF,
                                  ).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _saveAndClose,
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  alignment: Alignment.center,
                                  child: const Text(
                                    '저장',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontFamily: 'LG Smart_H',
                                      fontWeight: FontWeight.w600,
                                      height: 1.43,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 드롭다운들을 Positioned로 배치
                      // 시간 드롭다운 (시)
                      Builder(
                        builder: (context) {
                          if (!_showHourDropdown) {
                            return const SizedBox.shrink();
                          }

                          final RenderBox? renderBox =
                              _hourKey.currentContext?.findRenderObject()
                                  as RenderBox?;
                          if (renderBox == null) {
                            return const SizedBox.shrink();
                          }
                          final position = renderBox.localToGlobal(Offset.zero);
                          final size = renderBox.size;
                          final stackBox =
                              context.findRenderObject() as RenderBox?;
                          final stackPosition = stackBox?.localToGlobal(
                            Offset.zero,
                          );

                          if (stackPosition == null) {
                            return const SizedBox.shrink();
                          }

                          // Stack 내부의 SingleChildScrollView 기준으로 계산
                          // localToGlobal은 이미 스크롤 오프셋이 반영된 좌표를 반환
                          // Stack의 위치를 빼면 상대 위치가 나옴
                          final topPosition =
                              position.dy - stackPosition.dy + size.height + 4;

                          return Positioned(
                            left: 14,
                            top: topPosition,
                            child: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 100,
                                constraints: const BoxConstraints(
                                  maxHeight: 150,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _hourOptions.length,
                                  itemBuilder: (context, index) {
                                    final hour = _hourOptions[index];
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedHour = hour;
                                          _showHourDropdown = false;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _selectedHour == hour
                                              ? const Color(
                                                  0xFF8863EF,
                                                ).withOpacity(0.1)
                                              : Colors.transparent,
                                        ),
                                        child: Text(
                                          hour,
                                          style: TextStyle(
                                            color: _selectedHour == hour
                                                ? const Color(0xFF8863EF)
                                                : const Color(0xFF111111),
                                            fontSize: 14,
                                            fontFamily: 'LG Smart_H',
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // 분 드롭다운
                      if (_showMinuteDropdown)
                        Builder(
                          builder: (context) {
                            final RenderBox? renderBox =
                                _minuteKey.currentContext?.findRenderObject()
                                    as RenderBox?;
                            if (renderBox == null) {
                              return const SizedBox.shrink();
                            }
                            final position = renderBox.localToGlobal(
                              Offset.zero,
                            );
                            final size = renderBox.size;
                            final stackBox =
                                context.findRenderObject() as RenderBox?;
                            final stackPosition = stackBox?.localToGlobal(
                              Offset.zero,
                            );

                            if (stackPosition == null) {
                              return const SizedBox.shrink();
                            }

                            // Stack 내부의 SingleChildScrollView 기준으로 계산
                            final topPosition =
                                position.dy -
                                stackPosition.dy +
                                size.height +
                                4;

                            return Positioned(
                              left: 126, // 시간 필드 너비 + 간격
                              top: topPosition,
                              child: Material(
                                elevation: 8,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 100,
                                  constraints: const BoxConstraints(
                                    maxHeight: 150,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _minuteOptions.length,
                                    itemBuilder: (context, index) {
                                      final minute = _minuteOptions[index];
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedMinute = minute;
                                            _showMinuteDropdown = false;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _selectedMinute == minute
                                                ? const Color(
                                                    0xFF8863EF,
                                                  ).withOpacity(0.1)
                                                : Colors.transparent,
                                          ),
                                          child: Text(
                                            minute,
                                            style: TextStyle(
                                              color: _selectedMinute == minute
                                                  ? const Color(0xFF8863EF)
                                                  : const Color(0xFF111111),
                                              fontSize: 14,
                                              fontFamily: 'LG Smart_H',
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      // 카테고리 드롭다운
                      Builder(
                        builder: (context) {
                          if (!_showCategoryDropdown) {
                            return const SizedBox.shrink();
                          }

                          final RenderBox? renderBox =
                              _categoryKey.currentContext?.findRenderObject()
                                  as RenderBox?;
                          if (renderBox == null) {
                            return const SizedBox.shrink();
                          }
                          final position = renderBox.localToGlobal(Offset.zero);
                          final size = renderBox.size;
                          final stackBox =
                              context.findRenderObject() as RenderBox?;
                          final stackPosition = stackBox?.localToGlobal(
                            Offset.zero,
                          );

                          if (stackPosition == null) {
                            return const SizedBox.shrink();
                          }

                          // Stack 내부의 SingleChildScrollView 기준으로 계산
                          final topPosition =
                              position.dy - stackPosition.dy + size.height + 4;

                          return Positioned(
                            left: 238, // 시간 필드 + 분 필드 + 간격
                            top: topPosition,
                            right: 14,
                            child: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.of(context).size.height *
                                      0.5, // 40% -> 50%로 증가
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 카테고리 목록
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: _categories.length,
                                        itemBuilder: (context, index) {
                                          final category = _categories[index];
                                          return GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _selectedCategory = category;
                                                _showCategoryDropdown = false;
                                                if (category == '직접입력') {
                                                  _showCustomCategoryInput =
                                                      true;
                                                  _newCategoryController
                                                      .clear();
                                                  // 입력 필드에 포커스 주기
                                                  WidgetsBinding.instance
                                                      .addPostFrameCallback((
                                                        _,
                                                      ) {
                                                        _categoryFocusNode
                                                            .requestFocus();
                                                      });
                                                } else {
                                                  _showCustomCategoryInput =
                                                      false;
                                                }
                                              });
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 12,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    _selectedCategory ==
                                                        category
                                                    ? const Color(
                                                        0xFF8863EF,
                                                      ).withOpacity(0.1)
                                                    : Colors.transparent,
                                              ),
                                              child: Text(
                                                category,
                                                style: TextStyle(
                                                  color:
                                                      _selectedCategory ==
                                                          category
                                                      ? const Color(0xFF8863EF)
                                                      : const Color(0xFF111111),
                                                  fontSize: 14,
                                                  fontFamily: 'LG Smart_H',
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      // 카테고리 추가 버튼
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _showAddCategory =
                                                !_showAddCategory;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              top: BorderSide(
                                                color: Colors.grey.withOpacity(
                                                  0.2,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.add,
                                                size: 20,
                                                color: Color(0xFF8863EF),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '카테고리 추가',
                                                style: TextStyle(
                                                  color: const Color(
                                                    0xFF8863EF,
                                                  ),
                                                  fontSize: 14,
                                                  fontFamily: 'LG Smart_H',
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // 카테고리 입력 필드
                                      if (_showAddCategory)
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              top: BorderSide(
                                                color: Colors.grey.withOpacity(
                                                  0.2,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller:
                                                      _newCategoryController,
                                                  autofocus: true,
                                                  style: TextStyle(
                                                    color: const Color(
                                                      0xFF111111,
                                                    ),
                                                    fontSize: 14,
                                                    fontFamily: 'LG Smart_H',
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                  decoration: InputDecoration(
                                                    border: UnderlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: const Color(
                                                          0xFF8863EF,
                                                        ),
                                                        width: 2,
                                                      ),
                                                    ),
                                                    focusedBorder:
                                                        UnderlineInputBorder(
                                                          borderSide: BorderSide(
                                                            color: const Color(
                                                              0xFF8863EF,
                                                            ),
                                                            width: 2,
                                                          ),
                                                        ),
                                                  ),
                                                  onSubmitted: (_) =>
                                                      _addNewCategory(),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: _addNewCategory,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF8863EF,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
