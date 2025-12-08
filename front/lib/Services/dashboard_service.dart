// services/dashboard_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/dashboard_response.dart';
import 'config.dart';

class DashboardService {
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
    // 쿼리 파라미터 구성
    final queryParams = <String, String>{'user_id': userId.toString()};

    if (year != null) {
      queryParams['year'] = year.toString();
    }
    if (month != null) {
      queryParams['month'] = month.toString();
    }

    // Android인 경우 여러 URL 시도 (에뮬레이터와 실제 기기 모두 지원)
    List<String> urlsToTry = [baseUrl];
    if (!kIsWeb && Platform.isAndroid && ApiConfig.useEmulator == null) {
      // 자동 감지 모드: 에뮬레이터와 실제 기기 모두 시도
      urlsToTry = ApiConfig.getAndroidBaseUrls();
    }

    Exception? lastException;
    for (final url in urlsToTry) {
      try {
        final uri = Uri.parse(
          '$url/recommend/dashboard',
        ).replace(queryParameters: queryParams);

        print('Dashboard API Request URL: $uri'); // 디버깅

        print('[DashboardService] HTTP GET 요청 시작: $uri');
        final stopwatch = Stopwatch()..start();

        final response = await http
            .get(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            )
            .timeout(
              const Duration(seconds: 30), // 각 URL당 30초 타임아웃
              onTimeout: () {
                stopwatch.stop();
                print(
                  '[DashboardService] 요청 타임아웃 (${stopwatch.elapsedMilliseconds}ms 소요) - $url',
                );
                throw Exception('요청 시간 초과 - 백엔드 서버가 실행 중인지 확인해주세요');
              },
            );

        stopwatch.stop();
        print(
          '[DashboardService] HTTP 응답 수신 완료 (${stopwatch.elapsedMilliseconds}ms 소요) - $url',
        );

        print('Dashboard API Response Status: ${response.statusCode}'); // 디버깅
        print('Dashboard API Response Headers: ${response.headers}'); // 디버깅

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          print('Dashboard API Response: $data'); // 디버깅

          // 백엔드 응답 형식을 프론트엔드 모델 형식으로 변환
          final monthlySummary =
              data['monthly_summary'] as Map<String, dynamic>?;
          final habit = data['habit'] as Map<String, dynamic>?;

          print('Habit data: $habit'); // 디버깅
          print('Habit enabled: ${habit?['enabled']}'); // 디버깅

          // 백엔드에서 직접 받은 데이터를 그대로 DashboardResponse.fromJson에 전달
          // DashboardResponse.fromJson이 이미 'habit' 키를 처리하도록 수정되어 있음
          final transformedData = {
            'monthly_summary': monthlySummary,
            'habit': habit,
          };

          print(
            'Transformed data for DashboardResponse: $transformedData',
          ); // 디버깅
          print(
            'Habit enabled check: ${habit?['enabled']}, type: ${habit?['enabled'].runtimeType}',
          ); // 디버깅

          try {
            return DashboardResponse.fromJson(transformedData);
          } catch (e, stackTrace) {
            print('DashboardResponse.fromJson Error: $e');
            print('Stack trace: $stackTrace');
            print('Failed to parse data: $transformedData');
            rethrow;
          }
        } else {
          print(
            'Dashboard API Error: ${response.statusCode} - ${response.body}',
          );
          // 다음 URL 시도
          lastException = Exception('HTTP ${response.statusCode}');
          continue;
        }
      } catch (e) {
        print('[DashboardService] $url 연결 실패: $e');
        lastException = e is Exception ? e : Exception(e.toString());
        // 다음 URL 시도
        continue;
      }
    }

    // 모든 URL 시도 실패
    final errorMessage = lastException != null
        ? '모든 연결 시도 실패: ${lastException.toString()}'
        : '모든 연결 시도 실패';
    print(errorMessage);
    throw Exception(errorMessage);
  }
}
