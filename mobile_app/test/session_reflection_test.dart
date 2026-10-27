import 'package:flutter_test/flutter_test.dart';

import 'package:focus_echo_ai/core/models/focus_session.dart';

void main() {
  test('session reflection serializes through the local row shape', () {
    final original = FocusSession(
      id: 'session-1',
      userId: 'user-1',
      startTime: DateTime.utc(2026, 10, 27, 10),
      productiveApp: 'VS Code',
      focusRating: 2,
      driftReason: 'tired',
    );

    final restored = FocusSession.fromSqliteMap(original.toSqliteMap());

    expect(restored.focusRating, 2);
    expect(restored.driftReason, 'tired');
  });

  test('reflection fields remain nullable when skipped', () {
    final session = FocusSession(
      id: 'session-2',
      userId: 'user-1',
      startTime: DateTime.utc(2026, 10, 27, 10),
      productiveApp: 'VS Code',
    );

    final restored = FocusSession.fromSqliteMap(session.toSqliteMap());

    expect(restored.focusRating, isNull);
    expect(restored.driftReason, isNull);
  });
}
