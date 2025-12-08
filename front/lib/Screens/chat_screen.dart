import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../Services/config.dart';

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

  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    // 화면이 열리면 자동으로 키보드 표시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _messageFocusNode.canRequestFocus) {
          _messageFocusNode.requestFocus();
          // 키보드 강제 표시 (에뮬레이터용)
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              SystemChannels.textInput.invokeMethod('TextInput.show');
            }
          });
        }
      });
    });
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

    // 사용자 메시지 추가
    setState(() {
      _messages.add({'text': messageText, 'isUser': true});
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      // Android인 경우 여러 URL 시도 (에뮬레이터와 실제 기기 모두 지원)
      List<String> urlsToTry = [baseUrl];
      if (!kIsWeb && Platform.isAndroid && ApiConfig.useEmulator == null) {
        // 자동 감지 모드: 에뮬레이터와 실제 기기 모두 시도
        urlsToTry = ApiConfig.getAndroidBaseUrls();
        print('[ChatService] Android 자동 감지 모드: ${urlsToTry.length}개 URL 시도');
      } else {
        print('[ChatService] 단일 URL 사용: $baseUrl');
      }

      Exception? lastException;
      for (final url in urlsToTry) {
        try {
          // API 호출 - 경로: /api/chat/chat (url_prefix="/api/chat" + route="/chat")
          final fullUrl = '$url/chat/chat';
          print('[ChatService] 연결 시도: $fullUrl');

          final response = await http
              .post(
                Uri.parse(fullUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                body: jsonEncode({'user_id': userId, 'message': messageText}),
              )
              .timeout(
                const Duration(seconds: 10), // 각 URL당 10초 타임아웃 (더 빠른 실패 감지)
                onTimeout: () {
                  print('[ChatService] 타임아웃 발생: $fullUrl');
                  throw Exception('요청 시간 초과');
                },
              );

          print('[ChatService] 응답 상태 코드: ${response.statusCode}');

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final reply = data['reply'] as String? ?? '응답을 받지 못했습니다.';

            print('[ChatService] ✅ 성공! 응답 받음');
            setState(() {
              _isLoading = false;
              _messages.add({'text': reply, 'isUser': false});
            });
            // 스크롤을 약간 지연시켜서 새 메시지가 렌더링된 후 스크롤
            Future.delayed(const Duration(milliseconds: 100), () {
              _scrollToBottom();
            });
            return; // 성공하면 종료
          } else {
            // 서버가 응답했지만 에러 상태 코드인 경우
            print('[ChatService] ⚠️ 서버 오류: ${response.statusCode}');
            try {
              final errorData = jsonDecode(response.body);
              final errorMsg =
                  errorData['message'] as String? ??
                  errorData['error'] as String?;
              print('[ChatService] 서버 에러 메시지: $errorMsg');

              // 500 에러는 서버 내부 오류이므로 즉시 사용자에게 표시 (다른 URL 시도 안 함)
              if (response.statusCode == 500) {
                String userMessage = '서버 내부 오류가 발생했습니다.';
                if (errorMsg != null) {
                  if (errorMsg.contains('GEMINI_API_KEY')) {
                    userMessage =
                        'Google Gemini API 키가 설정되지 않았습니다.\n서버 관리자에게 문의해주세요.';
                  } else {
                    userMessage = errorMsg;
                  }
                }
                setState(() {
                  _messages.add({'text': userMessage, 'isUser': false});
                  _isLoading = false;
                });
                _scrollToBottom();
                return; // 즉시 종료
              }
            } catch (e) {
              // JSON 파싱 실패 시
              print('[ChatService] JSON 파싱 실패: $e');
            }

            // 500이 아닌 다른 에러는 다음 URL 시도
            lastException = Exception('서버 오류: ${response.statusCode}');
            continue;
          }
        } catch (e) {
          print('[ChatService] $url 연결 실패: $e');
          print('[ChatService] 에러 타입: ${e.runtimeType}');
          if (e is http.ClientException) {
            print('[ChatService] ClientException 상세: ${e.message}');
          }
          lastException = e is Exception ? e : Exception(e.toString());
          // 다음 URL 시도
          continue;
        }
      }

      // 모든 URL 시도 실패
      final errorMessage = lastException != null
          ? '모든 연결 시도 실패: ${lastException.toString()}'
          : '모든 연결 시도 실패';
      throw Exception(errorMessage);
    } catch (e) {
      String errorMessage = '죄송합니다. 연결에 문제가 발생했습니다.';

      if (e.toString().contains('Failed host lookup') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('모든 연결 시도 실패')) {
        errorMessage = '서버에 연결할 수 없습니다.\n백엔드 서버가 실행 중인지 확인해주세요.';
      } else if (e.toString().contains('요청 시간 초과')) {
        errorMessage = '요청 시간이 초과되었습니다.\n네트워크 연결을 확인해주세요.';
      } else if (e.toString().contains('서버 내부 오류')) {
        errorMessage = '서버 내부 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.';
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
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    // 로딩 중이고 마지막 아이템이면 로딩 인디케이터 표시
                    if (_isLoading && index == _messages.length) {
                      return _buildLoadingIndicator();
                    }
                    
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
                      child: TextField(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        autofocus: true, // 자동 포커스 활성화
                        readOnly: false, // 읽기 전용 아님
                        enabled: true, // 활성화됨
                        maxLines: 1,
                        keyboardType:
                            TextInputType.multiline, // 한글 입력을 위해 multiline 사용
                        textInputAction: TextInputAction.send,
                        enableInteractiveSelection: true,
                        enableSuggestions: true, // 제안 활성화
                        autocorrect: true, // 자동 수정 활성화
                        textCapitalization:
                            TextCapitalization.none, // 대문자 자동 변환 비활성화
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
                        onTap: () {
                          // TextField를 직접 탭했을 때도 포커스 요청
                          if (!_messageFocusNode.hasFocus) {
                            _messageFocusNode.requestFocus();
                          }
                          // 키보드 강제 표시 (에뮬레이터용)
                          Future.delayed(const Duration(milliseconds: 100), () {
                            SystemChannels.textInput.invokeMethod(
                              'TextInput.show',
                            );
                          });
                        },
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

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF111111).withOpacity(0.6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '답변을 생성하고 있어요...',
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 14,
                    fontFamily: 'LG Smart_H',
                    fontWeight: FontWeight.w400,
                    height: 1.43,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
