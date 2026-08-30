import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/providers/app_dependencies.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'local_db/database_helper.dart';
import 'local_db/distraction_event_dao.dart';
import 'local_db/focus_session_dao.dart';
import 'services/fcm_service.dart';
import 'services/nightly_sync_worker.dart';
import 'services/supabase_service.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  try {
    await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
  } catch (e) {
    debugPrint('Supabase Init Failed: $e. Using offline mode.');
  }

  if (kIsWeb) {
    await DatabaseHelper.initWebStorage(prefs);
    // Pre-populate web-friendly app names on first run so Focus Session works immediately
    if ((prefs.getString(AppKeys.productiveApps) ?? '[]') == '[]') {
      await prefs.setString(
        AppKeys.productiveApps,
        '["Figma","VS Code","GitHub","Google Docs","Notion"]',
      );
    }
    if ((prefs.getString(AppKeys.distractingApps) ?? '[]') == '[]') {
      await prefs.setString(
        AppKeys.distractingApps,
        '["Instagram","Twitter","YouTube","Reddit","TikTok"]',
      );
    }
    if ((prefs.getString(AppKeys.webDistractingSites) ?? '[]') == '[]') {
      await prefs.setString(
        AppKeys.webDistractingSites,
        '["instagram.com","youtube.com","x.com","reddit.com","tiktok.com"]',
      );
    }
  } else {
    await DatabaseHelper.instance.getDatabase();
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  AppRouter.initialize(prefs);

  final sessionDao = FocusSessionDao(DatabaseHelper.instance);
  final eventDao = DistractionEventDao(DatabaseHelper.instance);
  final supabaseService = SupabaseService();
  final syncService = SyncService(eventDao, sessionDao, supabaseService, prefs);

  final deviceId = await _ensureDeviceId(prefs);
  final currentUser = Supabase.instance.client.auth.currentUser;
  if (currentUser == null) {
    await prefs.setString(AppKeys.userId, deviceId);
    await _migrateLocalUserToDeviceId(sessionDao, eventDao, deviceId);
  } else {
    await prefs.setString(AppKeys.userId, currentUser.id);
  }

  if (!kIsWeb) {
    try {
      final fcmService = FcmService(prefs);
      await fcmService.initialize();
      AppDependencies.fcmService = fcmService;
      AppDependencies.isFirebaseConfigured = true;
    } catch (e) {
      AppDependencies.isFirebaseConfigured = false;
      debugPrint('Firebase/FCM Init Failed: $e. Notifications disabled.');
    }
    await initializeNightlySyncWorker();
  }

  AppDependencies.prefs = prefs;
  AppDependencies.sessionDao = sessionDao;
  AppDependencies.eventDao = eventDao;
  AppDependencies.supabaseService = supabaseService;
  AppDependencies.syncService = syncService;
  syncService.startPeriodicSync();

  // Listen for OAuth deep-link callback (signedIn fires after browser redirect)
  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final event = data.event;
    final user = data.session?.user;
    if (event == AuthChangeEvent.signedIn && user != null) {
      final previousId = prefs.getString(AppKeys.userId) ?? prefs.getString(AppKeys.deviceId);
      // Persist the real userId so all screens pick it up
      await prefs.setString(AppKeys.userId, user.id);
      debugPrint('[Auth] Signed in as ${user.email} (${user.id})');
      // Migrate any pre-login local data to the real account
      if (previousId != null && previousId != user.id) {
        await syncService.migrateGuestDataToUser(previousId, user.id);
      }
    } else if (event == AuthChangeEvent.signedOut) {
      final fallbackDeviceId = await _ensureDeviceId(prefs);
      await prefs.setString(AppKeys.userId, fallbackDeviceId);
      debugPrint('[Auth] Signed out — reverted to device userId');
    }
  });

  runApp(
    const ProviderScope(child: FocusEchoApp()),
  );
}

class FocusEchoApp extends StatelessWidget {
  const FocusEchoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Focus Echo AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
    );
  }
}

Future<String> _ensureDeviceId(SharedPreferences prefs) async {
  final existing = prefs.getString(AppKeys.deviceId);
  if (existing != null && existing.isNotEmpty) return existing;
  final generated = const Uuid().v4();
  await prefs.setString(AppKeys.deviceId, generated);
  return generated;
}

Future<void> _migrateLocalUserToDeviceId(
  FocusSessionDao sessionDao,
  DistractionEventDao eventDao,
  String deviceId,
) async {
  const legacyId = 'local-user';
  final sessions = await sessionDao.getUnsyncedSessions();
  final legacySessionIds = sessions.where((s) => s.userId == legacyId).map((s) => s.id).toList();
  if (legacySessionIds.isEmpty) return;
  await sessionDao.reassignUserId(legacyId, deviceId);
  await eventDao.markEventsUnsyncedForSessions(legacySessionIds);
}
