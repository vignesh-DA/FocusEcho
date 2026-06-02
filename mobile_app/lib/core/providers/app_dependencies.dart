import 'package:shared_preferences/shared_preferences.dart';

import '../../local_db/distraction_event_dao.dart';
import '../../local_db/focus_session_dao.dart';
import '../../services/fcm_service.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';

class AppDependencies {
  AppDependencies._();

  static late SharedPreferences prefs;
  static late FocusSessionDao sessionDao;
  static late DistractionEventDao eventDao;
  static late SupabaseService supabaseService;
  static late SyncService syncService;
  static FcmService? fcmService;
  static bool isFirebaseConfigured = false;
}
