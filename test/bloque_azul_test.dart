import 'package:flutter_test/flutter_test.dart';
import '../lib/bloque_azul.dart';

void main() {
  group('insertarBloqueAzul', () {
    test('bloque vacío siempre acepta el primer número', () {
      expect(insertarBloqueAzul([], 5), isTrue);
    });

    test('acepta el número si es igual al único número ya puesto', () {
      expect(insertarBloqueAzul([3], 3), isTrue);
    });

    test('rechaza el número si es distinto al único número ya puesto', () {
      expect(insertarBloqueAzul([3], 7), isFalse);
    });

    test('acepta el número si todos los del bloque ya son iguales a él', () {
      expect(insertarBloqueAzul([4, 4, 4], 4), isTrue);
    });

    test('rechaza el número aunque coincida con algunos, si no son todos iguales', () {
      expect(insertarBloqueAzul([4, 4, 6], 4), isFalse);
    });

    test('acepta el número mínimo de dado (1) si coincide', () {
      expect(insertarBloqueAzul([1, 1], 1), isTrue);
    });

    test('acepta el número máximo de dado (6) si coincide', () {
      expect(insertarBloqueAzul([6, 6], 6), isTrue);
    });

    test('rechaza si el número de dado no coincide con el resto', () {
      expect(insertarBloqueAzul([5, 5], 2), isFalse);
    });
  });
}