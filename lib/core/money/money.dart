import 'package:intl/intl.dart';

/// Supported primary currencies for Paydial, including a minimalist plain-numbers mode.
enum AppCurrency {
  egp('EGP', 'EGP', 'ج.م'),
  sar('SAR', 'SAR', 'ر.س'),
  aed('AED', 'AED', 'د.إ'),
  usd('USD', 'USD', r'$'),
  eur('EUR', 'EUR', '€'),
  gbp('GBP', 'GBP', '£'),
  none('NONE', '', '');

  final String code;
  final String symbolEn;
  final String symbolAr;

  const AppCurrency(this.code, this.symbolEn, this.symbolAr);

  /// Returns the localized symbol for this currency (`''` when [AppCurrency.none]).
  String symbol({required bool isArabic}) => isArabic ? symbolAr : symbolEn;

  /// Human-readable selector label for settings chips.
  String displayLabel({required bool isArabic}) {
    switch (this) {
      case AppCurrency.egp:
        return 'EGP (ج.م)';
      case AppCurrency.sar:
        return 'SAR (ر.س)';
      case AppCurrency.aed:
        return 'AED (د.إ)';
      case AppCurrency.usd:
        return r'USD ($)';
      case AppCurrency.eur:
        return 'EUR (€)';
      case AppCurrency.gbp:
        return 'GBP (£)';
      case AppCurrency.none:
        return isArabic ? 'بدون عملة (أرقام فقط)' : 'None / Plain Numbers';
    }
  }

  static AppCurrency fromCode(String? code) {
    if (code == null || code.trim().isEmpty) return AppCurrency.egp;
    final normalized = code.trim().toUpperCase();
    for (final currency in AppCurrency.values) {
      if (currency.code == normalized) return currency;
    }
    return AppCurrency.egp;
  }
}

/// Represents a monetary value stored as an exact integer of minor units (1/100 of major unit).
class Money implements Comparable<Money> {
  /// Maximum allowable transaction or budget amount (999,999,999 major units).
  static const int maxMajorUnits = 999999999;
  static const int maxMinorUnits = 99999999900;

  /// Currently active primary currency configuration.
  static AppCurrency currentCurrency = AppCurrency.egp;

  /// Default currency symbol used when none is explicitly specified in [toFormattedString].
  /// Can be dynamically synchronized with the active locale and selected [AppCurrency].
  static String defaultCurrencySymbol = 'EGP';

  /// Updates [currentCurrency] and synchronizes [defaultCurrencySymbol] for the active locale.
  static void applyCurrency(AppCurrency currency, {required bool isArabic}) {
    currentCurrency = currency;
    defaultCurrencySymbol = currency.symbol(isArabic: isArabic);
  }

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

  static final RegExp _groupedThousands = RegExp(r'^\d{1,3}(,\d{3})+$');

  /// Resolves thousands vs. decimal separators in a bare number ([digits],
  /// `.`, `,`) to plain `1234.56` form, or returns `null` if ambiguous.
  ///
  /// - Both `.` and `,` present: the last one is the decimal separator
  ///   (`1,234.56` and `1.234,56` both mean 1234.56).
  /// - Only commas: valid 3-digit groups are thousands (`1,234,567`);
  ///   a single comma followed by 1–2 digits is a decimal point (`12,5`).
  ///   Anything else (`12,3456`, `1,2,3`) is rejected rather than guessed,
  ///   so a mistyped amount is never silently multiplied.
  static String? normalizeSeparators(String number) {
    final lastDot = number.lastIndexOf('.');
    final lastComma = number.lastIndexOf(',');
    if (lastComma == -1) return number;

    if (lastDot != -1) {
      final decimalIsComma = lastComma > lastDot;
      final thousands = decimalIsComma ? '.' : ',';
      final decimalAt = decimalIsComma ? lastComma : lastDot;
      final intPart = number.substring(0, decimalAt);
      final fracPart = number.substring(decimalAt + 1);
      if (fracPart.contains(RegExp(r'[.,]'))) return null;
      final grouped = intPart.replaceAll(thousands, ',');
      if (intPart.contains(thousands) && !_groupedThousands.hasMatch(grouped)) {
        return null;
      }
      return '${intPart.replaceAll(thousands, '')}.$fracPart';
    }

    if (_groupedThousands.hasMatch(number)) return number.replaceAll(',', '');
    final parts = number.split(',');
    if (parts.length == 2 &&
        parts[0].isNotEmpty &&
        parts[1].isNotEmpty &&
        parts[1].length <= 2) {
      return '${parts[0]}.${parts[1]}';
    }
    return null;
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
  /// Supports optional currency prefixes/suffixes (EGP, ج.م, SAR, ر.س, AED, د.إ, USD, $, EUR, €, GBP, £),
  /// Eastern Arabic numerals, and leading/trailing whitespace.
  /// Throws [FormatException] if the string is not a valid number.
  factory Money.parse(String input) {
    var cleaned = normalizeDigits(input.trim());
    final tokens = <String>{
      'EGP',
      'ج.م',
      'SAR',
      'ر.س',
      'AED',
      'د.إ',
      'USD',
      r'$',
      'EUR',
      '€',
      'GBP',
      '£',
      if (defaultCurrencySymbol.trim().isNotEmpty) defaultCurrencySymbol.trim(),
    };

    String stripCurrencyTokens(String s) {
      var res = s.trim();
      var changed = true;
      while (changed && res.isNotEmpty) {
        changed = false;
        for (final token in tokens) {
          final upperRes = res.toUpperCase();
          final upperToken = token.toUpperCase();
          if (upperRes.startsWith(upperToken)) {
            res = res.substring(token.length).trim();
            changed = true;
          } else if (upperRes.endsWith(upperToken)) {
            res = res.substring(0, res.length - token.length).trim();
            changed = true;
          }
        }
      }
      return res;
    }

    cleaned = stripCurrencyTokens(cleaned);

    if (cleaned.isEmpty) {
      throw const FormatException('Cannot parse empty string as Money');
    }

    final isNegative = cleaned.startsWith('-');
    final isExplicitPositive = cleaned.startsWith('+');
    if (isNegative || isExplicitPositive) {
      cleaned = stripCurrencyTokens(cleaned.substring(1).trim());
    }

    // Arabic decimal (٫) -> '.', Arabic thousands (٬) and comma (،) -> ',',
    // then decide which separator is which (see normalizeSeparators).
    cleaned = cleaned
        .replaceAll('٫', '.')
        .replaceAll('٬', ',')
        .replaceAll('،', ',');
    final resolved = normalizeSeparators(cleaned);
    if (resolved == null) {
      throw FormatException('Ambiguous number separators in: "$input"');
    }
    cleaned = resolved;

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

    final symbol = (currencySymbol ?? defaultCurrencySymbol).trim();
    if (symbol.isEmpty) {
      return '$signPrefix$valueString';
    }
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
