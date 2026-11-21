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
  });
}
