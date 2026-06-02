import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class DistractionAlertModal extends StatefulWidget {
  const DistractionAlertModal({
    super.key,
    required this.onRecovery,
    required this.onEndSession,
    required this.onStreakPenalty,
    required this.onSnooze,
    required this.appName,
    required this.packageName,
    required this.riskScore,
  });

  final VoidCallback onRecovery;
  final VoidCallback onEndSession;
  final VoidCallback onStreakPenalty;
  final VoidCallback onSnooze;
  final String appName;
  final String packageName;
  final String riskScore;

  @override
  State<DistractionAlertModal> createState() => _DistractionAlertModalState();
}

class _DistractionAlertModalState extends State<DistractionAlertModal>
    with SingleTickerProviderStateMixin {
  int _seconds = 10;
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds == 0) {
        widget.onStreakPenalty();
        if (mounted) Navigator.of(context).pop();
        timer.cancel();
        return;
      }
      setState(() => _seconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (widget.riskScore) {
      'CRITICAL' => AppColors.accentRed,
      'HIGH' => Colors.orange,
      'MEDIUM' => AppColors.accentYellow,
      _ => AppColors.accentGreen,
    };

    return Material(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: AppDecorations.neonCard(glowColor: AppColors.accentRed),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.15).animate(
                  CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                ),
                child: const Icon(Icons.warning_rounded, size: 72, color: AppColors.accentRed),
              ),
              const SizedBox(height: 12),
              Text(
                "Heads up — quick focus check",
                style: AppTextStyles.displayMedium.copyWith(color: AppColors.accentRed),
              ),
              const SizedBox(height: 8),
              Text('Still focused after ${widget.appName}?', style: AppTextStyles.bodyLarge),
              const SizedBox(height: 8),
              Chip(
                backgroundColor: color.withOpacity(0.25),
                label: Text(widget.riskScore),
              ),
              const SizedBox(height: 16),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: _seconds / 10,
                      strokeWidth: 8,
                      color: AppColors.accentRed,
                    ),
                  ),
                  Text('$_seconds', style: AppTextStyles.displayLarge.copyWith(fontSize: 48)),
                ],
              ),
              const SizedBox(height: 10),
              const Text('Ready to return to your focus app?'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onRecovery();
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('+25 XP')),
                    );
                  },
                  child: const Text("I'm Back! 🎯"),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.accentRed),
                  ),
                  onPressed: () {
                    widget.onEndSession();
                    Navigator.of(context).pop();
                  },
                  child: const Text('End Session'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    widget.onSnooze();
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Snooze for 5 mins (Override)',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
