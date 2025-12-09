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
    // Android인 경우 여러 URL 시도 (에뮬레이터와 실제 기기 모두 지원)
    List<String> urlsToTry = [baseUrl];
    if (!kIsWeb && Platform.isAndroid && ApiConfig.useEmulator == null) {
      // 자동 감지 모드: 에뮬레이터와 실제 기기 모두 시도
      urlsToTry = ApiConfig.getAndroidBaseUrls();
    }

    // 성능 최적화: 순차적으로 시도 (실제 기기에서는 10.0.2.2 타임아웃 시간 낭비 방지)
    // 첫 번째 URL부터 시도하고, 성공하면 즉시 반환
    print('[RoutineService] getAllRoutines 연결 시도 시작: ${urlsToTry.length}개 URL');
    for (int i = 0; i < urlsToTry.length; i++) {
      final url = urlsToTry[i];
      print('[RoutineService] getAllRoutines 시도 ${i + 1}/${urlsToTry.length}: $url');
      try {
        final uri = Uri.parse(
          '$url/routines',
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
              const Duration(seconds: 10), // 실제 기기에서는 빠른 실패로 다음 URL 시도
              onTimeout: () {
                throw Exception('요청 시간 초과');
              },
            );

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes)) as List;
          final result = data
              .map(
                (item) =>
                    ViewAllRoutineItem.fromJson(item as Map<String, dynamic>),
              )
              .toList();
          print('[RoutineService] getAllRoutines 성공: $url');
          return result;
        } else {
          // HTTP 에러
          print('[RoutineService] getAllRoutines HTTP 에러 ($url): ${response.statusCode}');
          continue;
        }
      } catch (e) {
        // 모든 URL 시도 실패 시 로그 출력
        print('[RoutineService] getAllRoutines 연결 실패 ($url): $e');
        if (i == urlsToTry.length - 1) {
          // 마지막 URL도 실패
          print('[RoutineService] getAllRoutines 모든 연결 시도 실패');
        }
        continue;
      }
    }

    // 모든 URL 시도 실패
    print('[RoutineService] getAllRoutines 최종 실패: 모든 URL 연결 시도 완료');
    return [];
  }

  /// 특정 날짜의 루틴 목록을 가져옵니다.
  ///
  /// [date] 조회할 날짜 (YYYY-MM-DD 형식)
  /// Returns: 루틴 목록 리스트
  static Future<List<RoutineItem>> getRoutinesByDate({
    required String date, // YYYY-MM-DD 형식
  }) async {
    // Android인 경우 여러 URL 시도 (에뮬레이터와 실제 기기 모두 지원)
    List<String> urlsToTry = [baseUrl];
    if (!kIsWeb && Platform.isAndroid && ApiConfig.useEmulator == null) {
      // 자동 감지 모드: 에뮬레이터와 실제 기기 모두 시도
      urlsToTry = ApiConfig.getAndroidBaseUrls();
    }

    // 성능 최적화: 순차적으로 시도 (실제 기기에서는 10.0.2.2 타임아웃 시간 낭비 방지)
    // 첫 번째 URL부터 시도하고, 성공하면 즉시 반환
    print('[RoutineService] getRoutinesByDate 연결 시도 시작: ${urlsToTry.length}개 URL');
    for (int i = 0; i < urlsToTry.length; i++) {
      final url = urlsToTry[i];
      print('[RoutineService] getRoutinesByDate 시도 ${i + 1}/${urlsToTry.length}: $url');
      try {
        final uri = Uri.parse('$url/recommend/today-routines').replace(
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
              const Duration(seconds: 10), // 실제 기기에서는 빠른 실패로 다음 URL 시도
              onTimeout: () {
                throw Exception('요청 시간 초과');
              },
            );

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes)) as List;
          final result = data
              .map((item) => RoutineItem.fromJson(item as Map<String, dynamic>))
              .toList();
          print('[RoutineService] getRoutinesByDate 성공: $url');
          return result;
        } else {
          // HTTP 에러
          print('[RoutineService] getRoutinesByDate HTTP 에러 ($url): ${response.statusCode}');
          continue;
        }
      } catch (e) {
        // 모든 URL 시도 실패 시 로그 출력
        print('[RoutineService] getRoutinesByDate 연결 실패 ($url): $e');
        if (i == urlsToTry.length - 1) {
          // 마지막 URL도 실패
          print('[RoutineService] getRoutinesByDate 모든 연결 시도 실패');
        }
        continue;
      }
    }

    // 모든 URL 시도 실패
    print('[RoutineService] getRoutinesByDate 최종 실패: 모든 URL 연결 시도 완료');
    return [];
  }

  /// 새 루틴을 생성합니다
  /// Returns: 생성된 루틴 정보
  static Future<Map<String, dynamic>?> createRoutine({
    required String name,
    required String scheduleType,
    String? preferredTime,
    int? runMinutes,
    String routineType = 'ETC',
  }) async {
    // Android인 경우 여러 URL 시도 (에뮬레이터와 실제 기기 모두 지원)
    List<String> urlsToTry = [baseUrl];
    if (!kIsWeb && Platform.isAndroid && ApiConfig.useEmulator == null) {
      // 자동 감지 모드: 에뮬레이터와 실제 기기 모두 시도
      urlsToTry = ApiConfig.getAndroidBaseUrls();
    }

    final body = jsonEncode({
      'user_id': userId,
      'name': name,
      'routine_type': routineType,
      'schedule_type': scheduleType,
      'preferred_time': preferredTime,
      'run_minutes': runMinutes,
    });

    for (final url in urlsToTry) {
      try {
        final uri = Uri.parse('$url/routines');

        print('[RoutineService] Create Routine 요청 시작: $uri');

        final response = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: body,
            )
            .timeout(
              const Duration(seconds: 120), // 실제 기기 네트워크 고려하여 120초로 증가
              onTimeout: () {
                print('[RoutineService] Create Routine 타임아웃 발생: $uri');
                throw Exception('요청 시간 초과 - 백엔드 서버가 실행 중인지 확인해주세요');
              },
            );

        if (response.statusCode == 201) {
          final data =
              jsonDecode(utf8.decode(response.bodyBytes))
                  as Map<String, dynamic>;
          print('[RoutineService] Create Routine 성공: $url');
          return data;
        } else {
          print(
            'Create Routine API Error: ${response.statusCode} - ${response.body}',
          );
          // 다음 URL 시도
          continue;
        }
      } catch (e, stackTrace) {
        print('[RoutineService] Create Routine $url 연결 실패');
        print('[RoutineService] 에러 타입: ${e.runtimeType}');
        print('[RoutineService] 에러 메시지: $e');
        print('[RoutineService] 스택 트레이스: $stackTrace');
        // 다음 URL 시도
        continue;
      }
    }

    // 모든 URL 시도 실패
    print('[RoutineService] Create Routine 모든 연결 시도 실패');
    return null;
  }

  /// 루틴을 실행합니다 (체크 표시 시 호출)
  /// Returns: 실행 성공 여부
  static Future<bool> executeRoutine({
    required int routineId,
    required int userId,
    int? runTime,
  }) async {
    // Android인 경우 여러 URL 시도 (에뮬레이터와 실제 기기 모두 지원)
    List<String> urlsToTry = [baseUrl];
    if (!kIsWeb && Platform.isAndroid && ApiConfig.useEmulator == null) {
      urlsToTry = ApiConfig.getAndroidBaseUrls();
    }

    final body = jsonEncode({
      'user_id': userId,
      'status': 2, // 2=done (완료)
      'run_time': runTime,
    });

    for (final url in urlsToTry) {
      try {
        final uri = Uri.parse('$url/recommend/routines/$routineId/execute');

        print('[RoutineService] Execute Routine 요청 시작: $uri');

        final response = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: body,
            )
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                print('[RoutineService] Execute Routine 타임아웃 발생: $uri');
                throw Exception('요청 시간 초과');
              },
            );

        if (response.statusCode == 200) {
          print('[RoutineService] Execute Routine 성공: $url');
          return true;
        } else {
          print(
            'Execute Routine API Error: ${response.statusCode} - ${response.body}',
          );
          continue;
        }
      } catch (e, stackTrace) {
        print('[RoutineService] Execute Routine $url 연결 실패');
        print('[RoutineService] 에러 타입: ${e.runtimeType}');
        print('[RoutineService] 에러 메시지: $e');
        print('[RoutineService] 스택 트레이스: $stackTrace');
        continue;
      }
    }

    // 모든 URL 시도 실패
    print('[RoutineService] Execute Routine 모든 연결 시도 실패');
    return false;
  }

  /// 루틴을 삭제합니다
  /// Returns: 삭제 성공 여부
  static Future<bool> deleteRoutine({
    required int routineId,
  }) async {
    // Android인 경우 여러 URL 시도 (에뮬레이터와 실제 기기 모두 지원)
    List<String> urlsToTry = [baseUrl];
    if (!kIsWeb && Platform.isAndroid && ApiConfig.useEmulator == null) {
      urlsToTry = ApiConfig.getAndroidBaseUrls();
    }

    for (final url in urlsToTry) {
      try {
        final uri = Uri.parse('$url/recommend/routines/$routineId');

        print('[RoutineService] Delete Routine 요청 시작: $uri');

        final response = await http
            .delete(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            )
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                print('[RoutineService] Delete Routine 타임아웃 발생: $uri');
                throw Exception('요청 시간 초과');
              },
            );

        if (response.statusCode == 200) {
          print('[RoutineService] Delete Routine 성공: $url');
          return true;
        } else {
          print(
            'Delete Routine API Error: ${response.statusCode} - ${response.body}',
          );
          continue;
        }
      } catch (e, stackTrace) {
        print('[RoutineService] Delete Routine $url 연결 실패');
        print('[RoutineService] 에러 타입: ${e.runtimeType}');
        print('[RoutineService] 에러 메시지: $e');
        print('[RoutineService] 스택 트레이스: $stackTrace');
        continue;
      }
    }

    // 모든 URL 시도 실패
    print('[RoutineService] Delete Routine 모든 연결 시도 실패');
    return false;
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
  final int scheduleFrequency; // 스케줄 빈도 (1=1회, 2=2회 등)

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
    this.scheduleFrequency = 1,
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
      scheduleFrequency: json['schedule_frequency'] as int? ?? 1,
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
              // WEEKLY/MONTHLY 루틴의 경우 요일 정보 추가
              if (scheduleType == 'WEEKLY' && preferredTime!.contains(':')) {
                final weekday = _getWeekdayDisplay();
                return '${hour.toString().padLeft(2, '0')}:$minute$weekday';
              }
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
      // 주간 루틴: 완료 횟수/목표 횟수 형식 (예: "2/4")
      final frequency = scheduleFrequency > 0 ? scheduleFrequency : 1;
      return '$completedCount/$frequency';
    } else if (scheduleType == 'MONTHLY') {
      // 월간 루틴: 완료 횟수/목표 횟수 형식 (예: "2/4")
      final frequency = scheduleFrequency > 0 ? scheduleFrequency : 1;
      return '$completedCount/$frequency';
    } else if (scheduleType == 'CUSTOM') {
      // 커스텀 스케줄의 경우 추가 정보가 필요할 수 있음
      return '2주 1회';
    }
    return scheduleType;
  }

  /// 요일 표시 문자열 반환 (WEEKLY 루틴용)
  String _getWeekdayDisplay() {
    if (createdAt == null) return '';
    try {
      final date = DateTime.parse(createdAt!);
      final weekdays = ['(월)', '(화)', '(수)', '(목)', '(금)', '(토)', '(일)'];
      return weekdays[date.weekday - 1];
    } catch (e) {
      return '';
    }
  }
}
