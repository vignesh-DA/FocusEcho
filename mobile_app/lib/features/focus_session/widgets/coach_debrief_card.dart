import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/ai_coach_service.dart';

class CoachDebriefCard extends StatefulWidget {
  const CoachDebriefCard({
    super.key,
    required this.sessionId,
    this.coachService,
  });

  final String sessionId;
  final AiCoachService? coachService;

  @override
  State<CoachDebriefCard> createState() => _CoachDebriefCardState();
}

class _CoachDebriefCardState extends State<CoachDebriefCard> {
  late final AiCoachService _service;
  SessionDebriefResult? _debrief;
  bool _loading = true;
  int _userFeedback = 0; // -1, 0, 1

  @override
  void initState() {
    super.initState();
    _service = widget.coachService ?? AiCoachService();
    _loadDebrief();
  }

  Future<void> _loadDebrief() async {
    final result = await _service.fetchSessionDebrief(widget.sessionId);
    if (mounted) {
      setState(() {
        _debrief = result;
        _loading = false;
      });
    }
  }

  Future<void> _onFeedback(int feedback) async {
    setState(() => _userFeedback = feedback);
    await _service.submitFeedback(widget.sessionId, feedback);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(20),
        decoration: AppDecorations.glassmorphismCard().copyWith(
          border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accentBlue,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'EchoCoach analyzing session telemetry...',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      );
    }

    final debrief = _debrief;
    if (debrief == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.glassmorphismCard().copyWith(
        border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.accentBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'EchoCoach Debrief',
                style: AppTextStyles.displayMedium.copyWith(fontSize: 18),
              ),
              const Spacer(),
              if (debrief.totalSessionsAnalyzed < 5)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'Cold Start (<5 sessions)',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            debrief.headline,
            style: AppTextStyles.bodyLarge.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            debrief.body,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (debrief.distractionMinuteOffsets.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Text(
                  'Distraction timeline:',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ...debrief.distractionMinuteOffsets.map(
                  (offset) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppColors.accentRed.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Min ${offset.toStringAsFixed(1)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.accentRed,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (debrief.actionableTip.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.accentGreen.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: AppColors.accentGreen,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next Session Micro-Experiment',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.accentGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          debrief.actionableTip,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Was this debrief helpful?',
                style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _onFeedback(1),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _userFeedback == 1
                        ? Icons.thumb_up_rounded
                        : Icons.thumb_up_outlined,
                    size: 16,
                    color: _userFeedback == 1
                        ? AppColors.accentGreen
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _onFeedback(-1),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _userFeedback == -1
                        ? Icons.thumb_down_rounded
                        : Icons.thumb_down_outlined,
                    size: 16,
                    color: _userFeedback == -1
                        ? AppColors.accentRed
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
