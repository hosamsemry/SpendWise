import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/daily_spending_provider.dart';
import 'package:money_tracker/features/budgets/domain/cycle_summary.dart';

class VelvetTitaniumHeroCard extends StatelessWidget {
  final BudgetCycle cycle;
  final CycleSummary summary;
  final DailySpendingSummary daily;
  final bool isAmountsHidden;
  final VoidCallback? onToggleAmountsVisibility;

  static const String _maskedHero = '••••••';
  static const String _maskedCompact = '••••';

  const VelvetTitaniumHeroCard({
    super.key,
    required this.cycle,
    required this.summary,
    required this.daily,
    this.isAmountsHidden = false,
    this.onToggleAmountsVisibility,
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
    final isDark = context.isDark;
    final isNetPositive = summary.netRemainingTotal.inMinorUnits >= 0;

    // Harmonized palette tokens for Dark (Velvet Titanium) & Light (Porcelain Silk & Champagne Gold)
    final cardBorder = isDark
        ? const Color(0xFFE5C158).withValues(alpha: 0.35)
        : const Color(0xFFC6972C).withValues(alpha: 0.35);

    final cardShadows = isDark
        ? [
            BoxShadow(
              color: const Color(0xFF7B1123).withValues(alpha: 0.25),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ]
        : [
            BoxShadow(
              color: const Color(0xFF0B0F19).withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: const Color(0xFFC6972C).withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ];

    final cardBaseGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF14141B),
              Color(0xFF0F0F14),
              Color(0xFF0B0B0E),
            ],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFCFDFE),
              Color(0xFFF7F8FC),
            ],
          );

    final ambientGlowTopRight = isDark
        ? const Color(0xFF7B1123).withValues(alpha: 0.35)
        : const Color(0xFFE5C158).withValues(alpha: 0.12);

    final ambientGlowBottomLeft = isDark
        ? const Color(0xFF580F1A).withValues(alpha: 0.20)
        : const Color(0xFFBE185D).withValues(alpha: 0.04);

    final headerGold = isDark
        ? const Color(0xFFE5C158)
        : const Color(0xFF8C6514);

    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0B0F19);

    final textSecondary = isDark
        ? const Color(0xFFB4BED0)
        : const Color(0xFF475569);

    final textMuted = isDark
        ? const Color(0xFF8E9AB0)
        : const Color(0xFF64748B);

    final incomeColor = isDark
        ? const Color(0xFF34D399)
        : const Color(0xFF047857);

    final overspentColor = isDark
        ? const Color(0xFFF87171)
        : const Color(0xFFB91C1C);

    final warningColor = isDark
        ? const Color(0xFFFBBF24)
        : const Color(0xFFB45309);

    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE9EDF5);

    final separatorColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFFE2E8F0);

    final progressTrackColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFFEEF2F6);

    final paceGaugeTrackColor = isDark
        ? const Color(0xFF7B1123).withValues(alpha: 0.35)
        : const Color(0xFFE2E8F0);

    final paceGaugeProgressColor = isDark
        ? const Color(0xFFE5C158)
        : const Color(0xFFC6972C);

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
          color: cardBorder,
          width: 1.2,
        ),
        boxShadow: cardShadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Stack(
          children: [
            // 1. Base Layer Gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: cardBaseGradient,
                ),
              ),
            ),

            // 2. Ambient Metallic Glow Mesh
            Positioned(
              top: -65,
              right: -55,
              width: 230,
              height: 230,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ambientGlowTopRight,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -50,
              width: 190,
              height: 190,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ambientGlowBottomLeft,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Subtle top-edge sheen
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      isDark
                          ? const Color(0xFFE5C158).withValues(alpha: 0.3)
                          : const Color(0xFFC6972C).withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // 3. Main Content
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(23),
                splashColor: (isDark ? const Color(0xFFE5C158) : const Color(0xFFC6972C)).withValues(alpha: 0.10),
                highlightColor: (isDark ? const Color(0xFFE5C158) : const Color(0xFFC6972C)).withValues(alpha: 0.05),
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
                                    letterSpacing: 0.9,
                                    color: headerGold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  cycle.formattedRange,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Pace Pill Badge
                          if (daily.dailyPace != null || !isNetPositive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: !isNetPositive
                                    ? (isDark
                                        ? overspentColor.withValues(alpha: 0.16)
                                        : const Color(0xFFFEF2F2))
                                    : (isDark
                                        ? const Color(0xFF7B1123).withValues(alpha: 0.35)
                                        : const Color(0xFFFFFBEB)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: !isNetPositive
                                      ? (isDark
                                          ? overspentColor.withValues(alpha: 0.5)
                                          : const Color(0xFFFCA5A5))
                                      : (isDark
                                          ? const Color(0xFFE5C158).withValues(alpha: 0.45)
                                          : const Color(0xFFC6972C).withValues(alpha: 0.40)),
                                  width: 0.9,
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
                                          ? overspentColor
                                          : daily.isOverDailyPace
                                              ? warningColor
                                              : (isDark
                                                  ? const Color(0xFFE5C158)
                                                  : const Color(0xFFC6972C)),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    !isNetPositive
                                        ? context.l10n.overBudget
                                        : daily.isOverDailyPace
                                            ? context.l10n.overDailyPaceBadge(
                                                isAmountsHidden
                                                    ? _maskedCompact
                                                    : daily.overDailyPaceAmount
                                                        .toFormattedString(
                                                          decimalDigits:
                                                              daily.overDailyPaceAmount
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
                                                          decimalDigits:
                                                              daily.dailyPace!
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
                                          : (isDark
                                              ? const Color(0xFFF8FAFC)
                                              : const Color(0xFF8C6514)),
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
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      context.l10n.remainingBudget.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                        color: textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      isAmountsHidden
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_outlined,
                                      size: 14,
                                      color: isAmountsHidden
                                          ? headerGold
                                          : textMuted,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                _buildPrivacyText(
                                  isAmountsHidden
                                      ? _maskedHero
                                      : summary.netRemainingTotal
                                          .toFormattedString(showSign: true),
                                  keySuffix: 'remaining',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: isAmountsHidden ? 2.0 : -0.5,
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
                            progressColor: paceGaugeProgressColor,
                            trackColor: paceGaugeTrackColor,
                            textColor: textPrimary,
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
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isNetPositive
                                      ? (isDark
                                          ? const [
                                              Color(0xFFE5C158),
                                              Color(0xFFF7E29B),
                                            ]
                                          : const [
                                              Color(0xFFC6972C),
                                              Color(0xFFE5C158),
                                            ])
                                      : const [
                                          Color(0xFFDC2626),
                                          Color(0xFFEF4444),
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
                        color: dividerColor,
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
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                _buildPrivacyText(
                                  isAmountsHidden
                                      ? _maskedCompact
                                      : daily.totalSpentToday.toFormattedString(),
                                  keySuffix: 'today_spent',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: daily.isOverDailyPace
                                        ? warningColor
                                        : textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  daily.isOverDailyPace
                                      ? context.l10n.overDailyPace
                                      : (daily.dailyPace != null &&
                                              daily.dailyPace!.inMinorUnits > 0
                                          ? context.l10n.safeLeft(
                                              isAmountsHidden
                                                  ? _maskedCompact
                                                  : daily.remainingToday
                                                      .toFormattedString(),
                                            )
                                          : (daily.transactionCountToday == 0
                                              ? context.l10n.expensesCount(0)
                                              : context.l10n.expensesCount(
                                                  daily.transactionCountToday,
                                                ))),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: daily.isOverDailyPace
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

                          // Separator
                          Container(
                            width: 1,
                            height: 32,
                            color: separatorColor,
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
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                _buildPrivacyText(
                                  isAmountsHidden
                                      ? _maskedCompact
                                      : summary.totalIncome.toFormattedString(),
                                  keySuffix: 'total_income',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: incomeColor,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  context.l10n.recorded,
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
