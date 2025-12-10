import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// 전역 웹뷰 컨트롤러 (이미 열린 브라우저 관리)
WebViewController? _globalWashingMachineController;
bool _isWashingMachineScreenOpen = false;

class WashingMachineScreen extends StatefulWidget {
  final bool autoStart;

  const WashingMachineScreen({super.key, this.autoStart = false});

  @override
  State<WashingMachineScreen> createState() => _WashingMachineScreenState();
}

class _WashingMachineScreenState extends State<WashingMachineScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  @override
  void dispose() {
    // 화면이 닫힐 때 전역 컨트롤러 초기화
    if (_globalWashingMachineController == _controller) {
      _globalWashingMachineController = null;
      _isWashingMachineScreenOpen = false;
    }
    super.dispose();
  }

  void _initializeWebView() {
    // 이미 열린 브라우저가 있으면 재사용
    if (_globalWashingMachineController != null &&
        _isWashingMachineScreenOpen) {
      _controller = _globalWashingMachineController!;
      setState(() {
        _isLoading = false;
      });
      // 자동 시작이 요청되었으면 시작 버튼 클릭
      if (widget.autoStart) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _startWashingMachine();
        });
      }
      return;
    }

    // 새로운 웹뷰 생성
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            // 전역 컨트롤러에 저장
            _globalWashingMachineController = _controller;
            _isWashingMachineScreenOpen = true;
            // 페이지 로드 완료 후 자동 시작
            if (widget.autoStart) {
              Future.delayed(const Duration(milliseconds: 500), () {
                _startWashingMachine();
              });
            }
          },
        ),
      );

    // HTML 파일을 assets에서 로드
    _loadHtmlFromAssets();
  }

  Future<void> _loadHtmlFromAssets() async {
    try {
      // assets에서 HTML 파일 로드
      final String htmlContent = await rootBundle.loadString(
        'assets/show/washing-machine-demo.html',
      );

      // HTML 내용을 웹뷰에 로드
      // baseUrl을 설정하여 상대 경로 리소스(이미지 등)를 올바르게 로드할 수 있도록 함
      await _controller.loadHtmlString(
        htmlContent,
        baseUrl: kIsWeb
            ? 'assets/show/'
            : 'file:///android_asset/flutter_assets/assets/show/',
      );
    } catch (e) {
      print('[WashingMachineScreen] HTML 파일 로드 실패: $e');
      // 에러 발생 시 대체 HTML 표시
      _controller.loadHtmlString('''
        <html>
          <body>
            <h1>HTML 파일을 로드할 수 없습니다.</h1>
            <p>에러: $e</p>
            <p>assets/show/washing-machine-demo.html 파일이 존재하는지 확인해주세요.</p>
          </body>
        </html>
      ''');
    }
  }

  void _startWashingMachine() {
    // JavaScript를 통해 시작 버튼 클릭
    _controller.runJavaScript('''
      (function() {
        const playButton = document.getElementById('playButton');
        if (playButton) {
          playButton.click();
        }
      })();
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('세탁기'),
        backgroundColor: const Color(0xFF4B57BB),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
