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

    // 성능 최적화: 순차적으로 시도 (실제 기기에서는 10.0.2.2 타임아웃 시간 낭비 방지)
    // 첫 번째 URL부터 시도하고, 성공하면 즉시 반환
    print('[DashboardService] 연결 시도 시작: ${urlsToTry.length}개 URL');
    for (int i = 0; i < urlsToTry.length; i++) {
      final url = urlsToTry[i];
      print('[DashboardService] 시도 ${i + 1}/${urlsToTry.length}: $url');
      try {
        final uri = Uri.parse(
          '$url/recommend/dashboard',
        ).replace(queryParameters: queryParams);

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
              const Duration(seconds: 10), // 실제 기기에서는 빠른 실패로 다음 URL 시도
              onTimeout: () {
                stopwatch.stop();
                throw Exception('요청 시간 초과');
              },
            );

        stopwatch.stop();

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));

          // 백엔드 응답 형식을 프론트엔드 모델 형식으로 변환
          final monthlySummary =
              data['monthly_summary'] as Map<String, dynamic>?;
          final habit = data['habit'] as Map<String, dynamic>?;

          final transformedData = {
            'monthly_summary': monthlySummary,
            'habit': habit,
          };

          try {
            final result = DashboardResponse.fromJson(transformedData);
            print(
              '[DashboardService] 성공: $url (${stopwatch.elapsedMilliseconds}ms 소요)',
            );
            return result;
          } catch (e, stackTrace) {
            print('[DashboardService] JSON 파싱 에러 ($url): $e');
            print('[DashboardService] Stack trace: $stackTrace');
            print('[DashboardService] Failed to parse data: $transformedData');
            // 다음 URL 시도 계속
            continue;
          }
        } else {
          // HTTP 에러
          print('[DashboardService] HTTP 에러 ($url): ${response.statusCode}');
          continue;
        }
      } catch (e) {
        // 모든 URL 시도 실패 시 로그 출력
        print('[DashboardService] 연결 실패 ($url): $e');
        if (i == urlsToTry.length - 1) {
          // 마지막 URL도 실패
          print('[DashboardService] 모든 URL 연결 시도 실패');
        }
        continue;
      }
    }

    // 모든 URL 시도 실패 시 에러 던지기
    print('[DashboardService] 최종 실패: 모든 URL 연결 시도 완료');
    throw Exception('모든 연결 시도 실패 - 백엔드 서버가 실행 중인지 확인해주세요');
  }
}
