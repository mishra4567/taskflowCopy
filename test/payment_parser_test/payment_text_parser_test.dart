// test/payment_text_parser_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/services/spend/payment_text_parser.dart';

// What ML Kit would plausibly read from the PhonePe receipt, one row per
// line. Compare with the real output ("Show scanned text") and adjust if
// it differs.
const phonePeReceipt = '''
Transaction Successful
09:19 am on 16 Oct 2026
Paid to
MONALISHA DAS MANNA
₹20
dipanwitamanna313@oksbi
Sent to
: G Pay • dipanwitamanna313@oksbi
Transfer Details
Transaction ID
T2610160919450441352177
Debited from
priya4567
₹20
UTR: 374497160333
Powered by
UPI AXIS BANK
''';

void main() {
  test('PhonePe receipt', () {
    final p = PaymentTextParser.parse(phonePeReceipt);
    expect(p.amountPaise, 2000);
    expect(p.payee, 'Monalisha Das Manna');
    expect(p.paidAt, DateTime(2026, 10, 16, 9, 19));
    expect(p.upiRef, '374497160333');
    // Not GPay, even though "G Pay" appears in the recipient's row.
    expect(p.method, 'PhonePe');
    expect(p.looksUnsuccessful, isFalse);
    expect(p.isConfident, isTrue);
  });

  test('name and amount read as one row', () {
    final p = PaymentTextParser.parse(
      phonePeReceipt.replaceFirst(
        'MONALISHA DAS MANNA\n₹20',
        'MONALISHA DAS MANNA ₹20',
      ),
    );
    expect(p.payee, 'Monalisha Das Manna');
    expect(p.amountPaise, 2000);
    expect(p.isConfident, isTrue);
  });

  test('rupee sign misread as punctuation or dropped', () {
    final misread = PaymentTextParser.parse(
      phonePeReceipt.replaceAll('₹20', '%20'),
    );
    expect(misread.amountPaise, 2000);
    final dropped = PaymentTextParser.parse(
      phonePeReceipt.replaceAll('₹20', '20'),
    );
    expect(dropped.amountPaise, 2000);
  });

  test('misread rupee sign glued to the name is not auto-saved', () {
    final p = PaymentTextParser.parse(
      phonePeReceipt
          .replaceFirst('MONALISHA DAS MANNA\n₹20', 'MONALISHA DAS MANNA %20')
          .replaceAll('₹20', '%20'),
    );
    expect(p.payee, contains('20')); // the amount stuck to the name
    expect(p.isConfident, isFalse); // so it goes to the confirm sheet
  });

  test('failed receipt is never confident', () {
    final p = PaymentTextParser.parse(
      phonePeReceipt.replaceFirst(
        'Transaction Successful',
        'Transaction Failed',
      ),
    );
    expect(p.looksUnsuccessful, isTrue);
    expect(p.isConfident, isFalse);
  });

  test('money received', () {
    final p = PaymentTextParser.parse('''
Transaction Successful
11:05 am on 17 Oct 2026
Received from
RAVI KUMAR
₹500
UTR: 123456789012
''');
    expect(p.direction, 'received');
    expect(p.amountPaise, 50000);
    expect(p.payee, 'Ravi Kumar'); // who paid you
    expect(p.upiRef, '123456789012');
    expect(p.paidAt, DateTime(2026, 10, 17, 11, 5));
  });

  test('a paid receipt stays "paid"', () {
    expect(PaymentTextParser.parse(phonePeReceipt).direction, 'paid');
  });
}
