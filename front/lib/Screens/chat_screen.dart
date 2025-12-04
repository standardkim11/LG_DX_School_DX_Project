import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [
    {
      'text': '오늘 시간이 별로 없어서 오늘 꼭 해야할 루틴 중요한 순위로 좀 알려줘',
      'isUser': true,
    },
    {
      'text': '좋아,\n\n귀가 전 바닥 청소하기\n세탁기 돌리기\n\n원하면 바로 우선순위 설정해 줄까?',
      'isUser': false,
    },
    {
      'text': '나 이번주에 세탁기 몇 번 돌렸어?',
      'isUser': true,
    },
    {
      'text': '1번 돌려서 긴급으로 저장되어 있어',
      'isUser': false,
    },
    {
      'text': '그럼 그렇게 설정해 줘',
      'isUser': true,
    },
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
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

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      setState(() {
        _messages.add({
          'text': _messageController.text,
          'isUser': true,
        });
      });
      _messageController.clear();
      _scrollToBottom();
    }
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isUser = message['isUser'] as bool;
                    // 이전 메시지 확인
                    final prevMessage = index > 0 ? _messages[index - 1] : null;
                    final prevIsUser = prevMessage != null ? prevMessage['isUser'] as bool : null;
                    // 질문-답 그룹 사이에만 여백 추가 (Rou 답변 다음에 사용자 질문이 오는 경우)
                    final shouldAddSpacing = prevIsUser == false && isUser == true;
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
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
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
                      child: TextField(
                        controller: _messageController,
                        maxLines: null,
                        minLines: 1,
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
                        onSubmitted: (text) {
                          _sendMessage();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Image.asset(
                        'assets/bottom_navigation_icon/Send_icon.png',
                        width: 18,
                        height: 18,
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

  Widget _buildMessageBubble(String text, bool isUser, {bool addTopSpacing = false}) {
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

