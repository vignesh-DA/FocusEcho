import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/providers/app_dependencies.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'local_db/database_helper.dart';
import 'local_db/distraction_event_dao.dart';
import 'local_db/focus_session_dao.dart';
import 'local_db/intervention_event_dao.dart';
import 'services/browser_monitor/browser_monitor.dart';
import 'services/fcm_service.dart';
import 'services/nightly_sync_worker.dart';
import 'services/supabase_service.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  var supabaseReady = false;
  try {
    await Supabase.initialize(
        url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
    supabaseReady = true;
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

  final sessionDao = FocusSessionDao(DatabaseHelper.instance);
  final eventDao = DistractionEventDao(DatabaseHelper.instance);
  final interventionDao = InterventionEventDao(DatabaseHelper.instance);
  final supabaseService = SupabaseService();
  final syncService = SyncService(
      eventDao, sessionDao, interventionDao, supabaseService, prefs);

  // Every online launch gets a real Supabase identity, including guests.
  // The local-only marker is retained only when Supabase is unreachable; it is
  // never used as a cloud identity or sent to Supabase.
  User? currentUser = supabaseReady ? Supabase.instance.client.auth.currentUser : null;
  if (supabaseReady && currentUser == null) {
    try {
      final response = await Supabase.instance.client.auth.signInAnonymously();
      currentUser = response.user;
      debugPrint('[Auth] Anonymous sign-in: ${currentUser?.id}');
    } catch (e) {
      debugPrint('[Auth] Anonymous sign-in failed: $e — using offline mode');
    }
  }
  final previousId = prefs.getString(AppKeys.userId);
  if (currentUser != null) {
    await prefs.setString(AppKeys.userId, currentUser.id);
    if (previousId != null && previousId != currentUser.id) {
      await _migrateLocalUserToAuthId(
          sessionDao, eventDao, previousId, currentUser.id);
    }
  } else {
    await prefs.setString(AppKeys.userId, 'local-user');
  }

  AppRouter.initialize(prefs);

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
  AppDependencies.interventionDao = interventionDao;
  AppDependencies.supabaseService = supabaseService;
  AppDependencies.syncService = syncService;
  AppDependencies.syncServiceReady = true;
  syncService.startPeriodicSync();

  if (kIsWeb) {
    BrowserMonitor.instance.syncCredentialsIfAvailable();
  }

  // Keep the local cache identity aligned with Supabase after OTP upgrades,
  // anonymous re-issuance, refreshes, and sign-outs.
  if (supabaseReady) {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final event = data.event;
    final user = data.session?.user;
    if ((event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.userUpdated ||
            event == AuthChangeEvent.tokenRefreshed) &&
        user != null) {
      final previousId = prefs.getString(AppKeys.userId);
      await prefs.setString(AppKeys.userId, user.id);
      if (previousId != null && previousId != user.id) {
        await _migrateLocalUserToAuthId(sessionDao, eventDao, previousId, user.id);
      }
      unawaited(syncService.syncPendingEvents());
      if (kIsWeb) {
        BrowserMonitor.instance.syncCredentialsIfAvailable();
      }
      debugPrint('[Auth] Identity set: ${user.email ?? 'anonymous'} (${user.id})');
    } else if (event == AuthChangeEvent.signedOut) {
      try {
        final response = await Supabase.instance.client.auth.signInAnonymously();
        final anonymousUser = response.user;
        if (anonymousUser != null) {
          await prefs.setString(AppKeys.userId, anonymousUser.id);
          if (kIsWeb) {
            BrowserMonitor.instance.syncCredentialsIfAvailable();
          }
          debugPrint('[Auth] Signed out — issued anonymous identity ${anonymousUser.id}');
        }
      } catch (e) {
        await prefs.setString(AppKeys.userId, 'local-user');
        debugPrint('[Auth] Anonymous re-issue failed: $e');
      }
    }
    });
  }

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

Future<void> _migrateLocalUserToAuthId(
  FocusSessionDao sessionDao,
  DistractionEventDao eventDao,
  String fromUserId,
  String authUserId,
) async {
  final sessions = await sessionDao.getSessionHistory(10000);
  final sessionIds = sessions.where((s) => s.userId == fromUserId).map((s) => s.id).toList();
  if (sessionIds.isEmpty) return;
  await sessionDao.reassignUserId(fromUserId, authUserId);
  await eventDao.markEventsUnsyncedForSessions(sessionIds);
}