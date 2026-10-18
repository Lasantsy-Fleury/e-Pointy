import 'package:flutter_test/flutter_test.dart';
import 'package:mipointy/core/utils.dart';

void main() {
  group('Utils', () {
    test('matriculeFromCell preserves text zeros', () {
      expect(matriculeFromCell('00123'), '00123');
    });

    test('matriculeFromCell converts numbers but drops trailing .0', () {
      expect(matriculeFromCell(123), '123');
      expect(matriculeFromCell(123.0), '123');
    });

    test('searchKey ignores diacritics and case', () {
      expect(searchKey('Rakoto Jean'), searchKey('RAKOTO JEAN'));
      expect(searchKey('Mégane'), 'megane');
    });

    test('removeDiacritics', () {
      expect(removeDiacritics('Élève Àùç'), 'Eleve Auc');
    });

    test('normalizeName trims and collapses spaces', () {
      expect(normalizeName('  Jean   Marie  '), 'Jean Marie');
    });

    test('percentLabel', () {
      expect(percentLabel(84), '84 %');
    });
  });
}
