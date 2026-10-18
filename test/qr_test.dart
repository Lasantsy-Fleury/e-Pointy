import 'package:flutter_test/flutter_test.dart';
import 'package:mipointy/services/qr_service.dart';

void main() {
  group('QrService', () {
    test('encode and decode roundtrip', () {
      const sess = 'ABCD1234';
      const stu = 'TST0001';
      final enc = QrService.encodeForStudent(
          sessionToken: sess, studentQrToken: stu);
      expect(enc, 'MPT1|ABCD1234|TST0001');
      final dec = QrService.decode(enc);
      expect(dec, isNotNull);
      expect(dec!.sessionToken, sess);
      expect(dec.studentToken, stu);
    });

    test('decode invalid formats', () {
      expect(QrService.decode(''), isNull);
      expect(QrService.decode('BAD'), isNull);
      expect(QrService.decode('MPT1|onlytwo'), isNull);
      expect(QrService.decode('WRONG|a|b'), isNull);
      expect(QrService.decode('MPT1||b'), isNull);
    });
  });
}
