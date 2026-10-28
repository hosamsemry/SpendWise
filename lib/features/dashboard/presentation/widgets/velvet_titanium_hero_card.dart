import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/daily_spending_provider.dart';
import 'package:money_tracker/features/budgets/domain/cycle_summary.dart';

class VelvetTitaniumHeroCard extends StatelessWidget {
  final BudgetCycle cycle;
  final CycleSummary summary;
  final DailySpendingSummary daily;

  const VelvetTitaniumHeroCard({
    super.key,
    required this.cycle,
    required this.summary,
    required this.daily,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final isNetPositive = summary.netRemainingTotal.inMinorUnits >= 0;

    // Cycle days calculations
    final totalCycleDays = math.max(
      1,
      cycle.endDate.difference(cycle.startDate).inDays + 1,
    );
    final daysRemaining = (daily.daysRemainingInCycle ??
            cycle.endDate.difference(DateTime.now()).inDays + 1)
        .clamp(0, totalCycleDays);
    final daysElapsed = (totalCycleDays - daysRemaining).clamp(0, totalCycleDays);
    final cycleTimeProgress = (daysElapsed / totalCycleDays).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? const Color(0xFFE5C158).withValues(alpha: 0.35)
              : const Color(0xFFB38A24).withValues(alpha: 0.30),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0xFF7B1123).withValues(alpha: 0.25)
                : const Color(0xFFB38A24).withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Stack(
          children: [
            // 1. Base Layer Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF14141B),
                          const Color(0xFF0F0F14),
                          const Color(0xFF0B0B0E),
                        ]
                      : [
                          const Color(0xFFFFFFFF),
                          const Color(0xFFFBFBFC),
                          const Color(0xFFF4F4F8),
                        ],
                ),
              ),
            ),

            // 2. Velvet Crimson Radial Glow Mesh
            Positioned(
              top: -60,
              right: -60,
              width: 220,
              height: 220,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      isDark
                          ? const Color(0xFF7B1123).withValues(alpha: 0.35)
                          : const Color(0xFFE11D48).withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              width: 180,
              height: 180,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      isDark
                          ? const Color(0xFF580F1A).withValues(alpha: 0.20)
                          : const Color(0xFFB38A24).withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // 3. Main Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Cycle dates & Floating Pace Pill
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.currentBudgetCycle.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: context.goldColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              cycle.formattedRange,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Velvet Glass Pill Badge
                      if (daily.dailyPace != null || !isNetPositive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: !isNetPositive
                                ? context.overspentColor.withValues(alpha: 0.15)
                                : isDark
                                ? const Color(0xFF7B1123).withValues(alpha: 0.35)
                                : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: !isNetPositive
                                  ? context.overspentColor.withValues(alpha: 0.5)
                                  : isDark
                                  ? context.goldColor.withValues(alpha: 0.4)
                                  : context.goldColor.withValues(alpha: 0.6),
                              width: 0.8,
                            ),
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
                                      ? context.overspentColor
                                      : daily.isOverDailyPace
                                      ? Colors.amber.shade400
                                      : context.goldColor,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                !isNetPositive
                                    ? context.l10n.overBudget
                                    : daily.isOverDailyPace
                                    ? context.l10n.overDailyPaceBadge(
                                        daily.overDailyPaceAmount.toFormattedString(
                                          decimalDigits: daily.overDailyPaceAmount.inMajorUnits >= 100 ? 0 : 2,
                                        ),
                                      )
                                    : context.l10n.safeDailyPaceBadge(
                                        daily.dailyPace!.toFormattedString(
                                          decimalDigits: daily.dailyPace!.inMajorUnits >= 100 ? 0 : 2,
                                        ),
                                      ),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                  color: !isNetPositive
                                      ? context.overspentColor
                                      : isDark
                                      ? context.textPrimary
                                      : const Color(0xFF78350F),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Center Row: Balance Metrics on Left + Circular Pace Gauge on Right
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Balance column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.remainingBudget.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: context.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              summary.netRemainingTotal.toFormattedString(showSign: true),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: isNetPositive
                                    ? (isDark ? Colors.white : context.textPrimary)
                                    : context.overspentColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              context.l10n.ofTotal(
                                summary.totalBudgeted.toFormattedString(),
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Circular Pace Ring Gauge
                      _PaceRingGauge(
                        cycleProgress: cycleTimeProgress,
                        daysRemaining: daysRemaining,
                        goldColor: context.goldColor,
                        trackColor: isDark
                            ? const Color(0xFF7B1123).withValues(alpha: 0.35)
                            : Colors.grey.shade200,
                        textColor: context.textPrimary,
                        subtextColor: context.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Linear Spending Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 6,
                      color: isDark
                          ? const Color(0xFF262633)
                          : Colors.grey.shade200,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: summary.totalBudgeted.inMinorUnits > 0
                            ? (summary.totalSpent.inMinorUnits / summary.totalBudgeted.inMinorUnits).clamp(0.0, 1.0)
                            : (summary.totalSpent.inMinorUnits > 0 ? 1.0 : 0.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isNetPositive
                                  ? [
                                      context.goldColor,
                                      isDark ? const Color(0xFFFFF0BA) : const Color(0xFFB38A24),
                                    ]
                                  : [
                                      const Color(0xFFDC2626),
                                      const Color(0xFFEF4444),
                                    ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Divider
                  Container(
                    height: 1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                  const SizedBox(height: 14),

                  // Bottom 3 Key Metrics Row
                  Row(
                    children: [
                      // Metric 1: Today's Spent
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.todaysSpending,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: context.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              daily.totalSpentToday.toFormattedString(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: daily.isOverDailyPace
                                    ? Colors.amber.shade600
                                    : context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              daily.isOverDailyPace
                                  ? context.l10n.overDailyPace
                                  : (daily.dailyPace != null && daily.dailyPace!.inMinorUnits > 0
                                      ? context.l10n.safeLeft(daily.remainingToday.toFormattedString())
                                      : (daily.transactionCountToday == 0
                                          ? context.l10n.expensesCount(0)
                                          : context.l10n.expensesCount(daily.transactionCountToday))),
                              style: TextStyle(
                                fontSize: 10,
                                color: daily.isOverDailyPace
                                    ? Colors.amber.shade600
                                    : context.textTertiary,
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
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                      const SizedBox(width: 12),

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
                                color: context.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              summary.totalSpent.toFormattedString(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              summary.totalBudgeted.inMinorUnits > 0
                                  ? context.l10n.percentOfBudget(
                                      ((summary.totalSpent.inMinorUnits / summary.totalBudgeted.inMinorUnits) * 100).toStringAsFixed(0),
                                    )
                                  : context.l10n.noBudgetSetShort,
                              style: TextStyle(
                                fontSize: 10,
                                color: context.textTertiary,
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
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                      const SizedBox(width: 12),

                      // Metric 3: Total Income
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.totalIncomeLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: context.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              summary.totalIncome.toFormattedString(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: context.incomeColor,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              context.l10n.recorded,
                              style: TextStyle(
                                fontSize: 10,
                                color: context.textTertiary,
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
          ],
        ),
      ),
    );
  }
}

class _PaceRingGauge extends StatelessWidget {
  final double cycleProgress;
  final int daysRemaining;
  final Color goldColor;
  final Color trackColor;
  final Color textColor;
  final Color subtextColor;

  const _PaceRingGauge({
    required this.cycleProgress,
    required this.daysRemaining,
    required this.goldColor,
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
              progressColor: goldColor,
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

    // Progress Arc (Champagne Gold)
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
