import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/smart_detection/domain/parsed_bank_message.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';

/// Offline rule-based parser for Arabic and English bank SMS & wallet notifications
/// (supports Egyptian InstaPay / IPN, CIB, NBE, Banque Misr, AAIB, QNB, wallets, and GCC/international formats).
class BankMessageParser {
  static final List<RegExp> _ignorePatterns = [
    RegExp(
      r'\b(otp|one[\s-]?time\s*password|verification\s*code|security\s*code|passcode|do\s+not\s+share)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'(رمز\s*التحقق|كود\s*التحقق|كلمة\s*المرور|الرقم\s*السري|لا\s*تشارك)',
    ),
    RegExp(
      r'\b(declined|rejected|failed|unsuccessful|insufficient\s*funds|cancelled|canceled)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'(تم\s*رفض|مرفوض|فشلت\s*العملية|رصيد\s*غير\s*كاف|غير\s*كافي)',
    ),
  ];

  static final List<RegExp> _incomePatterns = [
    RegExp(
      r'(تم\s*(?:بنجاح\s*)?(?:إ|ا)ضافة|تم\s*(?:بنجاح\s*)?(?:إ|ا)يداع|تم\s*(?:بنجاح\s*)?استلام|تم\s*(?:بنجاح\s*)?تحصيل|تحويل\s*وارد|وارد\s*(?:إ|ا)لى|استلام\s*(?:مبلغ|حوالة|تحويل)|حوالة\s*واردة|وصلتك)',
    ),
    RegExp(
      r'\b(credited|deposited|deposit\s+of|transfer\s+received|received\s+(?:amount|egp|sar|aed|usd|eur|gbp|from)?|you\s+(?:have\s+)?received|incoming\s+transfer|refund(?:ed)?|cashback)\b',
      caseSensitive: false,
    ),
  ];

  static final List<RegExp> _expensePatterns = [
    RegExp(
      r'(تم\s*(?:بنجاح\s*)?خصم|تم\s*(?:بنجاح\s*)?سحب|تم\s*(?:بنجاح\s*)?دفع|تم\s*(?:بنجاح\s*)?سداد|تم\s*(?:بنجاح\s*)?تحويل|تم\s*(?:تنفيذ|إجراء|اجراء)\s*(?:عملية|معاملة)|عملية\s*(?:شراء|خصم|سحب)|شراء\s*بمبلغ|خصم\s*مبلغ|سحب\s*نقدي|تحويل\s*مبلغ)',
    ),
    RegExp(
      r'\b(debited|deducted|withdrawn|withdrawal|transfer\s+sent|sent\s+(?:with\s+amount|egp|sar|aed|usd|eur|gbp)?|you\s+(?:have\s+)?sent|transferred|successful\s+transfer|purchase(?:\s+of)?|was\s+used\s+(?:for|at)|spent|paid|payment\s+(?:of|to)|charged)\b',
      caseSensitive: false,
    ),
  ];

  // Currency-anchored amount patterns (checked in priority order before generic fallback)
  static final List<RegExp> _amountPatterns = [
    // e.g., EGP 100.01, SAR 250, USD 49.99, $120.50
    // Letter codes must not start inside a word: "LE" in "APPLE 12" or
    // "MOBILE 0100..." is not Egyptian pounds.
    RegExp(
      r'(?:(?<![A-Za-z])(?:EGP|SAR|AED|USD|EUR|GBP|LE|L\.E\.)|\$|€|£)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ),
    // e.g., 357.00 جم, 515.00 ج.م, 100.01 EGP, 500 ريال
    // `\b` only understands ASCII word characters, so it never matches after an
    // Arabic suffix; a negative lookahead on Latin + Arabic letters is used instead.
    RegExp(
      r'([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*(?:EGP|SAR|AED|USD|EUR|GBP|LE|L\.E\.|ج\.م|جم|جنيه(?:ات)?(?:\s*مصري)?|ر\.س|ريال|د\.إ|درهم|\$|€|£)(?![A-Za-z؀-ۿ])',
      caseSensitive: false,
    ),
    // Fallback: Arabic/English amount keyword directly preceding number: مبلغ 357.00 or amount of 100.01
    RegExp(
      r'(?:مبلغ|بمبلغ|قدرها?|amount(?:\s+of)?)\s*:?\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ),
  ];

  /// Markers of a real account/instrument (card, account, reference, balance,
  /// payment network). Personal chats mentioning money almost never contain one.
  static final List<RegExp> _instrumentPatterns = [
    RegExp(
      r'(?<![A-Za-z])(?:card|account|a/c|acct|ref(?:erence)?|balance|avl|bal|ipn|instapay|wallet|pos|atm)(?![A-Za-z])',
      caseSensitive: false,
    ),
    RegExp(
      r'(بطاق|حساب|مرجع|رصيد|محفظ|شبكة\s*المدفوعات\s*اللحظية|(?:إ|ا)نستا\s*باي)',
    ),
  ];

  /// Number of leading [_amountPatterns] that are anchored to a currency.
  static const int _currencyAnchoredAmountPatterns = 2;

  /// Words that introduce an account balance rather than the transaction
  /// amount ("Avl bal EGP 12,000", "الرصيد المتاح 500 ج.م").
  static final RegExp _balanceLeadIn = RegExp(
    r'(?:(?<![A-Za-z])(?:bal|balance|avl|available)(?![A-Za-z])|رصيد)[^0-9]{0,20}$',
    caseSensitive: false,
  );

  static final List<RegExp> _referencePatterns = [
    RegExp(
      r'(?:مرجع(?:\s*التاجر|\s*العملية)?|رقم\s*المرجع)\s*:?\s*([A-Za-z0-9][A-Za-z0-9,_-]*)',
    ),
    RegExp(
      r'\b(?:Ref(?:\s*#|erence|\s*No\.?)?)\s*:?\s*([A-Za-z0-9][A-Za-z0-9,_-]*)',
      caseSensitive: false,
    ),
  ];

  /// Attempts to parse [rawText] into a [ParsedBankMessage].
  /// Returns `null` if the message does not represent a financial debit/credit event
  /// (for example OTPs, declined alerts, or ordinary chat/system messages).
  ///
  /// Use [strict] for sources that also carry personal messages (SMS apps):
  /// the amount must then be tied to a currency and the text must reference an
  /// account/instrument (card, account, ref, balance, IPN, ...). Keep it off for
  /// text the user explicitly pasted or shared, or apps they chose to watch.
  static ParsedBankMessage? parse(
    String rawText, {
    String? title,
    DateTime? receivedAt,
    bool strict = false,
  }) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return null;

    final combined = (title != null && title.trim().isNotEmpty && !trimmed.contains(title.trim()))
        ? '${title.trim()} $trimmed'
        : trimmed;

    final normalized = Money.normalizeDigits(combined)
        .replaceAll('٫', '.')
        .replaceAll('٬', ',')
        .replaceAll('،', ',');

    // 1. Reject OTPs, failed/declined messages, etc.
    for (final pattern in _ignorePatterns) {
      if (pattern.hasMatch(normalized)) return null;
    }

    // 2. Detect transaction direction (income vs expense)
    final type = _detectType(normalized);
    if (type == null) return null;

    // 3. Extract monetary amount
    final amount = _extractAmount(
      normalized,
      currencyAnchoredOnly: strict,
    );
    if (amount == null || amount.inMinorUnits <= 0) return null;

    // 3b. Strict sources must look like they come from a bank or wallet.
    if (strict && !_instrumentPatterns.any((p) => p.hasMatch(normalized))) {
      return null;
    }

    // 4. Extract reference ID (optional, for deduplication)
    final referenceId = _extractReferenceId(normalized);

    // 5. Extract transaction timestamp (falls back to receivedAt / now)
    final now = receivedAt ?? DateTime.now();
    final when = _extractDateTime(normalized, fallback: now);

    // 6. Extract merchant / payee / clean descriptive note
    final merchant = _extractMerchant(trimmed, normalized);
    final suggestedNote = _buildSuggestedNote(
      merchant: merchant,
      normalizedText: normalized,
      type: type,
    );

    return ParsedBankMessage(
      type: type,
      amount: amount,
      suggestedNote: suggestedNote,
      merchantKey: merchant?.toLowerCase(),
      referenceId: referenceId,
      transactionDate: when.date,
      hasExplicitTime: when.hasTime,
      rawMessage: trimmed,
    );
  }

  static TransactionType? _detectType(String normalized) {
    // Check explicit expense & income indicators.
    // Some messages contain "transfer sent" or "تم خصم ... باستخدام (شبكة المدفوعات اللحظية)"
    final isExpense = _expensePatterns.any((p) => p.hasMatch(normalized));
    final isIncome = _incomePatterns.any((p) => p.hasMatch(normalized));

    if (isExpense && !isIncome) return TransactionType.expense;
    if (isIncome && !isExpense) return TransactionType.income;

    // Disambiguate if both appear (e.g. "transfer received" vs "transfer sent")
    if (isExpense && isIncome) {
      if (RegExp(r'(تم\s*خصم|debited|deducted|transfer\s+sent)', caseSensitive: false)
          .hasMatch(normalized)) {
        return TransactionType.expense;
      }
      if (RegExp(r'(تم\s*(?:إ|ا)ضافة|تم\s*(?:إ|ا)يداع|credited|transfer\s+received)', caseSensitive: false)
          .hasMatch(normalized)) {
        return TransactionType.income;
      }
    }
    return null;
  }

  static Money? _extractAmount(
    String normalized, {
    bool currencyAnchoredOnly = false,
  }) {
    final patterns = currencyAnchoredOnly
        ? _amountPatterns.take(_currencyAnchoredAmountPatterns)
        : _amountPatterns;
    // Try every match in priority order, not just the first: an earlier
    // match can be a phone number or a balance. Amounts that follow a balance
    // word are only used if nothing else is found.
    Money? balanceFallback;
    for (final pattern in patterns) {
      for (final match in pattern.allMatches(normalized)) {
        final parsed = Money.tryParse(match.group(1));
        if (parsed == null || parsed.inMinorUnits <= 0) continue;
        final before = normalized.substring(0, match.start);
        if (_balanceLeadIn.hasMatch(before)) {
          balanceFallback ??= parsed;
          continue;
        }
        return parsed;
      }
    }
    return balanceFallback;
  }

  static String? _extractReferenceId(String normalized) {
    for (final pattern in _referencePatterns) {
      final match = pattern.firstMatch(normalized);
      final value = match?.group(1)?.replaceAll(RegExp(r'[.,]+$'), '').trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static String? _extractMerchant(String raw, String normalized) {
    final normalizedRaw = Money.normalizeDigits(raw);

    // Arabic merchant pattern: "... عند <merchant> يوم ..." or "... لدى <merchant> ..." or "... إلى <merchant> ..."
    final arAtMatch = RegExp(
      r'(?:عند|لدى)\s*(.*?)\s*(?=(?:يوم\s*\d|بتاريخ|في\s*\d|الساعة|بمبلغ|مبلغ|مرجع|للمزيد|\.|$))',
    ).firstMatch(normalizedRaw);

    if (arAtMatch != null) {
      final candidate = _cleanMerchantCandidate(arAtMatch.group(1));
      if (candidate != null) return candidate;
    }

    // English merchant pattern: "... at <merchant> on ..." or "... to <merchant> on ..."
    final enAtMatch = RegExp(
      r'\b(?:at|to|from)\s+(?!amount\b|\d{3,4}\b)([A-Za-z0-9\u0600-\u06FF\s&\x27\-\._]{2,40}?)(?=\s+(?:on\s+\d|at\s+\d|for\s+(?:EGP|SAR|AED|USD)|with\s+amount|Ref\b)|\.|,|$)',
      caseSensitive: false,
    ).firstMatch(normalizedRaw);

    if (enAtMatch != null) {
      final candidate = _cleanMerchantCandidate(enAtMatch.group(1));
      if (candidate != null) return candidate;
    }

    return null;
  }

  static String? _cleanMerchantCandidate(String? rawCandidate) {
    if (rawCandidate == null) return null;
    final collapsed = rawCandidate.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.isEmpty || collapsed.length < 2) return null;
    // Reject bare masked account digits like "5561" or "0140"
    if (RegExp(r'^[xX*\d\s\-]+$').hasMatch(collapsed)) return null;
    return collapsed;
  }

  static String _buildSuggestedNote({
    required String? merchant,
    required String normalizedText,
    required TransactionType type,
  }) {
    if (merchant != null && merchant.isNotEmpty) {
      return merchant;
    }

    final lower = normalizedText.toLowerCase();
    if (lower.contains('ipn') && lower.contains('transfer')) {
      return type == TransactionType.income
          ? 'IPN transfer received'
          : 'IPN transfer';
    }
    if (normalizedText.contains('شبكة المدفوعات اللحظية') ||
        lower.contains('instapay')) {
      return type == TransactionType.income
          ? 'InstaPay transfer'
          : 'InstaPay payment';
    }
    if (lower.contains('atm') || normalizedText.contains('سحب نقدي')) {
      return 'ATM withdrawal';
    }
    if (type == TransactionType.income) {
      return 'Bank credit';
    }
    return 'Bank debit';
  }

  static ({DateTime date, bool hasTime}) _extractDateTime(
    String normalized, {
    required DateTime fallback,
  }) {
    int? month;
    int? day;
    int? year;

    // Pattern 1: Arabic bank format "يوم MM-DD" (e.g. "يوم 10-27") or "DD/MM[/YYYY]"
    final yomMatch = RegExp(r'يوم\s*(\d{1,2})[-/](\d{1,2})').firstMatch(normalized);
    if (yomMatch != null) {
      final first = int.tryParse(yomMatch.group(1) ?? '');
      final second = int.tryParse(yomMatch.group(2) ?? '');
      if (first != null && second != null) {
        // In Arabic "يوم 10-27" -> month=10, day=27; if first > 12 -> day=first, month=second
        if (first <= 12 && second <= 31) {
          month = first;
          day = second;
        } else if (first <= 31 && second <= 12) {
          day = first;
          month = second;
        }
      }
    }

    // Pattern 2: "on DD/MM[/YYYY]" or "DD-MM-YYYY"
    if (month == null || day == null) {
      final dateMatch = RegExp(
        r'\b(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?\b',
      ).firstMatch(normalized);
      if (dateMatch != null) {
        final first = int.tryParse(dateMatch.group(1) ?? '');
        final second = int.tryParse(dateMatch.group(2) ?? '');
        final third = int.tryParse(dateMatch.group(3) ?? '');
        if (first != null && second != null) {
          // Egypt & Arab banks predominantly use DD/MM unless second > 12
          if (second <= 12 && first <= 31) {
            day = first;
            month = second;
          } else if (first <= 12 && second <= 31) {
            month = first;
            day = second;
          }
          if (third != null) {
            year = third < 100 ? 2000 + third : third;
          }
        }
      }
    }

    int hour = fallback.hour;
    int minute = fallback.minute;
    var hasTime = false;

    // Extract time: "الساعة08:58" or "at 03:49 PM" or "20:32" (require standalone AM/PM/ص/م so words like مرجع don't match م)
    final timeMatch = RegExp(
      r'(?:الساعة\s*|at\s+)?(\d{1,2}):(\d{2})(?:\s*(AM|PM|ص|م)(?=\s|$|[.,،]))?',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (timeMatch != null) {
      final parsedHour = int.tryParse(timeMatch.group(1) ?? '');
      final parsedMinute = int.tryParse(timeMatch.group(2) ?? '');
      final period = timeMatch.group(3)?.toUpperCase();
      if (parsedHour != null &&
          parsedMinute != null &&
          parsedHour >= 0 &&
          parsedHour <= 23 &&
          parsedMinute >= 0 &&
          parsedMinute <= 59) {
        hour = parsedHour;
        minute = parsedMinute;
        hasTime = true;
        if (period == 'PM' || period == 'م') {
          if (hour < 12) hour += 12;
        } else if (period == 'AM' || period == 'ص') {
          if (hour == 12) hour = 0;
        }
      }
    }

    if (month != null && day != null && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      var resolvedYear = year ?? fallback.year;
      var candidate = DateTime(resolvedYear, month, day, hour, minute);
      // If year wasn't explicit and candidate is > 7 days in the future relative to fallback,
      // it likely occurred in the previous year (e.g. Oct SMS parsed in Jan).
      if (year == null && candidate.difference(fallback).inDays > 7) {
        candidate = DateTime(resolvedYear - 1, month, day, hour, minute);
      }
      return (date: candidate, hasTime: hasTime);
    }

    if (hasTime) {
      // Time stated but no date: same day as received, at the stated time.
      return (
        date: DateTime(fallback.year, fallback.month, fallback.day, hour, minute),
        hasTime: true,
      );
    }
    return (date: fallback, hasTime: false);
  }
}
