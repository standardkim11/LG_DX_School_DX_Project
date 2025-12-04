import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

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
  // 모바일/에뮬레이터: Android는 10.0.2.2, iOS 시뮬레이터는 localhost, 실제 기기는 컴퓨터 IP 사용
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8088/api';
    } else if (Platform.isAndroid) {
      // Android 에뮬레이터는 10.0.2.2 사용 (실제 기기는 컴퓨터의 로컬 IP 주소 사용)
      return 'http://10.0.2.2:8088/api';
    } else if (Platform.isIOS) {
      // iOS 시뮬레이터는 localhost 사용 (실제 기기는 컴퓨터의 로컬 IP 주소 사용)
      return 'http://localhost:8088/api';
    }
    return 'http://localhost:8088/api';
  }

  static const int userId = 1; // 실제로는 사용자 인증에서 가져와야 함

  final List<Map<String, dynamic>> _messages = [];

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

    // 사용자 메시지 추가
    setState(() {
      _messages.add({'text': messageText, 'isUser': true});
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      // API 호출 - 경로: /api/chat/chat (url_prefix="/api/chat" + route="/chat")
      // 모바일/에뮬레이터에서는 localhost 대신 10.0.2.2 (Android 에뮬레이터) 또는 실제 IP 사용
      final response = await http
          .post(
            Uri.parse('$baseUrl/chat/chat'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'user_id': userId, 'message': messageText}),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('요청 시간 초과');
            },
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['reply'] as String? ?? '응답을 받지 못했습니다.';

        setState(() {
          _messages.add({'text': reply, 'isUser': false});
          _isLoading = false;
        });
      } else {
        final errorBody = response.body;
        throw Exception('서버 오류: ${response.statusCode}\n$errorBody');
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
        _messages.add({'text': errorMessage, 'isUser': false});
        _isLoading = false;
      });

      // 디버깅용: 콘솔에 에러 출력
      print('Chat API Error: $e');
    }

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Rou',
                      style: TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 20,
                        fontFamily: 'LG Smart_H',
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),

              // 채팅 메시지 영역
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isUser = message['isUser'] as bool;
                    // 이전 메시지 확인
                    final prevMessage = index > 0 ? _messages[index - 1] : null;
                    final prevIsUser = prevMessage != null
                        ? prevMessage['isUser'] as bool
                        : null;
                    // 질문-답 그룹 사이에만 여백 추가 (Rou 답변 다음에 사용자 질문이 오는 경우)
                    final shouldAddSpacing =
                        prevIsUser == false && isUser == true;
                    return _buildMessageBubble(
                      message['text'] as String,
                      isUser,
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
                decoration: const BoxDecoration(color: Colors.white),
                child: Row(
                  children: [
                    const Text(
                      '+',
                      style: TextStyle(
                        color: Color(0xFF606D80),
                        fontSize: 32,
                        fontFamily: 'LG Smart_H',
                        fontWeight: FontWeight.w300,
                        height: 0.62,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.enter &&
                              !HardwareKeyboard.instance.isShiftPressed) {
                            if (_messageController.text.trim().isNotEmpty &&
                                !_isLoading) {
                              _sendMessage();
                            }
                          }
                        },
                        child: TextField(
                          controller: _messageController,
                          focusNode: _messageFocusNode,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Color(0xFF606D80),
                            fontSize: 14,
                            fontFamily: 'LG Smart_H',
                            fontWeight: FontWeight.w400,
                            height: 1.43,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '어떤 하루를 보내실 건가요?',
                            hintStyle: TextStyle(
                              color: Color(0xFF606D80),
                              fontSize: 14,
                              fontFamily: 'LG Smart_H',
                              fontWeight: FontWeight.w400,
                              height: 1.43,
                            ),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (text) {
                            if (text.trim().isNotEmpty) {
                              _sendMessage();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _isLoading ? null : _sendMessage,
                      child: Opacity(
                        opacity: _isLoading ? 0.5 : 1.0,
                        child: Image.asset(
                          'assets/bottom_navigation_icon/Send_icon.png',
                          width: 18,
                          height: 18,
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

  Widget _buildMessageBubble(
    String text,
    bool isUser, {
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
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 14,
                        fontFamily: 'LG Smart_H',
                        fontWeight: FontWeight.w400,
                        height: 1.43,
                      ),
                    ),
                  )
                : Text(
                    text,
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 14,
                      fontFamily: 'LG Smart_H',
                      fontWeight: FontWeight.w400,
                      height: 1.43,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
