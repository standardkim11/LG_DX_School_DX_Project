import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../Services/config.dart';
import 'routine_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  bool _isLoading = false;

  // API 베이스 URL
  static String get baseUrl {
    // config.dart에서 설정된 IP 주소 사용
    // Web에서는 Platform API를 사용할 수 없으므로 kIsWeb 체크
    return ApiConfig.getBaseUrl(
      isWeb: kIsWeb,
      isAndroid: !kIsWeb && Platform.isAndroid,
      isIOS: !kIsWeb && Platform.isIOS,
    );
  }

  static const int userId = 1; // 실제로는 사용자 인증에서 가져와야 함

  // 초기 환영 메시지 (첫 화면에만 표시)
  final List<Map<String, dynamic>> _initialMessages = [
    {
      'text': '지현님, 반가워요!',
      'isUser': false,
      'fontSize': 24.0,
      'fontWeight': FontWeight.w900,
    }, // 제일 크게, 볼드
    {'text': '루틴도 간단하게!', 'isUser': false, 'fontSize': 20.0}, // 크게
    {'text': '복잡한 루틴을 말 한마디로 만들어요.', 'isUser': false, 'fontSize': 15.0}, // 보통
    {'text': '원하는 조건과 제어할 제품만 말해보세요.', 'isUser': false, 'fontSize': 15.0}, // 보통
  ];

  // 실제 채팅 메시지
  final List<Map<String, dynamic>> _messages = [];

  // 초기 메시지가 표시되는지 여부
  bool _showInitialMessages = true;

  @override
  void initState() {
    super.initState();
    // 키보드 자동 포커스 제거
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isLoading) return;

    // 첫 메시지를 보낼 때 초기 메시지 제거
    if (_showInitialMessages) {
      setState(() {
        _showInitialMessages = false;
      });
    }

    // 사용자 메시지 추가
    setState(() {
      _messages.add({'text': messageText, 'isUser': true, 'fontSize': 15.0});
      _isLoading = true;
    });
    _messageController.clear();

    // 로딩 인디케이터가 표시되도록 스크롤 (여러 번 시도)
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollToBottom();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        _scrollToBottom();
      });
    });

    try {
      // Android인 경우 여러 URL 시도 (에뮬레이터와 실제 기기 모두 지원)
      List<String> urlsToTry = [baseUrl];
      if (!kIsWeb && Platform.isAndroid && ApiConfig.useEmulator == null) {
        // 자동 감지 모드: 에뮬레이터와 실제 기기 모두 시도
        urlsToTry = ApiConfig.getAndroidBaseUrls();
      }

      // 여러 URL 시도
      http.Response? response;
      String? successfulUrl;

      print('[ChatScreen] 채팅 API 연결 시도 시작: ${urlsToTry.length}개 URL');
      for (int i = 0; i < urlsToTry.length; i++) {
        final url = urlsToTry[i];
        print('[ChatScreen] 채팅 API 시도 ${i + 1}/${urlsToTry.length}: $url');
        try {
          // 오늘 날짜에 선택된 루틴 ID 가져오기
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final todayKey =
              '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
          final selectedRoutineIds = getSelectedRoutinesForDate(todayKey);
          final routineIdsList = selectedRoutineIds != null
              ? selectedRoutineIds.toList()
              : null;

          print('[ChatScreen] 오늘 날짜: $todayKey');
          print('[ChatScreen] 선택된 루틴 ID들: $routineIdsList');

          response = await http
              .post(
                Uri.parse('$url/chat/chat'),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                body: jsonEncode({
                  'user_id': userId,
                  'message': messageText,
                  'selected_routine_ids': routineIdsList, // 선택된 루틴 ID들 전달
                }),
              )
              .timeout(
                const Duration(seconds: 60), // 채팅은 응답 시간이 길 수 있으므로 60초로 설정
                onTimeout: () {
                  throw Exception('요청 시간 초과');
                },
              );

          if (response.statusCode == 200) {
            successfulUrl = url;
            print('[ChatScreen] 채팅 API 성공: $url');
            break; // 성공하면 즉시 종료
          } else {
            print('[ChatScreen] 채팅 API HTTP 에러 ($url): ${response.statusCode}');
            if (i < urlsToTry.length - 1) {
              continue; // 다음 URL 시도
            }
          }
        } catch (e) {
          print('[ChatScreen] 채팅 API 연결 실패 ($url): $e');
          if (i == urlsToTry.length - 1) {
            // 마지막 URL도 실패
            print('[ChatScreen] 채팅 API 모든 연결 시도 실패');
            throw e; // 모든 URL 실패 시 예외 던지기
          }
          continue; // 다음 URL 시도
        }
      }

      if (response == null) {
        throw Exception('모든 URL 연결 시도 실패');
      }

      // response가 null이 아니면 성공한 응답
      if (response!.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final reply = data['reply'] as String? ?? '응답을 받지 못했습니다.';

        setState(() {
          _messages.add({'text': reply, 'isUser': false, 'fontSize': 15.0});
          _isLoading = false;
        });
      } else {
        // 에러 응답 파싱 시도
        try {
          final errorData = jsonDecode(response.body);
          final errorMsg =
              errorData['message'] as String? ?? errorData['error'] as String?;
          final details = errorData['details'] as String?;

          String errorMessage = '서버 오류가 발생했습니다.';

          // 할당량 초과 에러 확인
          final fullErrorText = '${details ?? ''} ${errorMsg ?? ''}';
          if (fullErrorText.contains('quota') ||
              fullErrorText.contains('429') ||
              fullErrorText.contains('exceeded')) {
            errorMessage = 'AI 서비스 사용량이 초과되었습니다.\n잠시 후 다시 시도해주세요.';
          } else if (errorMsg != null) {
            if (errorMsg.contains('GEMINI_API_KEY')) {
              errorMessage =
                  'Google Gemini API 키가 설정되지 않았습니다.\n서버 관리자에게 문의해주세요.';
            } else {
              errorMessage = details ?? errorMsg;
            }
          } else if (details != null) {
            errorMessage = details;
          }

          setState(() {
            _messages.add({
              'text': errorMessage,
              'isUser': false,
              'fontSize': 15.0,
            });
            _isLoading = false;
          });
          _scrollToBottom();
          return;
        } catch (e) {
          // JSON 파싱 실패 시 기본 에러 처리
          final errorBody = response.body;
          throw Exception('서버 오류: ${response.statusCode}\n$errorBody');
        }
      }
    } catch (e) {
      String errorMessage = '죄송합니다. 연결에 문제가 발생했습니다.';

      if (e.toString().contains('Failed host lookup') ||
          e.toString().contains('Connection refused')) {
        errorMessage = '서버에 연결할 수 없습니다.\n백엔드 서버가 실행 중인지 확인해주세요.';
      } else if (e.toString().contains('요청 시간 초과')) {
        errorMessage = '요청 시간이 초과되었습니다.\n잠시 후 다시 시도해주세요.';
      } else if (e.toString().contains('서버 오류')) {
        errorMessage = '서버 오류가 발생했습니다.\n관리자에게 문의해주세요.';
      }

      setState(() {
        _messages.add({
          'text': errorMessage,
          'isUser': false,
          'fontSize': 15.0,
        });
        _isLoading = false;
      });

      // 디버깅용: 콘솔에 에러 출력
      print('Chat API Error: $e');
    }

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/lgrouthinq/Chat_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 상단 헤더
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Image.asset(
                        'assets/lgrouthinq/Back_icon.png',
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Rou',
                      style: TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 18,
                        fontFamily: 'LG Smart_H',
                        fontWeight: FontWeight.w600,
                        height: 1.33,
                      ),
                    ),
                  ],
                ),
              ),

              // 채팅 메시지 영역
              Expanded(
                child: _showInitialMessages
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(height: keyboardHeight > 0 ? 40 : 120),
                            ..._initialMessages.asMap().entries.map((entry) {
                              final index = entry.key;
                              final message = entry.value;
                              final fontSize =
                                  message['fontSize'] as double? ?? 15.0;
                              final fontWeight =
                                  message['fontWeight'] as FontWeight? ??
                                  FontWeight.w400;
                              // 마지막 두 메시지(인덱스 2와 3) 사이 간격만 줄임
                              final bottomPadding = (index == 2) ? 8.0 : 24.0;
                              return Padding(
                                padding: EdgeInsets.only(bottom: bottomPadding),
                                child: Text(
                                  message['text'] as String,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(0xFF111111),
                                    fontSize: fontSize,
                                    fontFamily: 'LG Smart_H',
                                    fontWeight: fontWeight,
                                    height: 1.47,
                                  ),
                                ),
                              );
                            }).toList(),
                            const Spacer(),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: _messages.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          // 로딩 중이고 마지막 아이템이면 봇 응답 위치에 로딩 인디케이터 표시
                          if (_isLoading && index == _messages.length) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: 24,
                                top: 16,
                              ),
                              child: _buildLoadingIndicator(),
                            );
                          }

                          final message = _messages[index];
                          final isUser = message['isUser'] as bool;
                          final fontSize =
                              message['fontSize'] as double? ?? 15.0;
                          // 이전 메시지 확인
                          final prevMessage = index > 0
                              ? _messages[index - 1]
                              : null;
                          final prevIsUser = prevMessage != null
                              ? prevMessage['isUser'] as bool
                              : null;
                          // 질문-답 그룹 사이에만 여백 추가 (Rou 답변 다음에 사용자 질문이 오는 경우)
                          final shouldAddSpacing =
                              prevIsUser == false && isUser == true;
                          return _buildMessageBubble(
                            message['text'] as String,
                            isUser,
                            fontSize: fontSize,
                            addTopSpacing: shouldAddSpacing,
                          );
                        },
                      ),
              ),

              // 하단 입력 영역
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: const Color(0xFFEAECF0), // 연한 회색 테두리
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add, color: Color(0xFF606D80), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        maxLines: 1,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.send,
                        enableInteractiveSelection: true,
                        style: const TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 15,
                          fontFamily: 'LG Smart_H',
                          fontWeight: FontWeight.w400,
                          height: 1.47,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '어떤 하루를 보내실 건가요?',
                          hintStyle: TextStyle(
                            color: Color(0xFF9B9BA1),
                            fontSize: 15,
                            fontFamily: 'LG Smart_H',
                            fontWeight: FontWeight.w400,
                            height: 1.47,
                          ),
                        ),
                        onSubmitted: (text) {
                          if (text.trim().isNotEmpty && !_isLoading) {
                            _sendMessage();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _isLoading ? null : _sendMessage,
                      child: Opacity(
                        opacity: _isLoading ? 0.5 : 1.0,
                        child: const Icon(
                          Icons.send,
                          color: Color(0xFF606D80),
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 16),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF111111),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '답변을 생성하고 있어요...',
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 15.0,
                    fontFamily: 'LG Smart_H',
                    fontWeight: FontWeight.w400,
                    height: 1.47,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildMessageBubble(
    String text,
    bool isUser, {
    double fontSize = 15.0,
    bool addTopSpacing = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 16,
        top: addTopSpacing ? 24 : 0, // 질문-답 그룹 사이에만 여백 추가
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 16),
          Flexible(
            child: isUser
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A6A6C).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                        color: const Color(0xFF111111),
                        fontSize: fontSize,
                        fontFamily: 'LG Smart_H',
                        fontWeight: FontWeight.w400,
                        height: 1.47,
                      ),
                    ),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      text,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: const Color(0xFF111111),
                        fontSize: fontSize,
                        fontFamily: 'LG Smart_H',
                        fontWeight: FontWeight.w400,
                        height: 1.47,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
