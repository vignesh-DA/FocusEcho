import 'package:flutter_test/flutter_test.dart';
import 'package:focus_echo_ai/services/focus_preferences_conflict.dart';

void main() {
  group('focus preference conflict rule', () {
    final remote = DateTime.utc(2026, 10, 27, 12);

    test('a newer offline local settings edit wins on reconnect', () {
      expect(
        resolveFocusPreferenceConflict(
          localUpdatedAt: remote.add(const Duration(seconds: 1)),
          remoteUpdatedAt: remote,
        ),
        FocusPreferenceWinner.local,
      );
    });

    test('a newer server edit wins over a stale device cache', () {
      expect(
        resolveFocusPreferenceConflict(
          localUpdatedAt: remote.subtract(const Duration(seconds: 1)),
          remoteUpdatedAt: remote,
        ),
        FocusPreferenceWinner.remote,
      );
    });

    test('equal timestamps resolve to the server copy', () {
      expect(
        resolveFocusPreferenceConflict(
          localUpdatedAt: remote,
          remoteUpdatedAt: remote,
        ),
        FocusPreferenceWinner.remote,
      );
    });

    test('a web session gets a copy of the saved site list', () {
      final savedSites = ['youtube.com', 'reddit.com'];
      final sessionSites = createSessionSiteSnapshot(savedSites);

      sessionSites.remove('youtube.com');

      expect(savedSites, ['youtube.com', 'reddit.com']);
      expect(sessionSites, ['reddit.com']);
    });
  });
}
