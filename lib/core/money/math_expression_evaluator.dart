import 'package:money_tracker/core/money/money.dart';

/// Robust arithmetic expression evaluator supporting BODMAS/PEMDAS precedence and parentheses.
class MathExpressionEvaluator {
  const MathExpressionEvaluator._();

  /// Tries to evaluate a mathematical expression (e.g. `10 + 5 * 2`, `(45 + 30) * 2`, `100 - (20 + 15)`).
  ///
  /// Returns a valid positive [Money] instance or `null` if the input is:
  /// - Malformed or contains unmatched parentheses
  /// - Contains division by zero
  /// - Produces a zero or negative final amount
  /// - Exceeds the maximum allowable transaction limit ([Money.maxMajorUnits])
  static Money? tryEvaluate(String input) {
    final normalized = Money.normalizeDigits(input.trim())
        .replaceAll('٫', '.')
        .replaceAll('٬', ',')
        .replaceAll('،', ',');
    if (normalized.isEmpty) return null;

    // Direct money parse if no arithmetic operators or parentheses exist
    if (!normalized.contains('+') &&
        !normalized.contains('-') &&
        !normalized.contains('*') &&
        !normalized.contains('×') &&
        !normalized.contains('/') &&
        !normalized.contains('÷') &&
        !normalized.contains('(') &&
        !normalized.contains(')')) {
      final direct = Money.tryParse(normalized);
      if (direct != null && direct.isPositive && direct.inMajorUnits <= Money.maxMajorUnits) {
        return direct;
      }
      return null;
    }

    try {
      final tokens = _tokenize(normalized);
      if (tokens == null || tokens.isEmpty) return null;

      final rpn = _toRpn(tokens);
      if (rpn == null || rpn.isEmpty) return null;

      final result = _evaluateRpn(rpn);
      if (result == null) return null;

      // Round once, at the end, to whole minor units (half away from zero).
      final minor = result.toMinorUnitsRounded();
      if (minor <= BigInt.zero || minor > BigInt.from(Money.maxMinorUnits)) {
        return null;
      }
      return Money.fromMinorUnits(minor.toInt());
    } catch (_) {
      return null;
    }
  }

  static List<String>? _tokenize(String input) {
    final sanitized = Money.normalizeDigits(input)
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('٫', '.')
        .replaceAll('٬', ',')
        .replaceAll('،', ',');

    // Numbers may carry thousands/decimal separators; each one is resolved
    // individually so `12,5 + 1` is 13.5, not 126.
    final regex = RegExp(r'([+\-*/()])|([0-9][0-9.,]*)');
    final matches = regex.allMatches(sanitized);

    final matchedCharsCount = matches.fold<int>(
      0,
      (prev, m) => prev + (m.group(0)?.length ?? 0),
    );
    final nonWhitespaceCount = sanitized.replaceAll(RegExp(r'\s+'), '').length;
    if (matchedCharsCount != nonWhitespaceCount) {
      return null;
    }

    final tokens = <String>[];
    for (final m in matches) {
      final token = m.group(0)!;
      if (m.group(2) == null) {
        tokens.add(token);
        continue;
      }
      final resolved = Money.normalizeSeparators(token);
      if (resolved == null || double.tryParse(resolved) == null) return null;
      tokens.add(resolved);
    }
    return tokens;
  }

  static int _precedence(String op) {
    if (op == '*' || op == '/') return 2;
    if (op == '+' || op == '-') return 1;
    return 0;
  }

  static List<String>? _toRpn(List<String> tokens) {
    final output = <String>[];
    final opStack = <String>[];

    String? prevToken;

    for (final token in tokens) {
      if (token == '+' || token == '-' || token == '*' || token == '/') {
        if (prevToken == null && (token == '*' || token == '/')) return null;
        if (prevToken != null &&
            (prevToken == '+' ||
                prevToken == '-' ||
                prevToken == '*' ||
                prevToken == '/' ||
                prevToken == '(')) {
          return null;
        }

        while (opStack.isNotEmpty &&
            opStack.last != '(' &&
            _precedence(opStack.last) >= _precedence(token)) {
          output.add(opStack.removeLast());
        }
        opStack.add(token);
      } else if (token == '(') {
        opStack.add(token);
      } else if (token == ')') {
        var foundLeft = false;
        while (opStack.isNotEmpty) {
          final top = opStack.removeLast();
          if (top == '(') {
            foundLeft = true;
            break;
          }
          output.add(top);
        }
        if (!foundLeft) return null;
      } else {
        final val = double.tryParse(token);
        if (val == null) return null;
        output.add(token);
      }
      prevToken = token;
    }

    if (prevToken == '+' || prevToken == '-' || prevToken == '*' || prevToken == '/') {
      return null;
    }

    while (opStack.isNotEmpty) {
      final top = opStack.removeLast();
      if (top == '(' || top == ')') return null;
      output.add(top);
    }

    return output;
  }

  /// Evaluates with exact rational arithmetic, so `2.675 * 1` is exactly
  /// 2.675 (and rounds to 2.68) instead of binary floating point's 2.67499...
  static _Rational? _evaluateRpn(List<String> rpn) {
    final stack = <_Rational>[];

    for (final token in rpn) {
      if (token == '+' || token == '-' || token == '*' || token == '/') {
        if (stack.length < 2) return null;
        final b = stack.removeLast();
        final a = stack.removeLast();
        switch (token) {
          case '+':
            stack.add(a + b);
          case '-':
            stack.add(a - b);
          case '*':
            stack.add(a * b);
          case '/':
            if (b.isZero) return null;
            stack.add(a / b);
        }
      } else {
        final val = _Rational.tryParseDecimal(token);
        if (val == null) return null;
        stack.add(val);
      }
    }

    if (stack.length != 1) return null;
    return stack.single;
  }
}

/// Minimal exact fraction (numerator / positive denominator) for the
/// calculator. Not normalized: values stay small for typed expressions.
class _Rational {
  final BigInt num;
  final BigInt den;

  _Rational(BigInt n, BigInt d)
      : num = d.isNegative ? -n : n,
        den = d.abs();

  /// Parses `123`, `123.45` exactly (no floating point).
  static _Rational? tryParseDecimal(String s) {
    final m = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(s);
    if (m == null) return null;
    final frac = m.group(2) ?? '';
    return _Rational(
      BigInt.parse('${m.group(1)}$frac'),
      BigInt.from(10).pow(frac.length),
    );
  }

  bool get isZero => num == BigInt.zero;

  _Rational operator +(_Rational o) => _Rational(num * o.den + o.num * den, den * o.den);
  _Rational operator -(_Rational o) => _Rational(num * o.den - o.num * den, den * o.den);
  _Rational operator *(_Rational o) => _Rational(num * o.num, den * o.den);
  _Rational operator /(_Rational o) => _Rational(num * o.den, den * o.num);

  /// Value * 100 rounded half away from zero.
  BigInt toMinorUnitsRounded() {
    final scaled = num * BigInt.from(100);
    final q = scaled ~/ den;
    final r = (scaled - q * den).abs();
    if (r * BigInt.two >= den) return scaled.isNegative ? q - BigInt.one : q + BigInt.one;
    return q;
  }
}
