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
        .replaceAll('،', '')
        .replaceAll('٫', '.');
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
      if (result == null || result <= 0 || result.isNaN || result.isInfinite) {
        return null;
      }

      if (result > Money.maxMajorUnits) {
        return null;
      }

      return Money.fromMajorUnits(result);
    } catch (_) {
      return null;
    }
  }

  static List<String>? _tokenize(String input) {
    final sanitized = Money.normalizeDigits(input)
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll(',', '')
        .replaceAll('،', '')
        .replaceAll('٫', '.');

    final regex = RegExp(r'([+\-*/()])|([0-9]+(?:\.[0-9]+)?)');
    final matches = regex.allMatches(sanitized);

    final matchedCharsCount = matches.fold<int>(
      0,
      (prev, m) => prev + (m.group(0)?.length ?? 0),
    );
    final nonWhitespaceCount = sanitized.replaceAll(RegExp(r'\s+'), '').length;
    if (matchedCharsCount != nonWhitespaceCount) {
      return null;
    }

    return matches.map((m) => m.group(0)!).toList();
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

  static double? _evaluateRpn(List<String> rpn) {
    final stack = <double>[];

    for (final token in rpn) {
      if (token == '+' || token == '-' || token == '*' || token == '/') {
        if (stack.length < 2) return null;
        final b = stack.removeLast();
        final a = stack.removeLast();

        double res;
        switch (token) {
          case '+':
            res = a + b;
            break;
          case '-':
            res = a - b;
            break;
          case '*':
            res = a * b;
            break;
          case '/':
            if (b == 0) return null;
            res = a / b;
            break;
          default:
            return null;
        }
        stack.add(res);
      } else {
        final val = double.tryParse(token);
        if (val == null) return null;
        stack.add(val);
      }
    }

    if (stack.length != 1) return null;
    return stack.single;
  }
}
