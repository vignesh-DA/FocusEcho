import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../core/constants/app_constants.dart';
import '../local_db/database_helper.dart';
import '../local_db/distraction_event_dao.dart';
import '../local_db/focus_session_dao.dart';
import 'supabase_service.dart';
import 'sync_service.dart';

const nightlySyncTaskName = 'focus_echo_nightly_sync';

@pragma('vm:entry-point')
void nightlySyncCallbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task != nightlySyncTaskName) {
      return true;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final localOnly = prefs.getBool(AppKeys.localOnlyMode) ?? false;
      if (localOnly) return true; // Skip sync in local-only mode

      await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
      await DatabaseHelper.instance.getDatabase();

      final eventDao = DistractionEventDao(DatabaseHelper.instance);
      final sessionDao = FocusSessionDao(DatabaseHelper.instance);
      final supabaseService = SupabaseService();
      final syncService = SyncService(eventDao, sessionDao, supabaseService, prefs);

      await syncService.syncPendingEvents();
      return true;
    } catch (e) {
      debugPrint('Nightly sync failed: $e');
      return false; // Return false to trigger WorkManager retry
    }
  });
}

Future<void> initializeNightlySyncWorker() async {
  // ignore: deprecated_member_use
  await Workmanager().initialize(nightlySyncCallbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    nightlySyncTaskName,
    nightlySyncTaskName,
    frequency: const Duration(hours: 24),
    initialDelay: const Duration(hours: 3),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}
