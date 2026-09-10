import 'package:flutter_test/flutter_test.dart';
import '../lib/bloque_verde.dart';

void main() {
  group('insertarBloqueVerde', () {
    test('acepta el número en un bloque vacío', () {
      expect(insertarBloqueVerde([], 5), isTrue);
    });

    test('acepta un número igual a los ya existentes', () {
      expect(insertarBloqueVerde([2, 2, 2], 2), isTrue);
    });

    test('acepta un número distinto a los ya existentes', () {
      expect(insertarBloqueVerde([1, 2, 3], 9), isTrue);
    });

    test('acepta cualquier valor dentro del rango de dados (1-6)', () {
      expect(insertarBloqueVerde([1, 3, 5], 6), isTrue);
    });

    test('acepta el número incluso si el bloque ya tiene mezcla de valores', () {
      expect(insertarBloqueVerde([1, 1, 2, 3, 3], 6), isTrue);
    });
  });
}