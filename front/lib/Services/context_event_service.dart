import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ContextEventService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8088/api';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8088/api';
    } else if (Platform.isIOS) {
      return 'http://localhost:8088/api';
    }
    return 'http://localhost:8088/api';
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
    try {
      final uri = Uri.parse('$baseUrl/recommend/context-event');

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
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('요청 시간 초과');
            },
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return data;
      } else {
        print('Context Event API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Context Event Service Error: $e');
      return null;
    }
  }
}

