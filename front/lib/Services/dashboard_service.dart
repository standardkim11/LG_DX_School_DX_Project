// services/dashboard_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/dashboard_response.dart';

class DashboardService {
  // API 베이스 URL (chat_screen과 동일한 방식)
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8088/api';
    } else if (Platform.isAndroid) {
      // Android 에뮬레이터는 10.0.2.2 사용
      return 'http://10.0.2.2:8088/api';
    } else if (Platform.isIOS) {
      // iOS 시뮬레이터는 localhost 사용
      return 'http://localhost:8088/api';
    }
    return 'http://localhost:8088/api';
  }

  static const int userId = 1; // 테스트용 고정 user_id

  /// 대시보드 데이터를 가져옵니다.
  /// 
  /// Returns:
  ///   - 성공 시: DashboardResponse 객체
  ///   - 실패 시: null
  static Future<DashboardResponse?> getDashboardData({
    int? year,
    int? month,
  }) async {
    try {
      // 쿼리 파라미터 구성
      final queryParams = <String, String>{
        'user_id': userId.toString(),
      };
      
      if (year != null) {
        queryParams['year'] = year.toString();
      }
      if (month != null) {
        queryParams['month'] = month.toString();
      }

      final uri = Uri.parse('$baseUrl/recommend/dashboard')
          .replace(queryParameters: queryParams);

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('요청 시간 초과');
            },
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print('Dashboard API Response: $data'); // 디버깅
        
        // 백엔드 응답 형식을 프론트엔드 모델 형식으로 변환
        final monthlySummary = data['monthly_summary'] as Map<String, dynamic>?;
        final habit = data['habit'] as Map<String, dynamic>?;
        
        print('Habit data: $habit'); // 디버깅
        print('Habit enabled: ${habit?['enabled']}'); // 디버깅
        
        // 백엔드에서 직접 받은 데이터를 그대로 DashboardResponse.fromJson에 전달
        // DashboardResponse.fromJson이 이미 'habit' 키를 처리하도록 수정되어 있음
        final transformedData = {
          'monthly_summary': monthlySummary,
          'habit': habit,
        };
        
        print('Transformed data for DashboardResponse: $transformedData'); // 디버깅
        print('Habit enabled check: ${habit?['enabled']}, type: ${habit?['enabled'].runtimeType}'); // 디버깅
        
        return DashboardResponse.fromJson(transformedData);
      } else {
        print('Dashboard API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Dashboard Service Error: $e');
      return null;
    }
  }
}

