import 'package:flutter_test/flutter_test.dart';
import '../lib/lista_distintos.dart';

void main() {
  group('insertarMantieneDistintos', () {
    test('lista vacía siempre permite insertar sin duplicar', () {
      expect(insertarMantieneDistintos([], 5), isTrue);
    });

    test('retorna true cuando el número no está en la lista', () {
      expect(insertarMantieneDistintos([1, 2, 3], 4), isTrue);
    });

    test('retorna false cuando el número ya está en la lista', () {
      expect(insertarMantieneDistintos([1, 2, 3], 2), isFalse);
    });

    test('funciona correctamente con números negativos', () {
      expect(insertarMantieneDistintos([-3, -1, 0, 2], -5), isTrue);
      expect(insertarMantieneDistintos([-3, -1, 0, 2], -1), isFalse);
    });

    test('retorna false si el número tese repite al final de la lista', () {
      expect(insertarMantieneDistintos([10, 20, 30, 40], 40), isFalse);
    });

    test('lista con un solo elemento igual al número da false', () {
      expect(insertarMantieneDistintos([7], 7), isFalse);
    });

    test('lista con un solo elemento distinto al número da true', () {
      expect(insertarMantieneDistintos([7], 9), isTrue);
    });

    test(
      'si la lista original ya tiene duplicados, retorna false '
      'aunque el número nuevo no se repita',
      () {
        expect(insertarMantieneDistintos([1, 2, 2, 3], 9), isFalse);
      },
    );

    test('lista con muchos elementos distintos y número nuevo', () {
      expect(
        insertarMantieneDistintos([1, 2, 3, 4, 5, 6, 7, 8, 9], 100),
        isTrue,
      );
    });
  });
}