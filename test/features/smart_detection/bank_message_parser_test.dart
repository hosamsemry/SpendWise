import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/smart_detection/domain/bank_message_parser.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';

void main() {
  group('BankMessageParser', () {
    test('parses Arabic InstaPay debit alert with empty merchant after عند', () {
      const msg =
          'تم خصم مبلغ 357.00 جم لحظيا باستخدام (شبكة المدفوعات اللحظية) من حسابكم رقم 0140 عند  يوم 10-27 الساعة08:58 مرجع التاجر 1607694422,1607 للمزيد اتصل بـ 19623.';

      final parsed = BankMessageParser.parse(
        msg,
        receivedAt: DateTime(2026, 11, 20, 12, 0),
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, TransactionType.expense);
      expect(parsed.amount, const Money.fromMinorUnits(35700));
      expect(parsed.referenceId, '1607694422,1607');
      expect(parsed.suggestedNote, 'InstaPay payment');
      expect(parsed.transactionDate.month, 10);
      expect(parsed.transactionDate.day, 27);
      expect(parsed.transactionDate.hour, 8);
      expect(parsed.transactionDate.minute, 58);
      expect(parsed.transactionDate.year, 2026);
    });

    test('parses Arabic InstaPay debit alert and extracts Arabic merchant name', () {
      const msg =
          'تم خصم مبلغ 515.00 جم لحظيا باستخدام (شبكة المدفوعات اللحظية) من حسابكم رقم 0140 عند كهرباء جنوب القاهرة يوم 10-29 الساعة20:32 مرجع التاجر 1613746459 للمزيد اتصل بـ 19623.';

      final parsed = BankMessageParser.parse(
        msg,
        receivedAt: DateTime(2026, 11, 20, 12, 0),
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, TransactionType.expense);
      expect(parsed.amount, const Money.fromMinorUnits(51500));
      expect(parsed.suggestedNote, 'كهرباء جنوب القاهرة');
      expect(parsed.merchantKey, 'كهرباء جنوب القاهرة');
      expect(parsed.referenceId, '1613746459');
      expect(parsed.transactionDate.month, 10);
      expect(parsed.transactionDate.day, 29);
      expect(parsed.transactionDate.hour, 20);
      expect(parsed.transactionDate.minute, 32);
    });

    test('parses English IPN transfer sent alert with 12h AM/PM time and Ref#', () {
      const msg =
          'IPN transfer sent with amount of EGP 100.01 from 5561 on 18/11 at 03:49 PM. Ref# 18369757. For more details call 19700.';

      final parsed = BankMessageParser.parse(
        msg,
        receivedAt: DateTime(2026, 11, 20, 12, 0),
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, TransactionType.expense);
      expect(parsed.amount, const Money.fromMinorUnits(10001));
      expect(parsed.suggestedNote, 'IPN transfer');
      expect(parsed.referenceId, '18369757');
      expect(parsed.transactionDate.day, 18);
      expect(parsed.transactionDate.month, 11);
      expect(parsed.transactionDate.hour, 15);
      expect(parsed.transactionDate.minute, 49);
    });

    test('parses Arabic and English income alerts and Eastern Arabic digits', () {
      const arIncome =
          'تم إضافة مبلغ ٢٬٥٠٠٫٧٥ جم إلى حسابكم تحويل وارد. رقم المرجع 991122';
      final parsedAr = BankMessageParser.parse(arIncome);
      expect(parsedAr, isNotNull);
      expect(parsedAr!.type, TransactionType.income);
      expect(parsedAr.amount, const Money.fromMinorUnits(250075));
      expect(parsedAr.referenceId, '991122');

      const enIncome =
          'IPN transfer received with amount of EGP 1,250.00 Ref# 778899.';
      final parsedEn = BankMessageParser.parse(enIncome);
      expect(parsedEn, isNotNull);
      expect(parsedEn!.type, TransactionType.income);
      expect(parsedEn.amount, const Money.fromMinorUnits(125000));
    });

    test('ignores OTPs, declined alerts, and non-financial messages', () {
      expect(
        BankMessageParser.parse(
          'Your OTP is 458291 for EGP 500.00 purchase. Do not share this code.',
        ),
        isNull,
      );
      expect(
        BankMessageParser.parse(
          'رمز التحقق الخاص بك هو 884422 لعملية بمبلغ 300.00 جم. لا تشارك الرمز.',
        ),
        isNull,
      );
      expect(
        BankMessageParser.parse(
          'Transaction declined at Carrefour for EGP 240.00 due to insufficient funds.',
        ),
        isNull,
      );
      expect(
        BankMessageParser.parse('Hey! Call me when you get home at 8:00 PM'),
        isNull,
      );
    });

    test('extracts amounts followed by Arabic currency suffixes', () {
      final cases = {
        'تم سحب 500 جنيه من حسابك رقم 1234': 50000,
        'تم خصم 515.00 جم من بطاقتك المنتهية 9876': 51500,
        'تم خصم 250 ريال من بطاقتك': 25000,
        'تم إيداع 1,200 جنيهات في حسابك': 120000,
        'تم خصم 75 درهم من بطاقتك': 7500,
      };
      cases.forEach((msg, minor) {
        final parsed = BankMessageParser.parse(msg);
        expect(parsed, isNotNull, reason: msg);
        expect(parsed!.amount, Money.fromMinorUnits(minor), reason: msg);
      });
    });

    test('does not treat a currency token embedded in a longer word as currency', () {
      // "LEarn" must not be read as the LE (Egyptian pound) suffix.
      expect(BankMessageParser.parse('Paid 20 LEarning credits today'), isNull);
    });

    group('strict mode (SMS apps that also carry personal messages)', () {
      const personal = [
        'I paid 200 EGP for dinner, send me your share',
        'Mom: I sent 1000 EGP to Ali today',
        'You paid EGP 85.50 for your trip',
        'Netflix: payment of \$9.99 is due on 12/05',
        'Salah transferred for \$150 million to Al Hilal',
        'You received EGP 50 cashback! Shop now',
        'دفعت 300 جنيه في العشا امبارح',
      ];
      const bank = [
        'Your card ending 1234 was debited with EGP 350.00 at Carrefour on 20/11 Ref# 998877',
        'IPN transfer sent with amount of EGP 100.01 from 5561 on 18/11 at 03:49 PM. Ref# 18369757.',
        'تم خصم مبلغ 515.00 جم لحظيا باستخدام (شبكة المدفوعات اللحظية) من حسابكم رقم 0140 عند كهرباء جنوب القاهرة يوم 10-29 الساعة20:32 مرجع التاجر 1613746459',
        'تم إضافة 2,500.00 جنيه إلى حسابك رقم 4455. رصيدك الحالي 7,000.00 جنيه',
        'SAR 120 credited to your account ****7788. Avl bal SAR 3,400',
      ];

      for (final msg in personal) {
        test('rejects personal/non-bank text: $msg', () {
          expect(BankMessageParser.parse(msg, strict: true), isNull);
        });
      }

      for (final msg in bank) {
        test('accepts bank alert: ${msg.substring(0, 30)}…', () {
          expect(BankMessageParser.parse(msg, strict: true), isNotNull);
        });
      }

      test('requires a currency-anchored amount, not just "مبلغ <n>"', () {
        const msg = 'تم خصم مبلغ 300 من حسابكم رقم 0140';
        expect(BankMessageParser.parse(msg), isNotNull);
        expect(BankMessageParser.parse(msg, strict: true), isNull);
      });
    });
  });

  group('BankMessageParser amount extraction', () {
    final when = DateTime(2026, 11, 10, 12);
    Money? amountOf(String text, {bool strict = false}) =>
        BankMessageParser.parse(text, receivedAt: when, strict: strict)?.amount;

    test('"LE" inside a word is not a currency', () {
      for (final strict in [false, true]) {
        expect(
          amountOf('Your card ending 1234 was charged at APPLE 12 STORE for EGP 300.00', strict: strict),
          Money.fromMajorUnits(300),
        );
        expect(amountOf('Purchase at TABLE 5 CAFE EGP 85.50 card 4321', strict: strict), Money.parse('85.50'));
      }
    });

    test('a bad first match does not hide the real amount', () {
      expect(
        amountOf('Transfer sent to MOBILE 01001234567 with amount EGP 200 Ref 9988'),
        Money.fromMajorUnits(200),
      );
    });

    test('a balance mentioned first is not taken as the amount', () {
      expect(
        amountOf('Avl bal EGP 12,000.00. Your account was debited with EGP 500.00'),
        Money.fromMajorUnits(500),
      );
      expect(
        amountOf('رصيدك 9,000 ج.م. تم خصم 250 ج.م من بطاقتك رقم 1234'),
        Money.fromMajorUnits(250),
      );
    });

    test('a lone balance amount is still used when nothing else is found', () {
      expect(
        amountOf('Your account 1234 was credited. Available balance EGP 700'),
        Money.fromMajorUnits(700),
      );
    });
  });
}
