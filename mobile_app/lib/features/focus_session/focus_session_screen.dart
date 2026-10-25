import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../distraction_alert/distraction_alert_modal.dart';
import '../distraction_alert/intervention_overlay.dart';
import 'focus_session_state.dart';
import 'focus_session_viewmodel.dart';
import 'session_summary_screen.dart';
import 'widgets/live_distraction_feed.dart';

class FocusSessionScreen extends ConsumerWidget {
  const FocusSessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(focusSessionProvider);
    final vm = ref.read(focusSessionProvider.notifier);

    // Feature 2 — level-1 relapses keep the existing heads-up modal.
    ref.listen(focusSessionProvider, (previous, next) {
      final wasAlerting = previous?.showAlert ?? false;
      if (!wasAlerting &&
          next.showAlert &&
          next.lastEventId != null &&
          next.escalationLevel <= 1) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => DistractionAlertModal(
            appName: next.lastDistractionLabel ??
                next.lastDistractionPackage ??
                'Unknown app',
            packageName: next.lastDistractionPackage ?? 'unknown',
            riskScore: next.currentRiskScore,
            onRecovery: () => vm.onRecovery(next.lastEventId!),
            onEndSession: vm.stopSession,
            onSnooze: () => vm.snoozeApp(next.lastDistractionPackage!),
            onStreakPenalty: vm.dismissAlert,
          ),
        );
      }
    });

    // Feature 4 — lightweight cross-surface nudge (non-blocking).
    ref.listen(focusSessionProvider, (previous, next) {
      final nudge = next.crossSurfaceNudge;
      if (nudge != null && nudge != (previous?.crossSurfaceNudge)) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.devices_other,
                      size: 18, color: AppColors.accentYellow),
                  const SizedBox(width: 8),
                  Expanded(child: Text(nudge)),
                ],
              ),
              backgroundColor: AppColors.card,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        vm.clearCrossSurfaceNudge();
      }
    });

    // Feature 1 — session-complete summary view.
    if (!state.isActive && state.sessionSummary != null) {
      return SessionSummaryScreen(
        summary: state.sessionSummary!,
        stats: state.sessionSummaryStats,
        onDismiss: vm.dismissSummary,
      );
    }

    if (!state.isActive) {
      return _SessionSetupView(state: state, vm: vm);
    }

    final elapsed = Duration(seconds: state.elapsedSeconds);
    final timer =
        '${elapsed.inHours.toString().padLeft(2, '0')}:${(elapsed.inMinutes % 60).toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';

    // Feature 2 — level 2+ renders as a full-screen intervention state.
    final showFullScreenIntervention =
        state.showAlert && state.escalationLevel >= 2;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Bug 2 fix — FittedBox prevents the HH:MM:SS string from
                  // overflowing at narrow/mobile viewport widths.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      timer,
                      style: AppTextStyles.displayLarge
                          .copyWith(color: AppColors.accentGreen),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.98, end: 1.02),
                    duration: const Duration(seconds: 2),
                    curve: Curves.easeInOut,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    onEnd: () {},
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: AppDecorations.glassmorphismCard(),
                      child: Column(
                        children: [
                          const Icon(Icons.apps_rounded, size: 48),
                          Text(state.session?.productiveApp ?? 'App',
                              style: AppTextStyles.displayMedium),
                          if (state.session?.intent.trim().isNotEmpty ??
                              false) ...[
                            const SizedBox(height: 6),
                            Text(
                              '"${state.session!.intent.trim()}"',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.accentBlue,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Bug 2 fix — Flexible prevents right-edge clipping when
                      // the distraction count label grows long at small widths.
                      Flexible(
                        child: Text(
                          'Distractions: ${state.distractionCount}',
                          style: AppTextStyles.bodyLarge
                              .copyWith(color: AppColors.accentRed),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'XP: ${state.sessionXp}',
                          style: AppTextStyles.bodyLarge
                              .copyWith(color: AppColors.accentYellow),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (kIsWeb || state.liveDistractionFeed.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 220,
                      child: LiveDistractionFeed(
                        feed: state.liveDistractionFeed,
                      ),
                    ),
                  ],
                  if (kIsWeb && !state.extensionConnected) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      color: AppColors.accentYellow.withValues(alpha: 0.15),
                      padding: const EdgeInsets.all(10),
                      child: const Row(
                        children: [
                          Icon(Icons.extension_off,
                              color: AppColors.accentYellow, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Install the FocusEcho Chrome extension for real-time monitoring.',
                              style: TextStyle(
                                  color: AppColors.accentYellow, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.accentRed)),
                    onPressed: vm.stopSession,
                    child: const Text('STOP SESSION'),
                  ),
                ],
              ),
            ),
          ),
          if (showFullScreenIntervention)
            InterventionOverlay(
              level: state.escalationLevel,
              distractionCount: state.distractionCount,
              appName: state.lastDistractionLabel ??
                  state.lastDistractionPackage ??
                  'Unknown app',
              sessionIntent: state.session?.intent ?? state.intent,
              onReturnToFocus: vm.returnToFocusFromIntervention,
              onTakeBreak: vm.takeBreakFromIntervention,
              onPauseSession: vm.pauseSessionFromIntervention,
            ),
        ],
      ),
    );
  }
}

/// Feature 1 — Enhanced setup view with rich category chips, custom app creation,
/// quick intent suggestions, and responsive layout.
class _SessionSetupView extends StatefulWidget {
  const _SessionSetupView({required this.state, required this.vm});

  final FocusSessionState state;
  final FocusSessionViewModel vm;

  @override
  State<_SessionSetupView> createState() => _SessionSetupViewState();
}

class _SessionSetupViewState extends State<_SessionSetupView> {
  late final TextEditingController _intentCtrl;

  static const List<String> _quickPicks = [
    'VS Code',
    'Figma',
    'GitHub',
    'Notion',
    'Google Docs',
    'ChatGPT / Claude',
    'Slack',
    'Cursor',
  ];

  static const List<String> _quickIntents = [
    'Deep coding session',
    'Feature implementation',
    'Bug fixes & tests',
    'UI & design review',
    'Documentation & writing',
    'Research & study',
  ];

  @override
  void initState() {
    super.initState();
    _intentCtrl = TextEditingController(text: widget.state.intent);
  }

  @override
  void didUpdateWidget(covariant _SessionSetupView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.intent != oldWidget.state.intent &&
        widget.state.intent != _intentCtrl.text) {
      _intentCtrl.text = widget.state.intent;
    }
  }

  @override
  void dispose() {
    _intentCtrl.dispose();
    super.dispose();
  }

  IconData _iconForApp(String app) {
    final l = app.toLowerCase();
    if (l.contains('code') || l.contains('cursor') || l.contains('intellij') || l.contains('terminal')) {
      return Icons.code_rounded;
    }
    if (l.contains('git') || l.contains('github') || l.contains('gitlab')) {
      return Icons.commit_rounded;
    }
    if (l.contains('figma') || l.contains('design') || l.contains('canva') || l.contains('photoshop') || l.contains('blender')) {
      return Icons.palette_outlined;
    }
    if (l.contains('doc') || l.contains('word') || l.contains('overleaf') || l.contains('latex')) {
      return Icons.description_outlined;
    }
    if (l.contains('sheet') || l.contains('excel')) {
      return Icons.table_chart_outlined;
    }
    if (l.contains('notion') || l.contains('obsidian') || l.contains('note')) {
      return Icons.auto_stories_outlined;
    }
    if (l.contains('slack') || l.contains('teams') || l.contains('meet') || l.contains('zoom')) {
      return Icons.chat_bubble_outline_rounded;
    }
    if (l.contains('chatgpt') || l.contains('claude') || l.contains('perplexity') || l.contains('ai')) {
      return Icons.psychology_outlined;
    }
    if (l.contains('coursera') || l.contains('khan') || l.contains('duolingo') || l.contains('study')) {
      return Icons.school_outlined;
    }
    return Icons.apps_rounded;
  }

  void _showAddCustomAppDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.add_circle_outline, color: AppColors.accentBlue),
            const SizedBox(width: 8),
            Text('Add Productive App', style: AppTextStyles.displayMedium.copyWith(fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the name of the app or website you work with:',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Linear, Jupyter, Blender, Company Portal',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  widget.vm.addProductiveApp(val.trim());
                  Navigator.of(dialogCtx).pop();
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentBlue,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                widget.vm.addProductiveApp(controller.text.trim());
                Navigator.of(dialogCtx).pop();
              }
            },
            child: const Text('Add & Select', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final vm = widget.vm;
    final intent = _intentCtrl.text;
    final canStart =
        state.selectedProductiveApp != null && intent.trim().isNotEmpty;

    final allApps = state.availableProductiveApps;
    final selectedApp = state.selectedProductiveApp;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Session'),
        leading: BackButton(onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/dashboard');
          }
        }),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: AppDecorations.glassmorphismCard(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header Badge & Title ─────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accentBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded, size: 14, color: AppColors.accentBlue),
                            const SizedBox(width: 4),
                            Text(
                              'DEEP WORK SETUP',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.accentBlue,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Ready to Focus?',
                      style: AppTextStyles.displayLarge.copyWith(fontSize: 30)),
                  const SizedBox(height: 6),
                  Text(
                    'Pick what you are working in and state your intention for this session.',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),

                  // ── Section 1: Quick Picks ────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Top Productive Tools',
                          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        '${allApps.length} tools available',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._quickPicks.map((app) {
                        final isSelected = selectedApp == app;
                        return ChoiceChip(
                          selected: isSelected,
                          onSelected: (_) => vm.selectProductiveApp(app),
                          avatar: Icon(
                            _iconForApp(app),
                            size: 16,
                            color: isSelected ? Colors.black : AppColors.accentBlue,
                          ),
                          label: Text(app),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                          selectedColor: AppColors.accentBlue,
                          backgroundColor: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected ? AppColors.accentBlue : AppColors.border,
                            ),
                          ),
                        );
                      }),
                      ActionChip(
                        onPressed: _showAddCustomAppDialog,
                        avatar: const Icon(Icons.add, size: 16, color: AppColors.accentGreen),
                        label: const Text('+ Custom app'),
                        labelStyle: const TextStyle(
                          color: AppColors.accentGreen,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        backgroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: AppColors.accentGreen.withValues(alpha: 0.5)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── Section 2: All Apps Dropdown Selector ─────────────────
                  Text('Or select from all apps:',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.accentBlue),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.accentBlue),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: allApps.contains(selectedApp)
                            ? selectedApp
                            : (allApps.isNotEmpty ? allApps.first : null),
                        menuMaxHeight: 320,
                        isExpanded: true,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        items: allApps.map((app) {
                          return DropdownMenuItem<String>(
                            value: app,
                            child: Row(
                              children: [
                                Icon(_iconForApp(app), size: 18, color: AppColors.accentBlue),
                                const SizedBox(width: 10),
                                Text(app, style: const TextStyle(color: Colors.white, fontSize: 14)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) vm.selectProductiveApp(v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Section 3: Focus Intent ──────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('What is your focus intent?',
                          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        '${intent.trim().length}/80',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: intent.trim().isNotEmpty
                              ? AppColors.accentGreen
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _intentCtrl,
                    maxLength: 80,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'e.g. Finish the analytics dashboard charts',
                      hintStyle: const TextStyle(color: Colors.white38),
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.surface,
                      prefixIcon: const Icon(Icons.track_changes_rounded, color: AppColors.accentBlue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.accentBlue),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {});
                      vm.setIntent(val);
                    },
                  ),
                  const SizedBox(height: 10),

                  // Quick Intent Suggestion Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _quickIntents.map((qi) {
                      return ActionChip(
                        backgroundColor: AppColors.surface.withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        label: Text(
                          qi,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                        onPressed: () {
                          _intentCtrl.text = qi;
                          setState(() {});
                          vm.setIntent(qi);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  // ── Section 4: Start Action Button ─────────────────────────
                  InkWell(
                    onTap: canStart
                        ? () => vm.startSession(
                              selectedApp!,
                              intent: intent,
                            )
                        : null,
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: canStart
                            ? const LinearGradient(
                                colors: [Color(0xFF00C2FF), Color(0xFF0072FF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: canStart ? null : AppColors.surface,
                        border: Border.all(
                          color: canStart ? AppColors.accentBlue : AppColors.border,
                        ),
                        boxShadow: canStart
                            ? [
                                BoxShadow(
                                  color: AppColors.accentBlue.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : const [],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 24,
                            color: canStart ? Colors.white : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'START FOCUS SESSION',
                            style: AppTextStyles.displayMedium.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                              color: canStart ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!canStart)
                    Text(
                      selectedApp == null
                          ? 'Select a productive tool above to continue.'
                          : 'Enter your focus intent above to unlock the session.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.accentYellow,
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 14, color: AppColors.accentGreen),
                        const SizedBox(width: 6),
                        Text(
                          'Ready to work in $selectedApp: "${intent.trim()}"',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.accentGreen),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
