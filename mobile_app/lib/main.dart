import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'features/focus_session/focus_session_viewmodel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/providers/app_dependencies.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/fe_logger.dart';
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
  if (AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
          url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
      supabaseReady = true;
    } catch (e, st) {
      FELog.e('Supabase', 'Supabase Init Failed: $e. Using offline mode.', e, st);
    }
  } else {
    FELog.e(
      'Config',
      'FATAL CONFIGURATION ERROR: SUPABASE_URL or SUPABASE_ANON_KEY is missing! '
      'The app was built without environment variables or dart_defines.json. '
      'Auth and sync operations will be unavailable.',
    );
  }

  if (kIsWeb) {
    await DatabaseHelper.initWebStorage(prefs);
    // Pre-populate web-friendly app names on first run so Focus Session works immediately
    final existingApps = prefs.getString(AppKeys.productiveApps) ?? '[]';
    if (existingApps == '[]' ||
        existingApps == '["Figma","VS Code","GitHub","Google Docs","Notion"]') {
      await prefs.setString(
        AppKeys.productiveApps,
        jsonEncode(FocusSessionViewModel.defaultProductiveApps),
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
  User? currentUser =
      supabaseReady ? Supabase.instance.client.auth.currentUser : null;
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

  // Shared account settings are the source of truth across web and APK;
  // SharedPreferences remains the offline cache on both platforms.
  await supabaseService.loadOrSeedFocusPreferences(prefs);

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

  if (kIsWeb && supabaseReady) {
    BrowserMonitor.instance.syncCredentialsIfAvailable();
  }

  // On native platforms, intercept the OAuth redirect URI that the OS delivers
  // after the user approves Google access in the system browser. The URI
  // (com.focusecho.ai://login-callback#access_token=...) is handed to
  // Supabase.getSessionFromUrl(), which stores the session tokens and fires
  // onAuthStateChange(signedIn). The existing listener below then saves the
  // user ID, syncs pending events, and calls AppRouter.refresh() — routing
  // the user to the next screen automatically (same flow as the browser
  // extension's OAuth redirect completion path).
  if (!kIsWeb && supabaseReady) {
    _initDeepLinkListener();
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
          await _migrateLocalUserToAuthId(
              sessionDao, eventDao, previousId, user.id);
        }
        unawaited(syncService.syncPendingEvents());
        if (kIsWeb) {
          BrowserMonitor.instance.syncCredentialsIfAvailable();
        }
        AppRouter.refresh();
        debugPrint(
            '[Auth] Identity set: ${user.email ?? 'anonymous'} (${user.id})');
      } else if (event == AuthChangeEvent.signedOut) {
        try {
          final response =
              await Supabase.instance.client.auth.signInAnonymously();
          final anonymousUser = response.user;
          if (anonymousUser != null) {
            await prefs.setString(AppKeys.userId, anonymousUser.id);
            if (kIsWeb) {
              BrowserMonitor.instance.syncCredentialsIfAvailable();
            }
            debugPrint(
                '[Auth] Signed out — issued anonymous identity ${anonymousUser.id}');
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
  final sessionIds =
      sessions.where((s) => s.userId == fromUserId).map((s) => s.id).toList();
  if (sessionIds.isEmpty) return;
  await sessionDao.reassignUserId(fromUserId, authUserId);
  await eventDao.markEventsUnsyncedForSessions(sessionIds);
}

// ---------------------------------------------------------------------------
// Native OAuth deep-link listener (Android + iOS)
// ---------------------------------------------------------------------------
/// Listens for the custom-scheme URI that the OS delivers after the browser
/// completes Google OAuth and redirects to com.focusecho.ai://login-callback.
///
/// Flow (mirrors the browser extension OAuth redirect):
///   1. LoginViewModel.signInWithGoogle() opens the system browser pointing
///      at Supabase's /authorize endpoint with redirectTo set to the custom
///      scheme URI.
///   2. After user approves, Google redirects the browser to the custom URI
///      with #access_token=...&refresh_token=... in the fragment.
///   3. Android (intent-filter in AndroidManifest.xml) / iOS (CFBundleURLSchemes
///      in Info.plist) intercepts the URI and resumes the app.
///   4. app_links delivers the URI to this listener.
///   5. We call Supabase.getSessionFromUrl() which parses the tokens, stores
///      the session, and fires onAuthStateChange(AuthChangeEvent.signedIn).
///   6. The existing listener in main() picks that up: saves user ID to prefs,
///      syncs pending events, and calls AppRouter.refresh() so GoRouter
///      re-evaluates the redirect guard and routes the user past the login
///      screen — exactly like the browser extension does after OAuth callback.
void _initDeepLinkListener() {
  final appLinks = AppLinks();

  // Handle URI if the app was launched cold by the deep link.
  appLinks.getInitialAppLink().then((uri) async {
    if (uri != null) {
      debugPrint('[OAuth] Cold-start deep link: $uri');
      await _handleOAuthRedirect(uri);
    }
  }).catchError((e) => debugPrint('[OAuth] getInitialAppLink error: $e'));

  // Handle URI while the app is already running (warm/hot start).
  appLinks.uriLinkStream.listen(
    (uri) async {
      debugPrint('[OAuth] Warm deep link: $uri');
      await _handleOAuthRedirect(uri);
    },
    onError: (e) => debugPrint('[OAuth] uriLinkStream error: $e'),
  );
}

Future<void> _handleOAuthRedirect(Uri uri) async {
  // Only act on our own scheme — ignore unrelated deep links.
  if (uri.scheme != 'com.focusecho.ai') return;
  debugPrint('[OAuth] Handling Supabase redirect: $uri');
  try {
    // Supabase v2: getSessionFromUrl parses the fragment and stores tokens.
    await Supabase.instance.client.auth.getSessionFromUrl(uri);
    // onAuthStateChange fires signedIn → AppRouter.refresh() is called from
    // the listener already registered in main() — no extra navigation needed.
  } catch (e) {
    debugPrint('[OAuth] getSessionFromUrl error: $e');
  }
}
