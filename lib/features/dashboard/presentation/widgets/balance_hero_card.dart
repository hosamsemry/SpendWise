import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/daily_spending_provider.dart';
import 'package:money_tracker/features/budgets/domain/cycle_summary.dart';

class BalanceHeroCard extends StatelessWidget {
  final BudgetCycle cycle;
  final CycleSummary summary;
  final DailySpendingSummary daily;
  final bool isAmountsHidden;
  final VoidCallback? onToggleAmountsVisibility;
  final bool isHistoricalCycle;

  static const String _maskedHero = '••••••';
  static const String _maskedCompact = '••••';

  const BalanceHeroCard({
    super.key,
    required this.cycle,
    required this.summary,
    required this.daily,
    this.isAmountsHidden = false,
    this.onToggleAmountsVisibility,
    this.isHistoricalCycle = false,
  });

  Widget _buildPrivacyText(
    String text, {
    required String keySuffix,
    required TextStyle style,
    TextOverflow? overflow,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      child: Text(
        text,
        key: ValueKey('${keySuffix}_$isAmountsHidden'),
        style: style,
        overflow: overflow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNetPositive = summary.netRemainingTotal.inMinorUnits >= 0;

    // Flat card on the surface colour with a hairline border. Colour is kept
    // for meaning: the accent tracks the cycle, red only when overspent.
    final accent = context.primaryColor;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final textMuted = context.textTertiary;
    final overspentColor = context.overspentColor;
    final warningColor = context.warningColor;
    final dividerColor = context.dividerColor;
    final separatorColor = context.borderColor;
    final progressTrackColor = context.surfaceVariantColor;

    // Cycle days calculations
    final totalCycleDays = math.max(
      1,
      cycle.endDate.difference(cycle.startDate).inDays + 1,
    );
    final daysRemaining = isHistoricalCycle
        ? 0
        : (daily.daysRemainingInCycle ??
                cycle.endDate.difference(DateTime.now()).inDays + 1)
            .clamp(0, totalCycleDays);
    final daysElapsed =
        isHistoricalCycle ? totalCycleDays : (totalCycleDays - daysRemaining).clamp(0, totalCycleDays);
    final cycleTimeProgress = (daysElapsed / totalCycleDays).clamp(0.0, 1.0);
    final avgDailySpent = Money.fromMinorUnits(
      (summary.totalSpent.inMinorUnits / totalCycleDays).round(),
    );

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: context.borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge - 1),
        child: Stack(
          children: [
            // 3. Main Content
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusLarge - 1),
                splashColor: accent.withValues(alpha: 0.06),
                highlightColor: accent.withValues(alpha: 0.03),
                onTap: onToggleAmountsVisibility == null
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        onToggleAmountsVisibility!();
                      },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Remaining Budget header (+ privacy eye) & Floating Pace Pill
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    context.l10n.remainingBudget.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.8,
                                      color: textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  isAmountsHidden
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_outlined,
                                  size: 14,
                                  color: isAmountsHidden ? accent : textMuted,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Pace / Status Pill Badge
                          if (isHistoricalCycle ||
                              daily.dailyPace != null ||
                              !isNetPositive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: !isNetPositive
                                    ? context.overspentLightColor
                                    : context.surfaceVariantColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: !isNetPositive
                                          ? overspentColor
                                          : (!isHistoricalCycle &&
                                                  daily.isOverDailyPace)
                                              ? warningColor
                                              : context.incomeColor,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    !isNetPositive
                                        ? context.l10n.overBudget
                                        : isHistoricalCycle
                                            ? context.l10n.cycleCompleted
                                            : daily.isOverDailyPace
                                                ? context.l10n.overDailyPaceBadge(
                                                    isAmountsHidden
                                                        ? _maskedCompact
                                                        : daily
                                                            .overDailyPaceAmount
                                                            .toFormattedString(
                                                              decimalDigits: daily
                                                                          .overDailyPaceAmount
                                                                          .inMajorUnits >=
                                                                      100
                                                                  ? 0
                                                                  : 2,
                                                            ),
                                                  )
                                                : context.l10n.safeDailyPaceBadge(
                                                    isAmountsHidden
                                                        ? _maskedCompact
                                                        : daily.dailyPace!
                                                            .toFormattedString(
                                                              decimalDigits: daily
                                                                          .dailyPace!
                                                                          .inMajorUnits >=
                                                                      100
                                                                  ? 0
                                                                  : 2,
                                                            ),
                                                  ),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.2,
                                      color: !isNetPositive
                                          ? overspentColor
                                          : textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Center Row: Balance Metrics on Left + Circular Pace Gauge on Right
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Balance column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPrivacyText(
                                  isAmountsHidden
                                      ? _maskedHero
                                      : summary.netRemainingTotal
                                          .toFormattedString(showSign: true),
                                  keySuffix: 'remaining',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: isAmountsHidden ? 2.0 : -0.8,
                                    color: isNetPositive
                                        ? textPrimary
                                        : overspentColor,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                _buildPrivacyText(
                                  context.l10n.ofTotal(
                                    isAmountsHidden
                                        ? _maskedCompact
                                        : summary.totalBudgeted
                                            .toFormattedString(),
                                  ),
                                  keySuffix: 'of_total',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Circular Pace Ring Gauge
                          _PaceRingGauge(
                            cycleProgress: cycleTimeProgress,
                            daysRemaining: daysRemaining,
                            progressColor: accent,
                            trackColor: progressTrackColor,
                            textColor: accent,
                            subtextColor: textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Linear Spending Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 6,
                          color: progressTrackColor,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: summary.totalBudgeted.inMinorUnits > 0
                                ? (summary.totalSpent.inMinorUnits /
                                        summary.totalBudgeted.inMinorUnits)
                                    .clamp(0.0, 1.0)
                                : (summary.totalSpent.inMinorUnits > 0
                                    ? 1.0
                                    : 0.0),
                            child: ColoredBox(
                              color: isNetPositive ? accent : overspentColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Divider
                      Container(
                        height: 1,
                        color: dividerColor,
                      ),
                      const SizedBox(height: 14),

                      // Bottom 2 Key Metrics Row (Today's Spending & Cycle Spent)
                      Row(
                        children: [
                          // Metric 1: Today's Spent (or Avg / Day for historical cycles)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isHistoricalCycle
                                      ? context.l10n.avgDailySpend
                                      : context.l10n.todaysSpending,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                _buildPrivacyText(
                                  isAmountsHidden
                                      ? _maskedCompact
                                      : (isHistoricalCycle
                                          ? avgDailySpent.toFormattedString()
                                          : daily.totalSpentToday
                                              .toFormattedString()),
                                  keySuffix: 'today_spent',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: (!isHistoricalCycle &&
                                            daily.isOverDailyPace)
                                        ? warningColor
                                        : textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  isHistoricalCycle
                                      ? context.l10n.cycleDaysCount(
                                          totalCycleDays,
                                        )
                                      : daily.isOverDailyPace
                                          ? context.l10n.overDailyPace
                                          : (daily.dailyPace != null &&
                                                  daily.dailyPace!.inMinorUnits >
                                                      0
                                              ? context.l10n.safeLeft(
                                                  isAmountsHidden
                                                      ? _maskedCompact
                                                      : daily.remainingToday
                                                          .toFormattedString(),
                                                )
                                              : (daily.transactionCountToday ==
                                                      0
                                                  ? context.l10n.expensesCount(
                                                      0,
                                                    )
                                                  : context.l10n.expensesCount(
                                                      daily
                                                          .transactionCountToday,
                                                    ))),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: (!isHistoricalCycle &&
                                            daily.isOverDailyPace)
                                        ? warningColor
                                        : textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // Separator
                          Container(
                            width: 1,
                            height: 32,
                            color: separatorColor,
                          ),
                          const SizedBox(width: 16),

                          // Metric 2: Cycle Spent
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.cycleSpent,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                _buildPrivacyText(
                                  isAmountsHidden
                                      ? _maskedCompact
                                      : summary.totalSpent.toFormattedString(),
                                  keySuffix: 'cycle_spent',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  summary.totalBudgeted.inMinorUnits > 0
                                      ? context.l10n.percentOfBudget(
                                          ((summary.totalSpent.inMinorUnits /
                                                      summary.totalBudgeted
                                                          .inMinorUnits) *
                                                  100)
                                              .toStringAsFixed(0),
                                        )
                                      : context.l10n.noBudgetSetShort,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaceRingGauge extends StatelessWidget {
  final double cycleProgress;
  final int daysRemaining;
  final Color progressColor;
  final Color trackColor;
  final Color textColor;
  final Color subtextColor;

  const _PaceRingGauge({
    required this.cycleProgress,
    required this.daysRemaining,
    required this.progressColor,
    required this.trackColor,
    required this.textColor,
    required this.subtextColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(76, 76),
            painter: _RingGaugePainter(
              progress: cycleProgress,
              progressColor: progressColor,
              trackColor: trackColor,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$daysRemaining',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                context.l10n.daysLeftLabel(daysRemaining),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: subtextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingGaugePainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color trackColor;

  _RingGaugePainter({
    required this.progress,
    required this.progressColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 5.5;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}
