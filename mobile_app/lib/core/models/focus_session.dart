import 'package:freezed_annotation/freezed_annotation.dart';
import 'dart:convert';

part 'focus_session.freezed.dart';
part 'focus_session.g.dart';

enum SessionStatus { active, completed, abandoned }

@freezed
class FocusSession with _$FocusSession {
  const factory FocusSession({
    required String id,
    required String userId,
    required DateTime startTime,
    DateTime? endTime,
    required String productiveApp,
    @Default('') String intent,
    @Default(0) int totalDistractions,
    @Default(0) int totalXpEarned,
    @Default(0) double focusScore,
    @Default(SessionStatus.active) SessionStatus status,
    @Default(false) bool isSynced,
    int? focusRating,
    String? driftReason,
    List<String>? parkedItems,
  }) = _FocusSession;

  factory FocusSession.fromJson(Map<String, dynamic> json) =>
      _$FocusSessionFromJson(json);

  const FocusSession._();

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'user_id': userId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'productive_app': productiveApp,
      'intent': intent,
      'total_distractions': totalDistractions,
      'total_xp_earned': totalXpEarned,
      'focus_score': focusScore,
      'status': status.name,
      'is_synced': isSynced ? 1 : 0,
      'focus_rating': focusRating,
      'drift_reason': driftReason,
      'parked_items': parkedItems == null ? null : jsonEncode(parkedItems),
    };
  }

  static FocusSession fromSqliteMap(Map<String, dynamic> map) {
    return FocusSession(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: map['end_time'] == null
          ? null
          : DateTime.parse(map['end_time'] as String),
      productiveApp: map['productive_app'] as String,
      intent: map['intent'] as String? ?? '',
      totalDistractions: map['total_distractions'] as int? ?? 0,
      totalXpEarned: map['total_xp_earned'] as int? ?? 0,
      focusScore: (map['focus_score'] as num?)?.toDouble() ?? 0,
      status: SessionStatus.values.firstWhere(
        (v) =>
            v.name == (map['status'] as String? ?? SessionStatus.active.name),
      ),
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      focusRating: (map['focus_rating'] as num?)?.toInt(),
      driftReason: map['drift_reason'] as String?,
      parkedItems: _decodeParkedItems(map['parked_items']),
    );
  }

  static List<String>? _decodeParkedItems(dynamic raw) {
    if (raw is List) return raw.whereType<String>().toList();
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.whereType<String>().toList();
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
