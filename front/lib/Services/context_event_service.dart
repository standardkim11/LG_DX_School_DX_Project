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
    // Android인 경우 여러 URL 시도
    List<String> urlsToTry = [baseUrl];
    if (!kIsWeb && Platform.isAndroid && ApiConfig.useEmulator == null) {
      urlsToTry = ApiConfig.getAndroidBaseUrls();
    }

    for (final url in urlsToTry) {
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
              const Duration(seconds: 30), // 타임아웃 단축 (30초로 변경)
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
          print(
            '[ContextEventService] API Error ($url): ${response.statusCode} - ${response.body}',
          );
          continue; // 다음 URL 시도
        }
      } catch (e) {
        print('[ContextEventService] 연결 실패 ($url): $e');
        continue; // 다음 URL 시도
      }
    }

    // 모든 URL 시도 실패
    print('[ContextEventService] 모든 URL 시도 실패');
    return null;
  }
}
