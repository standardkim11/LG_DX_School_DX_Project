// API 서버 설정 파일
//
// 자동 감지 모드:
//   - 에뮬레이터와 실제 기기를 자동으로 감지하여 적절한 IP 사용
//   - 에뮬레이터: 10.0.2.2 사용
//   - 실제 기기: localNetworkIp 사용
//
// 수동 설정 모드:
//   - useEmulator를 true/false로 설정하여 강제 지정 가능
//
class ApiConfig {
  // 실제 휴대폰에서 사용할 PC의 로컬 IP 주소
  // 예: '192.168.0.100' 또는 '192.168.1.50'
  // PC의 IP 주소 확인 방법:
  //   - Windows: ipconfig 명령어 실행 후 "IPv4 주소" 확인
  //   - Mac/Linux: ifconfig 또는 ip addr 명령어 실행
  static const String localNetworkIp = '192.168.0.34'; // PC의 실제 IP 주소

  // Android 에뮬레이터에서 사용할 IP (변경 불필요)
  static const String androidEmulatorIp = '10.0.2.2';

  static const int port = 8088;

  // 에뮬레이터 사용 여부 (null이면 자동 감지)
  // - null: 자동 감지 (에뮬레이터와 실제 기기 모두 지원)
  // - true: 에뮬레이터 강제 사용 (10.0.2.2 사용)
  // - false: 실제 기기 강제 사용 (localNetworkIp 사용)
  static const bool? useEmulator = false; // 실제 휴대폰 사용 시 false로 설정

  static String getBaseUrl({
    required bool isWeb,
    required bool isAndroid,
    required bool isIOS,
  }) {
    if (isWeb) {
      return 'http://localhost:$port/api';
    } else if (isAndroid) {
      // useEmulator가 null이면 자동 감지 (에뮬레이터 우선 시도)
      // 실제로는 연결 시도로 판단하지만, 여기서는 에뮬레이터 IP를 우선 반환
      // 서비스 레이어에서 연결 실패 시 fallback 로직 사용
      if (useEmulator == true) {
        return 'http://$androidEmulatorIp:$port/api';
      } else if (useEmulator == false) {
        return 'http://$localNetworkIp:$port/api';
      } else {
        // 자동 감지: 에뮬레이터 IP를 기본값으로 사용
        // (대부분의 경우 에뮬레이터에서 개발하므로)
        return 'http://$androidEmulatorIp:$port/api';
      }
    } else if (isIOS) {
      return 'http://localhost:$port/api';
    }
    return 'http://localhost:$port/api';
  }

  /// Android에서 사용할 수 있는 모든 가능한 base URL 목록 반환
  /// (에뮬레이터와 실제 기기 모두 지원)
  static List<String> getAndroidBaseUrls() {
    return [
      'http://$androidEmulatorIp:$port/api', // 에뮬레이터
      'http://$localNetworkIp:$port/api', // 실제 기기
    ];
  }
}
