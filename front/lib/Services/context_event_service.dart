import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class ContextEventService {
  static String get baseUrl {
    // config.dart에서 설정된 IP 주소 사용
    return ApiConfig.getBaseUrl(
      isWeb: kIsWeb,
      isAndroid: Platform.isAndroid,
      isIOS: Platform.isIOS,
    );
  }

  static const int userId = 1; // 테스트용 고정 user_id

  /// context_event API를 호출하여 귀가 시점 추천 정보를 가져옵니다.
  ///
  /// [currentLat] 현재 위치 위도
  /// [currentLng] 현재 위치 경도
  /// Returns: context_event 응답 데이터
  static Future<Map<String, dynamic>?> getContextEvent({
    required double currentLat,
    required double currentLng,
  }) async {
    // Android인 경우 여러 URL 시도 (병렬 처리로 개선)
    List<String> urlsToTry = [baseUrl];
    if (!kIsWeb && Platform.isAndroid && ApiConfig.useEmulator == null) {
      urlsToTry = ApiConfig.getAndroidBaseUrls();
    }

    // 성능 최적화: 순차적으로 시도 (실제 기기에서는 10.0.2.2 타임아웃 시간 낭비 방지)
    // 첫 번째 URL부터 시도하고, 성공하면 즉시 반환
    print('[ContextEventService] 연결 시도 시작: ${urlsToTry.length}개 URL');
    for (int i = 0; i < urlsToTry.length; i++) {
      final url = urlsToTry[i];
      print('[ContextEventService] 시도 ${i + 1}/${urlsToTry.length}: $url');
      try {
        final uri = Uri.parse('$url/recommend/context-event');

        final response = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'user_id': userId,
                'current_lat': currentLat,
                'current_lng': currentLng,
                'event_type': 'ARRIVE_HOME',
              }),
            )
            .timeout(
              const Duration(seconds: 10), // 실제 기기에서는 빠른 실패로 다음 URL 시도
              onTimeout: () {
                throw Exception('요청 시간 초과');
              },
            );

        if (response.statusCode == 200) {
          final data =
              jsonDecode(utf8.decode(response.bodyBytes))
                  as Map<String, dynamic>;
          print('[ContextEventService] 성공: $url');
          return data;
        } else {
          // HTTP 에러
          print('[ContextEventService] HTTP 에러 ($url): ${response.statusCode}');
          continue;
        }
      } catch (e) {
        // 모든 URL 시도 실패 시 로그 출력
        print('[ContextEventService] 연결 실패 ($url): $e');
        if (i == urlsToTry.length - 1) {
          // 마지막 URL도 실패
          print('[ContextEventService] 모든 URL 연결 시도 실패');
        }
        continue;
      }
    }

    // 모든 URL 시도 실패
    print('[ContextEventService] 최종 실패: 모든 URL 연결 시도 완료');
    return null;
  }
}
