import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';
import '../../models/engine_models.dart';
import '../../models/game_state.dart';
import 'primitives.dart';

class ReviewTab extends StatelessWidget {
  const ReviewTab({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(state.config.locale);

    return SingleChildScrollView(
      child: ControlSectionBand(
        title: strings.liveReview,
        child: LiveReviewCard(state: state),
      ),
    );
  }
}

class LiveReviewCard extends StatelessWidget {
  const LiveReviewCard({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(state.config.locale);
    final review = state.latestReview;
    if (review == null) {
      return Text(
        strings.waitingForMoveReview,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: Colors.white70, height: 1.35),
      );
    }

    final zhHant = strings.locale == AppLocale.zhHant;
    final tone = _qualityColor(review.quality);
    final summary = state.reviewSummary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LatestMoveVerdict(
          review: review,
          strings: strings,
          tone: tone,
          zhHant: zhHant,
        ),
        const SizedBox(height: 14),
        _ReviewSummaryGrid(summary: summary, strings: strings),
        const SizedBox(height: 14),
        Text(
          '${strings.winChance}: ${strings.white} ${review.whiteWinPercent}% / ${strings.black} ${review.blackWinPercent}%',
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _WinChanceBar(
          white: review.whiteWinPercent,
          draw: review.drawPercent,
          black: review.blackWinPercent,
        ),
        const SizedBox(height: 14),
        ControlDataLine(label: strings.playedMove, value: review.moveUci),
        ControlDataLine(label: strings.bestWas, value: review.bestMoveUci),
        ControlDataLine(
          label: strings.cpLoss,
          value: '${review.centipawnLoss}',
        ),
        ControlDataLine(
          label: strings.beforeAfter,
          value: '${review.beforeEvaluation} -> ${review.afterEvaluation}',
        ),
      ],
    );
  }

  Color _qualityColor(MoveQuality quality) => switch (quality) {
    MoveQuality.brilliant => const Color(0xFF26C2A3),
    MoveQuality.great => const Color(0xFF86A8C8),
    MoveQuality.best => const Color(0xFF8ED84E),
    MoveQuality.mistake => const Color(0xFFFFA24C),
    MoveQuality.miss => const Color(0xFFFF7065),
    MoveQuality.blunder => const Color(0xFFFF4F5E),
  };
}

class _LatestMoveVerdict extends StatelessWidget {
  const _LatestMoveVerdict({
    required this.review,
    required this.strings,
    required this.tone,
    required this.zhHant,
  });

  final MoveReview review;
  final AppStrings strings;
  final Color tone;
  final bool zhHant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.46)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              review.quality.icon,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: tone,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _qualityLabel(review.quality, zhHant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${review.moveUci} -> ${review.bestMoveUci}  /  ${review.centipawnLoss} ${strings.cpUnit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _qualityLabel(MoveQuality quality, bool zhHant) {
    if (!zhHant) {
      return quality.label(false);
    }
    return switch (quality) {
      MoveQuality.brilliant => '妙手',
      MoveQuality.great => '好棋',
      MoveQuality.best => '最佳',
      MoveQuality.mistake => '失誤',
      MoveQuality.miss => '漏失機會',
      MoveQuality.blunder => '大失誤',
    };
  }
}

class _ReviewSummaryGrid extends StatelessWidget {
  const _ReviewSummaryGrid({required this.summary, required this.strings});

  final MoveReviewSummary summary;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryPill(
                key: const ValueKey('review-summary-reviewed'),
                label: strings.reviewedMoves,
                value: '${summary.reviewedMoves}',
                icon: Icons.fact_check_rounded,
                tone: Colors.white70,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryPill(
                key: const ValueKey('review-summary-good'),
                label: strings.goodMoves,
                value: '${summary.goodMoveCount}',
                icon: Icons.trending_up_rounded,
                tone: _goodTone,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryPill(
                key: const ValueKey('review-summary-problem'),
                label: strings.problemMoves,
                value: '${summary.problemMoveCount}',
                icon: Icons.warning_amber_rounded,
                tone: _problemTone,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ProblemBreakdown(summary: summary, strings: strings),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricChip(
                key: const ValueKey('review-summary-average-cp'),
                label: strings.averageCpLoss,
                value: '${summary.averageCentipawnLoss}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricChip(
                key: const ValueKey('review-summary-average-pace'),
                label: strings.averagePace,
                value: _formatDurationMs(summary.averageMoveMs),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricChip(
                key: const ValueKey('review-summary-last-pace'),
                label: strings.lastPace,
                value: _formatDurationMs(summary.lastMoveMs),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDurationMs(int milliseconds) {
    if (milliseconds <= 0) {
      return '--';
    }
    final seconds = milliseconds / 1000;
    if (seconds < 10) {
      return '${seconds.toStringAsFixed(1)}s';
    }
    return '${seconds.round()}s';
  }

  static const Color _goodTone = Color(0xFF8ED84E);
  static const Color _problemTone = Color(0xFFFF7065);
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tone.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: tone),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: Colors.white70),
                ),
              ),
            ],
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProblemBreakdown extends StatelessWidget {
  const _ProblemBreakdown({required this.summary, required this.strings});

  final MoveReviewSummary summary;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          _BreakdownLine(
            key: const ValueKey('review-breakdown-mistakes'),
            label: strings.mistakes,
            value: summary.mistakeCount,
            icon: '?',
            tone: const Color(0xFFFFA24C),
          ),
          const SizedBox(height: 8),
          _BreakdownLine(
            key: const ValueKey('review-breakdown-missed-chances'),
            label: strings.missedChances,
            value: summary.missCount,
            icon: 'X',
            tone: const Color(0xFFFF7065),
          ),
          const SizedBox(height: 8),
          _BreakdownLine(
            key: const ValueKey('review-breakdown-critical-mistakes'),
            label: strings.criticalMistakes,
            value: summary.blunderCount,
            icon: '??',
            tone: const Color(0xFFFF4F5E),
          ),
        ],
      ),
    );
  }
}

class _BreakdownLine extends StatelessWidget {
  const _BreakdownLine({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final int value;
  final String icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            icon,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: tone,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '$value',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: value > 0 ? tone : Colors.white54,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WinChanceBar extends StatelessWidget {
  const _WinChanceBar({
    required this.white,
    required this.draw,
    required this.black,
  });

  final int white;
  final int draw;
  final int black;

  @override
  Widget build(BuildContext context) {
    final drawWidth = draw > 0 ? draw : 1;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 18,
        child: Row(
          children: [
            Expanded(
              flex: white.clamp(1, 100),
              child: Container(color: const Color(0xFFF2E9D8)),
            ),
            Expanded(
              flex: drawWidth.clamp(1, 100),
              child: Container(color: const Color(0xFF7E8580)),
            ),
            Expanded(
              flex: black.clamp(1, 100),
              child: Container(color: const Color(0xFF232625)),
            ),
          ],
        ),
      ),
    );
  }
}
