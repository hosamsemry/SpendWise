import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/money.dart';

/// Represents a single category slice inside [CategoryDonutChart].
class DonutSliceData {
  final String categoryId;
  final String label;
  final Money amount;
  final double percentage; // 0.0 - 100.0
  final Color color;

  const DonutSliceData({
    required this.categoryId,
    required this.label,
    required this.amount,
    required this.percentage,
    required this.color,
  });
}

/// Interactive, animated Donut Chart with tap-to-inspect slice highlighting,
/// smooth sweep-in reveal, and dynamic center percentage callout.
class CategoryDonutChart extends StatefulWidget {
  final List<DonutSliceData> slices;
  final Money totalSpent;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;

  const CategoryDonutChart({
    super.key,
    required this.slices,
    required this.totalSpent,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  static const List<Color> _darkPalette = [
    Color(0xFFE5C158), // Champagne Gold
    Color(0xFF10B981), // Emerald Mint
    Color(0xFF60A5FA), // Sapphire Sky
    Color(0xFFF97316), // Warm Coral Amber
    Color(0xFFA78BFA), // Soft Amethyst
    Color(0xFFF43F5E), // Velvet Rose
    Color(0xFF2DD4BF), // Teal Aqua
    Color(0xFFFBBF24), // Sunlit Honey
  ];

  static const List<Color> _lightPalette = [
    Color(0xFFB8860B), // Rich Metallic Gold
    Color(0xFF059669), // Deep Emerald
    Color(0xFF2563EB), // Royal Cobalt
    Color(0xFFEA580C), // Burnt Terracotta
    Color(0xFF7C3AED), // Deep Violet
    Color(0xFFE11D48), // Crimson Rose
    Color(0xFF0D9488), // Deep Teal
    Color(0xFFD97706), // Warm Amber
  ];

  /// Returns a harmonious, theme-adapted color for category index [index].
  static Color colorForIndex(int index, {required bool isDark}) {
    final palette = isDark ? _darkPalette : _lightPalette;
    return palette[index % palette.length];
  }

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart>
    with TickerProviderStateMixin {
  static const double _chartSize = 232.0;
  static const double _baseStrokeWidth = 26.0;
  static const double _selectedStrokeWidth = 34.0;
  static const double _selectedPopOut = 4.5;

  late final AnimationController _revealController;
  late final Animation<double> _revealAnimation;

  late final AnimationController _selectionController;
  late final Animation<double> _selectionAnimation;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _revealAnimation = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeOutCubic,
    );
    _revealController.forward();

    _selectionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _selectionAnimation = CurvedAnimation(
      parent: _selectionController,
      curve: Curves.easeOutCubic,
    );
    if (widget.selectedCategoryId != null) {
      _selectionController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant CategoryDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.totalSpent != widget.totalSpent ||
        oldWidget.slices.length != widget.slices.length) {
      _revealController.forward(from: 0.0);
    }

    if (oldWidget.selectedCategoryId != widget.selectedCategoryId) {
      if (widget.selectedCategoryId != null) {
        _selectionController.forward(from: 0.0);
      } else {
        _selectionController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _revealController.dispose();
    _selectionController.dispose();
    super.dispose();
  }

  List<_SliceArcRange> _computeArcRanges() {
    final slices = widget.slices;
    if (slices.isEmpty) return const [];

    final totalMinor = slices.fold<int>(
      0,
      (sum, s) => sum + s.amount.inMinorUnits,
    );
    if (totalMinor <= 0) return const [];

    const fullCircle = 2 * math.pi;
    final hasMultiple = slices.length > 1;
    final gapRadians = hasMultiple ? 0.035 : 0.0;

    final ranges = <_SliceArcRange>[];
    double cursor = 0.0;

    for (var i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final rawSweep = (slice.amount.inMinorUnits / totalMinor) * fullCircle;
      final effectiveGap = rawSweep > gapRadians * 2.2 ? gapRadians : 0.0;
      final drawStart = cursor + effectiveGap / 2;
      final drawSweep = math.max(rawSweep - effectiveGap, 0.012);

      ranges.add(
        _SliceArcRange(
          index: i,
          slice: slice,
          hitStart: cursor,
          hitEnd: cursor + rawSweep,
          drawStart: drawStart,
          drawSweep: drawSweep,
        ),
      );
      cursor += rawSweep;
    }

    return ranges;
  }

  void _handleTapUp(TapUpDetails details) {
    final ranges = _computeArcRanges();
    if (ranges.isEmpty) return;

    const size = Size(_chartSize, _chartSize);
    final center = Offset(size.width / 2, size.height / 2);
    final delta = details.localPosition - center;
    final distance = delta.distance;

    final baseRadius = (size.shortestSide / 2) - (_selectedStrokeWidth / 2) - _selectedPopOut - 4;
    final innerRadius = baseRadius - (_baseStrokeWidth / 2);
    final outerRadius = baseRadius + (_selectedStrokeWidth / 2) + _selectedPopOut;

    // Tapping inside the center hole clears active selection
    if (distance < innerRadius - 6) {
      if (widget.selectedCategoryId != null) {
        HapticFeedback.selectionClick();
        widget.onCategorySelected(null);
      }
      return;
    }

    // Ignore taps far outside the donut ring
    if (distance > outerRadius + 16) return;

    // Angle clockwise from 12 o'clock (-pi/2) in [0, 2*pi)
    double angle = (math.atan2(delta.dy, delta.dx) + (math.pi / 2)) % (2 * math.pi);
    if (angle < 0) angle += 2 * math.pi;

    for (final range in ranges) {
      if (angle >= range.hitStart && angle <= range.hitEnd) {
        HapticFeedback.selectionClick();
        final tappedId = range.slice.categoryId;
        if (widget.selectedCategoryId == tappedId) {
          widget.onCategorySelected(null);
        } else {
          widget.onCategorySelected(tappedId);
        }
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final ranges = _computeArcRanges();

    DonutSliceData? selectedSlice;
    if (widget.selectedCategoryId != null) {
      for (final s in widget.slices) {
        if (s.categoryId == widget.selectedCategoryId) {
          selectedSlice = s;
          break;
        }
      }
    }

    return Card(
      key: const ValueKey('category_donut_chart_card'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            SizedBox(
              width: _chartSize,
              height: _chartSize,
              child: GestureDetector(
                key: const ValueKey('category_donut_chart_gesture'),
                behavior: HitTestBehavior.opaque,
                onTapUp: _handleTapUp,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _revealAnimation,
                        _selectionAnimation,
                      ]),
                      builder: (context, _) {
                        return CustomPaint(
                          size: const Size(_chartSize, _chartSize),
                          painter: _DonutChartPainter(
                            ranges: ranges,
                            selectedCategoryId: widget.selectedCategoryId,
                            revealProgress: _revealAnimation.value,
                            selectionProgress: _selectionAnimation.value,
                            baseStrokeWidth: _baseStrokeWidth,
                            selectedStrokeWidth: _selectedStrokeWidth,
                            selectedPopOut: _selectedPopOut,
                            trackColor: isDark
                                ? context.surfaceVariantColor.withValues(alpha: 0.45)
                                : Colors.grey.shade100,
                            isDark: isDark,
                          ),
                        );
                      },
                    ),

                    // Center Callout
                    SizedBox(
                      width: _chartSize - (_selectedStrokeWidth * 2) - 24,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.92, end: 1.0).animate(anim),
                            child: child,
                          ),
                        ),
                        child: selectedSlice == null
                            ? _buildTotalCallout(context)
                            : _buildSelectedSliceCallout(context, selectedSlice),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Interactive Legend Pills (1-tap quick slice selection)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: widget.slices.map((slice) {
                final isSelected = slice.categoryId == widget.selectedCategoryId;
                final isDimmed =
                    widget.selectedCategoryId != null && !isSelected;

                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isDimmed ? 0.52 : 1.0,
                  child: InkWell(
                    key: ValueKey('donut_legend_${slice.categoryId}'),
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onCategorySelected(
                        isSelected ? null : slice.categoryId,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? slice.color.withValues(alpha: isDark ? 0.22 : 0.14)
                            : context.surfaceVariantColor.withValues(
                                alpha: isDark ? 0.5 : 0.65,
                              ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? slice.color
                              : context.borderColor.withValues(alpha: 0.7),
                          width: isSelected ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: slice.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            slice.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${slice.percentage.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? slice.color
                                  : context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCallout(BuildContext context) {
    return Column(
      key: const ValueKey('donut_callout_total'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.totalCycleExpenses,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            widget.totalSpent.toFormattedString(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          context.l10n.tapSliceToInspect,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            color: context.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedSliceCallout(
    BuildContext context,
    DonutSliceData slice,
  ) {
    return Column(
      key: ValueKey('donut_callout_${slice.categoryId}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: slice.color.withValues(alpha: context.isDark ? 0.22 : 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${slice.percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: slice.color,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          slice.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            slice.amount.toFormattedString(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _SliceArcRange {
  final int index;
  final DonutSliceData slice;
  final double hitStart;
  final double hitEnd;
  final double drawStart;
  final double drawSweep;

  const _SliceArcRange({
    required this.index,
    required this.slice,
    required this.hitStart,
    required this.hitEnd,
    required this.drawStart,
    required this.drawSweep,
  });
}

class _DonutChartPainter extends CustomPainter {
  final List<_SliceArcRange> ranges;
  final String? selectedCategoryId;
  final double revealProgress;
  final double selectionProgress;
  final double baseStrokeWidth;
  final double selectedStrokeWidth;
  final double selectedPopOut;
  final Color trackColor;
  final bool isDark;

  const _DonutChartPainter({
    required this.ranges,
    required this.selectedCategoryId,
    required this.revealProgress,
    required this.selectionProgress,
    required this.baseStrokeWidth,
    required this.selectedStrokeWidth,
    required this.selectedPopOut,
    required this.trackColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius =
        (size.shortestSide / 2) - (selectedStrokeWidth / 2) - selectedPopOut - 4;

    // Subtle background ring track
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = baseStrokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, baseRadius, trackPaint);

    if (ranges.isEmpty || revealProgress <= 0) return;

    const topAngle = -math.pi / 2;
    final maxRevealedAngle = 2 * math.pi * revealProgress;
    final hasSelection = selectedCategoryId != null;

    // Draw non-selected slices first, then selected slice on top for clean pop-out & glow
    for (final passSelected in [false, true]) {
      for (final range in ranges) {
        final isSelected = range.slice.categoryId == selectedCategoryId;
        if (isSelected != passSelected) continue;

        if (range.drawStart >= maxRevealedAngle) continue;
        final clampedSweep = math.min(
          range.drawSweep,
          maxRevealedAngle - range.drawStart,
        );
        if (clampedSweep <= 0) continue;

        final startAngle = topAngle + range.drawStart;
        final midAngle = startAngle + clampedSweep / 2;

        final strokeWidth = isSelected
            ? baseStrokeWidth +
                ((selectedStrokeWidth - baseStrokeWidth) * selectionProgress)
            : baseStrokeWidth;

        final popDistance = isSelected ? selectedPopOut * selectionProgress : 0.0;
        final sliceCenter = Offset(
          center.dx + math.cos(midAngle) * popDistance,
          center.dy + math.sin(midAngle) * popDistance,
        );

        final opacity = hasSelection && !isSelected
            ? 1.0 - (0.55 * selectionProgress)
            : 1.0;

        final rect = Rect.fromCircle(center: sliceCenter, radius: baseRadius);

        // Soft ambient glow behind the highlighted slice
        if (isSelected && selectionProgress > 0.05) {
          final glowPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth + 6
            ..strokeCap = StrokeCap.butt
            ..color = range.slice.color.withValues(
              alpha: (isDark ? 0.28 : 0.20) * selectionProgress,
            )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
          canvas.drawArc(rect, startAngle, clampedSweep, false, glowPaint);
        }

        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt
          ..color = range.slice.color.withValues(alpha: opacity.clamp(0.0, 1.0));

        canvas.drawArc(rect, startAngle, clampedSweep, false, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.ranges != ranges ||
        oldDelegate.selectedCategoryId != selectedCategoryId ||
        oldDelegate.revealProgress != revealProgress ||
        oldDelegate.selectionProgress != selectionProgress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.isDark != isDark;
  }
}
