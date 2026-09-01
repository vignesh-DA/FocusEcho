import 'dart:async';

enum FocusState {
  focus,
  grace,
  transition,
  distraction,
  recovering,
}

enum FocusEventType {
  appSwitch,
  notification,
  screenOn,
  screenOff,
}

enum AppCategory {
  alwaysAllowed,
  allowedWithLimit,
  alwaysDistraction,
  neutral,
  unknown,
}

enum FocusActionType {
  distractionTriggered,
  intentionalSwitch,
  recovery,
}

class FocusSignal {
  FocusSignal({
    required this.type,
    required this.timestamp,
    this.packageName,
    this.appLabel,
    this.source,
    this.escalationLevel = 1,
  });

  final FocusEventType type;
  final DateTime timestamp;
  final String? packageName;
  final String? appLabel;
  final String? source;

  /// Feature 2 — escalation level attached by the native layer when the
  /// payload already ran through the relapse ladder (adb_fixture / usage_stats
  /// distractions). Defaults to 1 for signals without one.
  final int escalationLevel;
}

class FocusAction {
  FocusAction({required this.type, required this.payload});

  final FocusActionType type;
  final Map<String, dynamic> payload;
}

class FocusDetectionConfig {
  FocusDetectionConfig({
    required this.focusApp,
    required this.alwaysAllowedApps,
    required this.allowedWithLimitApps,
    required this.alwaysDistractionApps,
    required this.neutralApps,
    required this.timeLimitsSeconds,
    required this.gracePeriodMs,
    required this.transitionThresholdMs,
    required this.unknownThresholdMs,
    required this.notificationGraceMs,
    required this.screenOnGraceMs,
    required this.debounceMs,
  });

  final String focusApp;
  final Set<String> alwaysAllowedApps;
  final Set<String> allowedWithLimitApps;
  final Set<String> alwaysDistractionApps;
  final Set<String> neutralApps;
  final Map<String, int> timeLimitsSeconds;
  final int gracePeriodMs;
  final int transitionThresholdMs;
  final int unknownThresholdMs;
  final int notificationGraceMs;
  final int screenOnGraceMs;
  final int debounceMs;
}

class FocusDetectionEngine {
  FocusState _state = FocusState.focus;
  FocusDetectionConfig? _config;
  Future<void> Function(FocusAction action)? _onAction;

  String? _currentPackage;
  String? _currentLabel;
  String? _transitionPackage;
  String? _transitionLabel;
  DateTime? _switchedAwayAt;
  DateTime? _lastSwitchTime;
  DateTime? _lastNotificationTime;
  String? _lastNotificationPackage;
  DateTime? _screenOnGraceUntil;
  bool _paused = false;
  int _switchStackDepth = 0;
  int _lastEscalationLevel = 1;
  final Map<String, DateTime> _snoozedApps = {};

  Timer? _graceTimer;
  Timer? _transitionTimer;

  FocusState get state => _state;

  void setActionHandler(Future<void> Function(FocusAction action) handler) {
    _onAction = handler;
  }

  void configure(FocusDetectionConfig config) {
    _config = config;
  }

  void reset() {
    _state = FocusState.focus;
    _currentPackage = null;
    _currentLabel = null;
    _transitionPackage = null;
    _transitionLabel = null;
    _switchedAwayAt = null;
    _lastSwitchTime = null;
    _lastNotificationTime = null;
    _lastNotificationPackage = null;
    _screenOnGraceUntil = null;
    _paused = false;
    _switchStackDepth = 0;
    _lastEscalationLevel = 1;
    _snoozedApps.clear();
    _graceTimer?.cancel();
    _transitionTimer?.cancel();
  }

  void snooze(String packageName, int durationMinutes) {
    _snoozedApps[packageName] = DateTime.now().add(Duration(minutes: durationMinutes));
    _state = FocusState.focus; // Treat as focused/safe during snooze
    _graceTimer?.cancel();
    _transitionTimer?.cancel();
  }

  List<FocusAction> handleSignal(FocusSignal signal) {
    if (_config == null) return const [];

    switch (signal.type) {
      case FocusEventType.notification:
        _lastNotificationTime = signal.timestamp;
        _lastNotificationPackage = signal.packageName;
        return const [];
      case FocusEventType.screenOff:
        _paused = true;
        _graceTimer?.cancel();
        _transitionTimer?.cancel();
        _state = FocusState.focus;
        return const [];
      case FocusEventType.screenOn:
        _paused = false;
        _screenOnGraceUntil = signal.timestamp.add(
          Duration(milliseconds: _config!.screenOnGraceMs),
        );
        return const [];
      case FocusEventType.appSwitch:
        return _handleAppSwitch(signal);
    }
  }

  List<FocusAction> _handleAppSwitch(FocusSignal signal) {
    final config = _config!;
    if (_paused) return const [];
    if (signal.packageName == null) return const [];

    final now = signal.timestamp;
    if (_lastSwitchTime != null &&
        now.difference(_lastSwitchTime!).inMilliseconds < config.debounceMs) {
      return const [];
    }

    final packageName = signal.packageName!;
    if (_currentPackage == packageName) return const [];

    _lastSwitchTime = now;
    _currentPackage = packageName;
    _currentLabel = signal.appLabel ?? packageName;
    _lastEscalationLevel = signal.escalationLevel;

    if (packageName == config.focusApp) {
      return _handleReturnToFocus(now);
    }

    _transitionLabel = signal.appLabel ?? packageName;

    if (_screenOnGraceUntil != null && now.isBefore(_screenOnGraceUntil!)) {
      _enterGrace(packageName, now);
      return const [];
    }

    final category = _classify(packageName);

    if (category == AppCategory.neutral) {
      _enterGrace(packageName, now);
      return const [];
    }

    if (_switchedAwayAt == null) {
      _switchedAwayAt = now;
      _switchStackDepth = 1;
    } else {
      _switchStackDepth += 1;
    }

    if (category == AppCategory.alwaysDistraction) {
      _state = FocusState.distraction;
      _transitionPackage = packageName;
      _graceTimer?.cancel();
      _transitionTimer?.cancel();
      return [
        FocusAction(
          type: FocusActionType.distractionTriggered,
          payload: _buildPayload(packageName, category, now),
        ),
      ];
    }

    if (category == AppCategory.alwaysAllowed) {
      _state = FocusState.transition;
      _transitionPackage = packageName;
      _graceTimer?.cancel();
      _transitionTimer?.cancel();
      return const [];
    }

    final thresholdMs = _thresholdFor(packageName, category);
    _state = FocusState.transition;
    _transitionPackage = packageName;

    _transitionTimer?.cancel();
    _transitionTimer = Timer(Duration(milliseconds: thresholdMs), () {
      if (_currentPackage == _transitionPackage && _state != FocusState.focus) {
        _state = FocusState.distraction;
        final action = FocusAction(
          type: FocusActionType.distractionTriggered,
          payload: _buildPayload(packageName, category, DateTime.now()),
        );
        final handler = _onAction;
        if (handler != null) {
          unawaited(handler(action));
        }
      }
    });

    return const [];
  }

  List<FocusAction> _handleReturnToFocus(DateTime now) {
    final config = _config!;
    _graceTimer?.cancel();
    _transitionTimer?.cancel();

    final switchedAwayAt = _switchedAwayAt;
    final transitionPackage = _transitionPackage;
    final timeAwaySeconds = switchedAwayAt == null
        ? 0
        : now.difference(switchedAwayAt).inSeconds;

    final actions = <FocusAction>[];

    if (switchedAwayAt != null && timeAwaySeconds <= (config.gracePeriodMs ~/ 1000)) {
      _state = FocusState.focus;
    } else if (transitionPackage != null) {
      final category = _classify(transitionPackage);
      final thresholdMs = _thresholdFor(transitionPackage, category);
      if (category == AppCategory.alwaysAllowed || category == AppCategory.neutral) {
        _state = FocusState.focus;
        actions.add(
          FocusAction(
            type: FocusActionType.intentionalSwitch,
            payload: _buildPayload(transitionPackage, category, now),
          ),
        );
      } else if (timeAwaySeconds * 1000 < thresholdMs) {
        _state = FocusState.focus;
        actions.add(
          FocusAction(
            type: FocusActionType.intentionalSwitch,
            payload: _buildPayload(transitionPackage, category, now),
          ),
        );
      } else {
        _state = FocusState.recovering;
        actions.add(
          FocusAction(
            type: FocusActionType.recovery,
            payload: {
              'timeAwaySeconds': timeAwaySeconds,
              'returnedToOrigin': true,
            },
          ),
        );
      }
    }

    _switchedAwayAt = null;
    _transitionPackage = null;
    _transitionLabel = null;
    _switchStackDepth = 0;
    return actions;
  }

  void _enterGrace(String packageName, DateTime now) {
    final config = _config!;
    _state = FocusState.grace;
    _transitionPackage = packageName;
    _transitionLabel = _currentLabel ?? packageName;
    _graceTimer?.cancel();
    _graceTimer = Timer(Duration(milliseconds: config.gracePeriodMs), () {
      if (_currentPackage == _transitionPackage && _state == FocusState.grace) {
        _state = FocusState.transition;
      }
    });
  }

  int _thresholdFor(String packageName, AppCategory category) {
    final config = _config!;
    if (_isNotificationTriggered(packageName)) {
      return config.notificationGraceMs;
    }
    if (config.timeLimitsSeconds.containsKey(packageName)) {
      return config.timeLimitsSeconds[packageName]! * 1000;
    }
    if (category == AppCategory.allowedWithLimit) {
      return config.transitionThresholdMs;
    }
    if (category == AppCategory.unknown) {
      return config.unknownThresholdMs;
    }
    return config.transitionThresholdMs;
  }

  bool _isNotificationTriggered(String packageName) {
    final config = _config!;
    if (_lastNotificationPackage != packageName || _lastNotificationTime == null) {
      return false;
    }
    final deltaMs = DateTime.now().difference(_lastNotificationTime!).inMilliseconds;
    return deltaMs <= config.notificationGraceMs;
  }

  AppCategory _classify(String packageName) {
    final config = _config!;

    if (_snoozedApps.containsKey(packageName)) {
      final until = _snoozedApps[packageName]!;
      if (DateTime.now().isBefore(until)) return AppCategory.alwaysAllowed;
      _snoozedApps.remove(packageName);
    }

    if (_matchesAny(config.alwaysDistractionApps, packageName)) {
      return AppCategory.alwaysDistraction;
    }
    if (_matchesAny(config.alwaysAllowedApps, packageName)) return AppCategory.alwaysAllowed;
    if (_matchesAny(config.allowedWithLimitApps, packageName)) return AppCategory.allowedWithLimit;
    if (_matchesAny(config.neutralApps, packageName)) return AppCategory.neutral;
    return AppCategory.unknown;
  }

  bool _matchesAny(Set<String> patterns, String packageName) {
    for (final pattern in patterns) {
      if (pattern.endsWith('.*')) {
        final prefix = pattern.substring(0, pattern.length - 2);
        if (packageName.startsWith(prefix)) return true;
      } else if (pattern == packageName) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic> _buildPayload(String packageName, AppCategory category, DateTime now) {
    final config = _config!;
    final switchedAwayAt = _switchedAwayAt ?? now;
    final timeAwaySeconds = now.difference(switchedAwayAt).inSeconds;
    return {
      'packageName': packageName,
      'appLabel': _transitionLabel ?? _currentLabel ?? packageName,
      'category': category,
      'timeAwaySeconds': timeAwaySeconds,
      'wasNotificationTriggered': _isNotificationTriggered(packageName),
      'returnedToOrigin': _currentPackage == config.focusApp,
      'switchStackDepth': _switchStackDepth,
      'escalation_level': _lastEscalationLevel,
      'timestamp': now,
    };
  }
}
