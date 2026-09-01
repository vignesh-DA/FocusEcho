import 'package:freezed_annotation/freezed_annotation.dart';

part 'distraction_event.freezed.dart';
part 'distraction_event.g.dart';

@freezed
class DistractionEvent with _$DistractionEvent {
  const factory DistractionEvent({
    required String id,
    required String sessionId,
    required String packageName,
    required String appLabel,
    required DateTime triggeredAt,
    DateTime? recoveredAt,
    int? recoveryTimeSeconds,
    required String riskScore,
    @Default('distraction') String eventType,
    String? appCategory,
    int? timeAwaySeconds,
    double? riskScoreNumeric,
    bool? wasNotificationTriggered,
    bool? returnedToOrigin,
    int? switchStackDepth,
    int? timeOfDayHour,
    int? dayOfWeek,
    int? sessionMinuteWhenOccurred,
    // Feature 2 — escalation ladder level (1 = heads-up, 2-3 = full-screen)
    // recorded at the time the event fired. Mirrors the Supabase column.
    @Default(1) int escalationLevel,
    @Default(false) bool isRecovered,
    @Default(false) bool isSynced,
  }) = _DistractionEvent;

  factory DistractionEvent.fromJson(Map<String, dynamic> json) => _$DistractionEventFromJson(json);

  const DistractionEvent._();

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'package_name': packageName,
      'app_label': appLabel,
      'triggered_at': triggeredAt.toIso8601String(),
      'recovered_at': recoveredAt?.toIso8601String(),
      'recovery_time_seconds': recoveryTimeSeconds,
      'risk_score': riskScore,
      'event_type': eventType,
      'app_category': appCategory,
      'time_away_seconds': timeAwaySeconds,
      'risk_score_numeric': riskScoreNumeric,
      'was_notification_triggered': wasNotificationTriggered == true ? 1 : 0,
      'returned_to_origin': returnedToOrigin == true ? 1 : 0,
      'switch_stack_depth': switchStackDepth,
      'time_of_day_hour': timeOfDayHour,
      'day_of_week': dayOfWeek,
      'session_minute_when_occurred': sessionMinuteWhenOccurred,
      'escalation_level': escalationLevel,
      'is_recovered': isRecovered ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  static DistractionEvent fromSqliteMap(Map<String, dynamic> map) {
    return DistractionEvent(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      packageName: map['package_name'] as String,
      appLabel: map['app_label'] as String,
      triggeredAt: DateTime.parse(map['triggered_at'] as String),
      recoveredAt: map['recovered_at'] == null ? null : DateTime.parse(map['recovered_at'] as String),
      recoveryTimeSeconds: map['recovery_time_seconds'] as int?,
      riskScore: map['risk_score'] as String,
      eventType: map['event_type'] as String? ?? 'distraction',
      appCategory: map['app_category'] as String?,
      timeAwaySeconds: map['time_away_seconds'] as int?,
      riskScoreNumeric: (map['risk_score_numeric'] as num?)?.toDouble(),
      wasNotificationTriggered: (map['was_notification_triggered'] as int?) == 1,
      returnedToOrigin: (map['returned_to_origin'] as int?) == 1,
      switchStackDepth: map['switch_stack_depth'] as int?,
      timeOfDayHour: map['time_of_day_hour'] as int?,
      dayOfWeek: map['day_of_week'] as int?,
      sessionMinuteWhenOccurred: map['session_minute_when_occurred'] as int?,
      escalationLevel: (map['escalation_level'] as int?) ?? 1,
      isRecovered: (map['is_recovered'] as int? ?? 0) == 1,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
    );
  }
}
