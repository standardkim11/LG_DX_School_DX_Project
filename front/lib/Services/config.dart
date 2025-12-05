// API 서버 설정 파일
//
// 에뮬레이터 사용 시:
//   - useEmulator = true (기본값)로 설정
//   - 추가 설정 불필요, 바로 사용 가능
//
// 실제 휴대폰 사용 시:
//   1. useEmulator = false로 변경
//   2. localNetworkIp에 PC의 로컬 IP 주소 입력
//   3. PC의 IP 주소 확인 방법:
//      - Windows: ipconfig 명령어 실행 후 "IPv4 주소" 확인
//      - Mac/Linux: ifconfig 또는 ip addr 명령어 실행
//
class ApiConfig {
  // 실제 휴대폰에서 사용할 PC의 로컬 IP 주소
  // 예: '192.168.0.100' 또는 '192.168.1.50'
  // 실제 휴대폰에서 테스트할 때만 이 값을 PC의 실제 IP 주소로 변경하세요
  static const String localNetworkIp = '192.168.0.34'; // PC의 실제 IP 주소

  // Android 에뮬레이터에서 사용할 IP (변경 불필요)
  static const String androidEmulatorIp = '10.0.2.2';

  static const int port = 8088;

  // 에뮬레이터 사용 여부
  // - true: Android 에뮬레이터에서 사용 (기본값, 10.0.2.2 사용)
  // - false: 실제 휴대폰에서 사용 (PC의 로컬 IP 주소 사용)
  static const bool useEmulator = false; // 실제 휴대폰에서 사용

  static String getBaseUrl({
    required bool isWeb,
    required bool isAndroid,
    required bool isIOS,
  }) {
    if (isWeb) {
      return 'http://localhost:$port/api';
    } else if (isAndroid) {
      // 에뮬레이터 사용 여부에 따라 IP 선택
      if (useEmulator) {
        return 'http://$androidEmulatorIp:$port/api';
      } else {
        // 실제 휴대폰: PC의 로컬 네트워크 IP 주소 사용
        return 'http://$localNetworkIp:$port/api';
      }
    } else if (isIOS) {
      return 'http://localhost:$port/api';
    }
    return 'http://localhost:$port/api';
  }
}
