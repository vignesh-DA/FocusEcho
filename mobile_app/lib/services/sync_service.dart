import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local_db/distraction_event_dao.dart';
import '../local_db/focus_session_dao.dart';
import 'supabase_service.dart';

class SyncResult {
  const SyncResult({
    required this.synced,
    required this.failed,
    required this.skipped,
    required this.noConnection,
  });

  final int synced;
  final int failed;
  final int skipped;
  final bool noConnection;

  factory SyncResult.noConnection() =>
      const SyncResult(synced: 0, failed: 0, skipped: 0, noConnection: true);
}

class SyncService {
  SyncService(this._eventDao, this._sessionDao, this._supabaseService);

  final DistractionEventDao _eventDao;
  final FocusSessionDao _sessionDao;
  final SupabaseService _supabaseService;
  Timer? _timer;

  static const int _maxRetries = 3;

  Future<SyncResult> syncPendingEvents() async {
    try {
      if (_supabaseService.currentUser == null) {
        return const SyncResult(synced: 0, failed: 0, skipped: 0, noConnection: false);
      }
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        return SyncResult.noConnection();
      }

      var synced = 0;
      var failed = 0;

      final events = await _eventDao.getUnsyncedEvents();
      for (final event in events) {
        final success = await _retryWithBackoff(() async {
          await _supabaseService.upsertDistractionEvent(event);
          await _eventDao.markAsSynced(event.id);
        });
        if (success) {
          synced++;
        } else {
          failed++;
        }
      }

      final sessions = await _sessionDao.getUnsyncedSessions();
      for (final session in sessions) {
        final success = await _retryWithBackoff(() async {
          await _supabaseService.upsertFocusSession(session);
          await _sessionDao.markAsSynced(session.id);
        });
        if (success) {
          synced++;
        } else {
          failed++;
        }
      }

      return SyncResult(
        synced: synced,
        failed: failed,
        skipped: 0,
        noConnection: false,
      );
    } on SocketException {
      return SyncResult.noConnection();
    } on TimeoutException {
      return SyncResult.noConnection();
    } catch (_) {
      return SyncResult.noConnection();
    }
  }

  /// Called after a user signs in. Re-assigns all guest data to the real
  /// Supabase UUID in SQLite, then triggers an immediate sync.
  Future<void> migrateGuestDataToUser(String fromUserId, String realUserId) async {

    // 1. Find sessions that belong to the guest ID before reassigning
    final guestSessions = await _sessionDao.getUnsyncedSessions();
    final guestSessionIds = guestSessions
      .where((s) => s.userId == fromUserId)
        .map((s) => s.id)
        .toList();

    // 2. Re-assign session user_id to the real UUID
    if (guestSessionIds.isNotEmpty) {
      await _sessionDao.reassignUserId(fromUserId, realUserId);
      // 3. Also reset sync flag on their events
      await _eventDao.markEventsUnsyncedForSessions(guestSessionIds);
    }

    debugPrint(
      '[SyncService] Migrated ${guestSessionIds.length} guest session(s) to user $realUserId',
    );

    // 4. Immediately push everything to Supabase
    await syncPendingEvents();
  }

  /// Retry [operation] up to [_maxRetries] times with exponential backoff.
  Future<bool> _retryWithBackoff(Future<void> Function() operation) async {
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        await operation();
        return true;
      } on SocketException {
        return false; // No point retrying without network
      } on TimeoutException {
        return false;
      } on PostgrestException catch (e) {
        debugPrint('Supabase sync error (attempt ${attempt + 1}): ${e.message}');
        if (attempt == _maxRetries - 1) return false;
        await Future<void>.delayed(Duration(milliseconds: 500 * pow(2, attempt).toInt()));
      } on AuthException catch (e) {
        debugPrint('Auth error during sync: ${e.message}');
        return false; // Auth errors won't resolve with retry
      }
    }
    return false;
  }

  void startPeriodicSync() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) {
      unawaited(syncPendingEvents());
    });
  }

  void stopPeriodicSync() {
    _timer?.cancel();
    _timer = null;
  }
}
