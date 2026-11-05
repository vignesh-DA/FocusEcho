import 'package:flutter_test/flutter_test.dart';
import 'package:focus_echo_ai/core/constants/app_constants.dart';
import 'package:focus_echo_ai/services/focus_preferences_conflict.dart';

void main() {
  group('Focus preference conflict and session snapshot behavior', () {
    final now = DateTime.utc(2026, 11, 2, 14);

    test('Newer local preference edit wins', () {
      expect(
        resolveFocusPreferenceConflict(
          localUpdatedAt: now.add(const Duration(seconds: 10)),
          remoteUpdatedAt: now,
        ),
        FocusPreferenceWinner.local,
      );
    });

    test('Newer remote preference edit wins', () {
      expect(
        resolveFocusPreferenceConflict(
          localUpdatedAt: now.subtract(const Duration(seconds: 10)),
          remoteUpdatedAt: now,
        ),
        FocusPreferenceWinner.remote,
      );
    });

    test('Equal timestamps favor remote server truth', () {
      expect(
        resolveFocusPreferenceConflict(
          localUpdatedAt: now,
          remoteUpdatedAt: now,
        ),
        FocusPreferenceWinner.remote,
      );
    });

    test('Session site snapshot is an independent clone', () {
      final original = ['youtube.com', 'twitter.com', 'reddit.com'];
      final snapshot = createSessionSiteSnapshot(original);
      snapshot.add('tiktok.com');
      expect(original.length, 3);
      expect(snapshot.length, 4);
    });

    test('Empty saved site list creates empty snapshot', () {
      final snapshot = createSessionSiteSnapshot([]);
      expect(snapshot.isEmpty, true);
    });

    test('Editing session snapshot leaves saved list unchanged', () {
      final original = ['instagram.com'];
      final snapshot = createSessionSiteSnapshot(original);
      snapshot.clear();
      expect(original.isNotEmpty, true);
      expect(snapshot.isEmpty, true);
    });

  });
}
