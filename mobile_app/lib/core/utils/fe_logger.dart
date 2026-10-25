/// @fileoverview FocusEcho structured logger — mirrors Python's logging module.
///
/// Usage:
///   FELog.i('Dashboard', 'Profile loaded: totalXp=225');
///   FELog.e('Analytics', 'Session query failed', e);
///
/// Log format:
///   [FE DEBUG] [Dashboard] 12:34:56.789 → Profile loaded: totalXp=225
///
/// Levels (ascending severity):
///   d → DEBUG   verbose step-by-step tracing
///   i → INFO    normal milestones (loaded, fetched, state updated)
///   w → WARN    degraded but recoverable (fallback to local, missing data)
///   e → ERROR   something failed (exception caught, query returned error)
///
/// Toggle verbosity at compile time with [FELog.level].
library;

import 'package:flutter/foundation.dart';

/// Minimum log level to emit. Lower severity lines are silently dropped.
/// Override in debug builds:  FELog.level = FELogLevel.debug;
enum FELogLevel { debug, info, warn, error }

class FELog {
  /// Change to [FELogLevel.info] for release builds to reduce noise.
  static FELogLevel level = kDebugMode ? FELogLevel.debug : FELogLevel.info;

  static const _reset  = '\x1B[0m';
  static const _grey   = '\x1B[90m';
  static const _cyan   = '\x1B[36m';
  static const _yellow = '\x1B[33m';
  static const _red    = '\x1B[31m';

  // ── Public API ─────────────────────────────────────────────────────────────

  /// DEBUG — granular step tracing (SQL row counts, branch decisions, etc.)
  static void d(String tag, String msg) =>
      _emit(FELogLevel.debug, '${_grey}DEBUG$_reset', tag, msg);

  /// INFO — normal milestones (loaded, fetched, state transitioned)
  static void i(String tag, String msg) =>
      _emit(FELogLevel.info, '${_cyan}INFO $_reset', tag, msg);

  /// WARN — degraded but recoverable (fallback path taken, null field, etc.)
  static void w(String tag, String msg) =>
      _emit(FELogLevel.warn, '${_yellow}WARN $_reset', tag, msg);

  /// ERROR — caught exception or unrecoverable failure
  static void e(String tag, String msg, [Object? error, StackTrace? st]) {
    final detail = error != null ? '\n  ↳ $error' : '';
    final trace  = st   != null ? '\n  ↳ ${st.toString().split('\n').take(4).join('\n  ')}' : '';
    _emit(FELogLevel.error, '${_red}ERROR$_reset', tag, '$msg$detail$trace');
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  static void _emit(FELogLevel lvl, String label, String tag, String msg) {
    if (lvl.index < level.index) return;
    final ts = _timestamp();
    debugPrint('[FE $label] [$tag] $ts → $msg');
  }

  static String _timestamp() {
    final n = DateTime.now();
    final h  = n.hour.toString().padLeft(2, '0');
    final m  = n.minute.toString().padLeft(2, '0');
    final s  = n.second.toString().padLeft(2, '0');
    final ms = n.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}
