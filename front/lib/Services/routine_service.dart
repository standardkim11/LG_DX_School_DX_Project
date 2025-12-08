import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class RoutineService {
  static String get baseUrl {
    // config.dart에서 설정된 IP 주소 사용
    return ApiConfig.getBaseUrl(
      isWeb: kIsWeb,
      isAndroid: Platform.isAndroid,
      isIOS: Platform.isIOS,
    );
  }

  static const int userId = 1; // 테스트용 고정 user_id

  /// 전체 루틴 목록을 가져옵니다 (VIEW ALL 화면용)
  /// 집계 정보(완료 횟수 등)를 포함하여 반환
  /// Returns: 전체 루틴 목록 리스트
  static Future<List<ViewAllRoutineItem>> getAllRoutines() async {
    try {
      final uri = Uri.parse(
        '$baseUrl/routines',
      ).replace(queryParameters: {'user_id': userId.toString()});

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
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as List;
        return data
            .map(
              (item) =>
                  ViewAllRoutineItem.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      } else {
        print('Routine API Error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Routine Service Error: $e');
      return [];
    }
  }

  /// 특정 날짜의 루틴 목록을 가져옵니다.
  ///
  /// [date] 조회할 날짜 (YYYY-MM-DD 형식)
  /// Returns: 루틴 목록 리스트
  static Future<List<RoutineItem>> getRoutinesByDate({
    required String date, // YYYY-MM-DD 형식
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/recommend/today-routines').replace(
        queryParameters: {
          'user_id': userId.toString(),
          'date': date, // 날짜 파라미터 추가
        },
      );

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
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as List;
        return data
            .map((item) => RoutineItem.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        print('Routine API Error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Routine Service Error: $e');
      return [];
    }
  }

  /// 루틴을 생성합니다.
  ///
  /// [name] 루틴명
  /// [scheduleType] 스케줄 타입 (DAILY, WEEKLY, MONTHLY)
  /// [preferredTime] 선호 시간 (HH:MM 형식, 선택사항)
  /// [runMinutes] 목표 횟수
  /// [routineType] 루틴 타입 (CLEANING 등)
  /// Returns: 생성된 루틴 정보 또는 null (실패 시)
  static Future<Map<String, dynamic>?> createRoutine({
    required String name,
    required String scheduleType,
    String? preferredTime,
    required int runMinutes,
    required String routineType,
    List<String>? selectedDays,
  }) async {
    late final Uri uri;
    try {
      uri = Uri.parse('$baseUrl/routines');

      final requestBody = {
        'user_id': userId,
        'name': name,
        'schedule_type': scheduleType,
        'run_minutes': runMinutes,
        'routine_type': routineType,
      };

      if (preferredTime != null) {
        requestBody['preferred_time'] = preferredTime;
      }

      if (selectedDays != null && selectedDays.isNotEmpty) {
        requestBody['selected_days'] = selectedDays;
      }

      print('[RoutineService] HTTP POST 요청 시작: $uri');
      print('[RoutineService] Request Body: $requestBody');

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () {
              throw Exception('요청 시간 초과 - 백엔드 서버가 실행 중인지 확인해주세요');
            },
          );

      print('[RoutineService] HTTP 응답 수신 완료: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return data;
      } else {
        print(
          'Routine Create API Error: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } on SocketException catch (e) {
      final errorMessage =
          '네트워크 연결 오류: 백엔드 서버($baseUrl)에 연결할 수 없습니다.\n\n해결 방법:\n1. 백엔드 서버가 실행 중인지 확인 (back/Project/app.py)\n2. PC와 휴대폰이 같은 Wi-Fi에 연결되어 있는지 확인\n3. 방화벽에서 포트 8088을 허용했는지 확인\n4. 휴대폰 브라우저에서 http://192.168.0.34:8088/api/routines 접속 테스트\n\n오류 상세: $e';
      print('[RoutineService] SocketException 발생: $e');
      print('[RoutineService] 시도한 URL: $uri');
      print('[RoutineService] Base URL: $baseUrl');
      throw Exception(errorMessage);
    } catch (e) {
      print('Routine Create Service Error: $e');
      throw Exception('루틴 생성 중 오류가 발생했습니다: $e');
    }
  }
}

class RoutineItem {
  final int routineId;
  final String name;
  final String routineType;
  final String scheduleType;
  final String? preferredTime;
  final int runMinutes;
  final bool done;
  final bool failed;

  RoutineItem({
    required this.routineId,
    required this.name,
    required this.routineType,
    required this.scheduleType,
    this.preferredTime,
    required this.runMinutes,
    required this.done,
    required this.failed,
  });

  factory RoutineItem.fromJson(Map<String, dynamic> json) {
    return RoutineItem(
      routineId: json['routine_id'] as int,
      name: json['name'] as String,
      routineType: json['routine_type'] as String,
      scheduleType: json['schedule_type'] as String,
      preferredTime: json['preferred_time'] as String?,
      runMinutes: json['run_minutes'] as int? ?? 0,
      done: json['done'] as bool? ?? false,
      failed: json['failed'] as bool? ?? false,
    );
  }

  /// schedule_type을 UI 표시 형식으로 변환
  String getCategoryDisplay() {
    if (scheduleType == 'WEEKLY') {
      return '주 1회';
    } else if (scheduleType == 'DAILY') {
      if (preferredTime != null) {
        // "HH:MM" 형식을 "HH:MM까지 완료하기" 형식으로 변환
        try {
          final timeParts = preferredTime!.split(':');
          if (timeParts.length >= 2) {
            final hour = int.parse(timeParts[0]);
            final minute = timeParts[1];
            return '${hour.toString().padLeft(2, '0')}:$minute까지 완료하기';
          }
        } catch (e) {
          // 파싱 실패 시 그대로 반환
        }
      }
      return '매일';
    } else if (scheduleType == 'CUSTOM') {
      return '2주 1회';
    } else if (scheduleType == 'MONTHLY') {
      return '월 1회';
    }
    return scheduleType;
  }
}

/// VIEW ALL 화면용 루틴 아이템 (집계 정보 포함)
class ViewAllRoutineItem {
  final int id;
  final int userId;
  final String name;
  final String routineType;
  final int? runMinutes;
  final String scheduleType;
  final String? preferredTime;
  final bool isActive;
  final String? createdAt;
  final int completedCount; // 완료 횟수
  final bool isDoneToday; // 오늘 완료 여부

  ViewAllRoutineItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.routineType,
    this.runMinutes,
    required this.scheduleType,
    this.preferredTime,
    required this.isActive,
    this.createdAt,
    required this.completedCount,
    required this.isDoneToday,
  });

  factory ViewAllRoutineItem.fromJson(Map<String, dynamic> json) {
    return ViewAllRoutineItem(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      name: json['name'] as String,
      routineType: json['routine_type'] as String? ?? '',
      runMinutes: json['run_minutes'] as int?,
      scheduleType: json['schedule_type'] as String? ?? '',
      preferredTime: json['preferred_time'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] as String?,
      completedCount: json['completed_count'] as int? ?? 0,
      isDoneToday: json['is_done_today'] as bool? ?? false,
    );
  }

  /// schedule_type과 preferred_time을 UI 표시 형식으로 변환
  String getTimeDisplay() {
    if (scheduleType == 'DAILY') {
      if (preferredTime != null) {
        // 시간 형식 변환 (예: "MORNING" -> "8시까지 완료하기", "17:30" -> "17:30")
        if (preferredTime!.contains(':')) {
          // "HH:MM" 형식
          try {
            final timeParts = preferredTime!.split(':');
            if (timeParts.length >= 2) {
              final hour = int.parse(timeParts[0]);
              final minute = timeParts[1];
              return '${hour.toString().padLeft(2, '0')}:$minute';
            }
          } catch (e) {
            // 파싱 실패 시 그대로 반환
          }
          return preferredTime!;
        } else {
          // "MORNING", "EVENING" 등
          final timeMap = {
            'MORNING': '8시까지 완료하기',
            'AFTERNOON': '13:00',
            'EVENING': '19:00',
            'NIGHT': '21:00',
          };
          return timeMap[preferredTime!.toUpperCase()] ?? preferredTime!;
        }
      }
      return '매일';
    } else if (scheduleType == 'WEEKLY') {
      // 주간 루틴의 경우 요일 정보가 필요할 수 있음
      return '주 1회';
    } else if (scheduleType == 'CUSTOM') {
      // 커스텀 스케줄의 경우 추가 정보가 필요할 수 있음
      return '2주 1회';
    } else if (scheduleType == 'MONTHLY') {
      return '월 1회';
    }
    return scheduleType;
  }
}
