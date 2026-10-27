import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:focus_echo_ai/local_db/database_helper.dart';

class _RecordingExecutor implements DatabaseExecutor {
  final statements = <String>[];

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    statements.add(sql);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('database v4 upgrade adds reflection and parking columns', () async {
    final executor = _RecordingExecutor();

    await DatabaseHelper.upgradeFocusSessionsBatchOne(executor);

    expect(executor.statements, [
      'ALTER TABLE focus_sessions ADD COLUMN focus_rating INTEGER',
      'ALTER TABLE focus_sessions ADD COLUMN drift_reason TEXT',
      'ALTER TABLE focus_sessions ADD COLUMN parked_items TEXT',
    ]);
  });
}
