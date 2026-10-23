import 'package:intl/intl.dart';

/// Represents a monetary value stored as an exact integer of minor units (piastres).
/// 1 EGP = 100 piastres.
class Money implements Comparable<Money> {
  /// Maximum allowable transaction or budget amount (999,999,999 EGP).
  static const int maxMajorUnits = 999999999;
  static const int maxMinorUnits = 99999999900;

  /// Default currency symbol used when none is explicitly specified in [toFormattedString].
  /// Can be dynamically synchronized with the active locale (e.g. 'ج.م' or 'EGP').
  static String defaultCurrencySymbol = 'EGP';

  final int minorUnits;

  const Money.fromMinorUnits(this.minorUnits);

  const Money.zero() : minorUnits = 0;

  /// Normalizes any Eastern Arabic digits (٠-٩) or Persian digits (۰-۹) to standard ASCII (0-9).
  static String normalizeDigits(String input) {
    const arabicEastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var result = input;
    for (int i = 0; i < 10; i++) {
      result = result
          .replaceAll(arabicEastern[i], '$i')
          .replaceAll(persian[i], '$i');
    }
    return result;
  }

  /// Creates a [Money] instance from major units (EGP).
  ///
  /// Uses decimal-safe integer math by parsing the string representation
  /// to avoid floating-point inaccuracies.
  factory Money.fromMajorUnits(num amount) {
    // Convert to fixed string representation with 2 decimal places to prevent float drift
    final fixedString = amount.toStringAsFixed(2);
    return Money.parse(fixedString);
  }

  /// Parses a decimal string (e.g., "120", "120.5", "120.50", "-50.00") into a [Money] instance.
  ///
  /// Supports optional "EGP" or "ج.م" prefix/suffix, Eastern Arabic numerals, and leading/trailing whitespace.
  /// Throws [FormatException] if the string is not a valid number.
  factory Money.parse(String input) {
    var cleaned = normalizeDigits(input.trim());
    if (cleaned.toUpperCase().startsWith('EGP')) {
      cleaned = cleaned.substring(3).trim();
    }
    if (cleaned.toUpperCase().endsWith('EGP')) {
      cleaned = cleaned.substring(0, cleaned.length - 3).trim();
    }
    if (cleaned.startsWith('ج.م')) {
      cleaned = cleaned.substring(3).trim();
    }
    if (cleaned.endsWith('ج.م')) {
      cleaned = cleaned.substring(0, cleaned.length - 3).trim();
    }

    if (cleaned.isEmpty) {
      throw const FormatException('Cannot parse empty string as Money');
    }

    final isNegative = cleaned.startsWith('-');
    final isExplicitPositive = cleaned.startsWith('+');
    if (isNegative || isExplicitPositive) {
      cleaned = cleaned.substring(1).trim();
    }

    // Strip thousands separators (Western commas and Arabic commas)
    // Replace Arabic decimal separator (٫ U+066B) with period (.)
    cleaned = cleaned
        .replaceAll('،', '')
        .replaceAll(',', '')
        .replaceAll('٫', '.');

    final parts = cleaned.split('.');
    if (parts.length > 2) {
      throw FormatException('Invalid monetary format: "$input"');
    }

    final wholePartStr = parts[0];
    final int? wholePart = int.tryParse(wholePartStr);
    if (wholePart == null || wholePart < 0) {
      throw FormatException(
        'Invalid monetary whole part: "$wholePartStr" in "$input"',
      );
    }

    int minorPart = 0;
    if (parts.length == 2) {
      final fracStr = parts[1];
      if (fracStr.length > 2) {
        throw FormatException('More than 2 decimal places in: "$input"');
      }
      if (fracStr.isNotEmpty) {
        final padded = fracStr.padRight(2, '0');
        final parsedFrac = int.tryParse(padded);
        if (parsedFrac == null || parsedFrac < 0) {
          throw FormatException(
            'Invalid fractional part: "$fracStr" in "$input"',
          );
        }
        minorPart = parsedFrac;
      }
    }

    final totalMinor = (wholePart * 100) + minorPart;
    if (totalMinor > maxMinorUnits) {
      throw const FormatException('Amount exceeds maximum allowable limit of 999,999,999 EGP');
    }
    return Money.fromMinorUnits(isNegative ? -totalMinor : totalMinor);
  }

  /// Tries to parse [input] into a [Money] instance, returning `null` on failure.
  static Money? tryParse(String? input) {
    if (input == null) return null;
    try {
      return Money.parse(input);
    } catch (_) {
      return null;
    }
  }

  /// Total minor units (piastres).
  int get inMinorUnits => minorUnits;

  /// Value in major units (EGP) as a double.
  double get inMajorUnits => minorUnits / 100.0;

  bool get isNegative => minorUnits < 0;
  bool get isPositive => minorUnits > 0;
  bool get isZero => minorUnits == 0;

  Money operator +(Money other) =>
      Money.fromMinorUnits(minorUnits + other.minorUnits);

  Money operator -(Money other) =>
      Money.fromMinorUnits(minorUnits - other.minorUnits);

  Money operator *(num multiplier) =>
      Money.fromMinorUnits((minorUnits * multiplier).round());

  Money operator -() => Money.fromMinorUnits(-minorUnits);

  bool operator <(Money other) => minorUnits < other.minorUnits;

  bool operator <=(Money other) => minorUnits <= other.minorUnits;

  bool operator >(Money other) => minorUnits > other.minorUnits;

  bool operator >=(Money other) => minorUnits >= other.minorUnits;

  Money abs() => Money.fromMinorUnits(minorUnits.abs());

  /// Formats the money value into a readable string.
  ///
  /// Examples:
  /// - `toFormattedString()`: `1,250.00 EGP`
  /// - If [includeCurrency] is false: `1,250.00`
  /// - If [showSign] is true: `+1,250.00 EGP` or `-250.00 EGP`
  /// - If [decimalDigits] is 0: `1,250 EGP`
  String toFormattedString({
    bool includeCurrency = true,
    bool showSign = false,
    int decimalDigits = 2,
    bool symbolPrefix = false,
    String? currencySymbol,
  }) {
    final absMinor = minorUnits.abs();
    final major = absMinor ~/ 100;
    final minor = absMinor % 100;

    final numberFormat = NumberFormat('#,##0', 'en_US');
    final formattedMajor = numberFormat.format(major);

    String valueString;
    if (decimalDigits == 0) {
      valueString = formattedMajor;
    } else if (decimalDigits == 2) {
      valueString = '$formattedMajor.${minor.toString().padLeft(2, '0')}';
    } else {
      final doubleVal = absMinor / 100.0;
      valueString = NumberFormat.currency(
        symbol: '',
        decimalDigits: decimalDigits,
      ).format(doubleVal).trim();
    }

    String signPrefix = '';
    if (minorUnits < 0) {
      signPrefix = '-';
    } else if (showSign && minorUnits > 0) {
      signPrefix = '+';
    }

    if (!includeCurrency) {
      return '$signPrefix$valueString';
    }

    final symbol = currencySymbol ?? defaultCurrencySymbol;
    if (symbolPrefix) {
      return '$signPrefix$symbol $valueString';
    } else {
      return '$signPrefix$valueString $symbol';
    }
  }

  @override
  int compareTo(Money other) => minorUnits.compareTo(other.minorUnits);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Money && other.minorUnits == minorUnits);

  @override
  int get hashCode => minorUnits.hashCode;

  @override
  String toString() => toFormattedString();
}
