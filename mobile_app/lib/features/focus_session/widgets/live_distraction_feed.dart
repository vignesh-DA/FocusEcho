import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A compact Realtime distraction feed for an active focus session.
///
/// Rows are intentionally lightweight: the feed is a data surface, not a
/// modal. Each row enters once and then remains static until its data changes.
class LiveDistractionFeed extends StatelessWidget {
  const LiveDistractionFeed({super.key, required this.feed});

  final List<Map<String, dynamic>> feed;

  @override
  Widget build(BuildContext context) {
    final visibleRows = feed.take(50).toList(growable: false);
    final overflow = feed.length - visibleRows.length;

    return Semantics(
      container: true,
      label: 'Live distraction feed, ${feed.length} events',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.rss_feed_rounded,
                    size: 17, color: AppColors.accentBlue),
                const SizedBox(width: 8),
                Text('Live distractions', style: AppTextStyles.bodyLarge),
                const Spacer(),
                if (overflow > 0)
                  Text('+$overflow more',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: visibleRows.isEmpty
                  ? Center(
                      child: Text(
                        'No distractions yet — great focus!',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.accentGreen),
                      ),
                    )
                  : ListView.separated(
                      key:
                          const PageStorageKey<String>('live-distraction-feed'),
                      itemCount: visibleRows.length,
                      physics: const BouncingScrollPhysics(),
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) => _LiveFeedRow(
                        key: ValueKey(_rowKey(visibleRows[index], index)),
                        row: visibleRows[index],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _rowKey(Map<String, dynamic> row, int index) {
    return '${row['id'] ?? row['triggered_at'] ?? 'event'}-$index';
  }
}

class _LiveFeedRow extends StatefulWidget {
  const _LiveFeedRow({super.key, required this.row});

  final Map<String, dynamic> row;

  @override
  State<_LiveFeedRow> createState() => _LiveFeedRowState();
}

class _LiveFeedRowState extends State<_LiveFeedRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final reducedMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    _controller = AnimationController(
      vsync: this,
      duration:
          reducedMotion ? Duration.zero : const Duration(milliseconds: 200),
    )..forward();
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _fade = curve;
    _slide = Tween<Offset>(begin: const Offset(0, -0.08), end: Offset.zero)
        .animate(curve);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final label = _label(row);
    final level = _level(row);
    final recovered = row['is_recovered'] == true || row['is_recovered'] == 1;
    final dotColor = recovered ? AppColors.accentGreen : AppColors.accentRed;
    final badgeColor =
        level <= 1 ? AppColors.accentYellow : AppColors.accentRed;
    final status = recovered ? 'returned' : 'distraction';
    final semantics = '$label, level $level, $status, ${_timeAgo(row)}';

    return Semantics(
      label: semantics,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Container(
            constraints: const BoxConstraints(minHeight: 42),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: dotColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: dotColor.withValues(alpha: 0.18),
                  child: Text(
                    label.isEmpty ? '?' : label.characters.first.toUpperCase(),
                    style: TextStyle(
                        color: dotColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'L$level',
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(_timeAgo(row),
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _label(Map<String, dynamic> row) {
    final raw = (row['app_label'] ?? row['package_name'] ?? 'unknown')
        .toString()
        .trim();
    return raw.replaceFirst(RegExp(r'^web:'), '');
  }

  int _level(Map<String, dynamic> row) {
    final value = row['escalation_level'];
    return value is num ? value.toInt().clamp(1, 3) : 1;
  }

  String _timeAgo(Map<String, dynamic> row) {
    final raw = row['triggered_at']?.toString();
    final timestamp = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    if (timestamp == null) return 'just now';
    final elapsed = DateTime.now().difference(timestamp);
    if (elapsed.inSeconds < 60) return 'just now';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min ago';
    if (elapsed.inHours < 24) return '${elapsed.inHours} hr ago';
    return '${elapsed.inDays} d ago';
  }
}
