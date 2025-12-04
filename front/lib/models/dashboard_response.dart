// models/dashboard_response.dart
class HabitInfo {
  final String name;
  final double progressRate;
  final int? remainingDays; // 남은 일수 추가

  HabitInfo({
    required this.name,
    required this.progressRate,
    this.remainingDays,
  });

  factory HabitInfo.fromJson(Map<String, dynamic> json) {
    // 백엔드는 'display_name'을 보냄, 'name'은 없을 수 있음
    final displayName = json['display_name'] as String? ?? json['name'] as String? ?? '';
    return HabitInfo(
      name: displayName,
      progressRate: (json['progress_rate'] as num?)?.toDouble() ?? 0.0,
      remainingDays: json['remaining_days'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'progress_rate': progressRate,
      'remaining_days': remainingDays,
    };
  }
}

class DashboardResponse {
  final double successRate;
  final int completedCount;
  final int failedCount;
  final int pendingCount;
  final HabitInfo? mainHabit;

  DashboardResponse({
    required this.successRate,
    required this.completedCount,
    required this.failedCount,
    required this.pendingCount,
    this.mainHabit,
  });

  factory DashboardResponse.fromJson(Map<String, dynamic> json) {
    // 백엔드는 'monthly_summary' 객체 안에 데이터를 보냄
    final monthlySummary = json['monthly_summary'] as Map<String, dynamic>?;
    // 백엔드는 'habit' 키를 사용 (not 'main_habit')
    final habitData = json['habit'] as Map<String, dynamic>?;
    
    return DashboardResponse(
      successRate: (monthlySummary?['success_rate'] as num?)?.toDouble() ?? 0.0,
      completedCount: monthlySummary?['completed_count'] as int? ?? 0,
      failedCount: monthlySummary?['failed_count'] as int? ?? 0,
      pendingCount: monthlySummary?['postponed_count'] as int? ?? 0,
      // 'enabled'가 true이고 데이터가 있을 때만 HabitInfo 생성
      mainHabit: (habitData != null && habitData['enabled'] == true)
          ? HabitInfo.fromJson(habitData)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success_rate': successRate,
      'completed_count': completedCount,
      'failed_count': failedCount,
      'pending_count': pendingCount,
      'main_habit': mainHabit?.toJson(),
    };
  }
}

