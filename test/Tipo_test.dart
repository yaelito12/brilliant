import 'package:flutter_test/flutter_test.dart';
import '../lib/tipo.dart';

void main() {
  group('TipoVerde', () {
    final tipo = TipoVerde();

    test('acepta cualquier número en un bloque vacío', () {
      expect(tipo.esPosibleAgregar([], 5), isTrue);
    });

    test('acepta un número distinto a los ya existentes', () {
      expect(tipo.esPosibleAgregar([1, 2, 3], 9), isTrue);
    });

    test('puntuaciones tiene los 3 lugares definidos', () {
      expect(tipo.puntuaciones, {1: 4, 2: 3, 3: 2});
    });
  });

  group('TipoAzul', () {
    final tipo = TipoAzul();

    test('bloque vacío siempre acepta el primer número', () {
      expect(tipo.esPosibleAgregar([], 5), isTrue);
    });

    test('acepta el número si es igual al único número ya puesto', () {
      expect(tipo.esPosibleAgregar([3], 3), isTrue);
    });

    test('rechaza el número si es distinto al único número ya puesto', () {
      expect(tipo.esPosibleAgregar([3], 7), isFalse);
    });

    test('rechaza el número aunque coincida con algunos, si no son todos iguales', () {
      expect(tipo.esPosibleAgregar([4, 4, 6], 4), isFalse);
    });

    test('puntuaciones tiene los 3 lugares definidos', () {
      expect(tipo.puntuaciones, {1: 7, 2: 5, 3: 3});
    });
  });

  group('TipoMorado', () {
    final tipo = TipoMorado();

    test('permite colocar un número cuando la lista está vacía', () {
      expect(tipo.esPosibleAgregar([], 4), isTrue);
    });

    test('permite un segundo número diferente', () {
      expect(tipo.esPosibleAgregar([4], 5), isTrue);
    });

    test('no permite un tercer número diferente', () {
      expect(tipo.esPosibleAgregar([4, 5], 2), isFalse);
    });

    test('permite repetir el primero o el segundo número ya usados', () {
      expect(tipo.esPosibleAgregar([4, 5, 4, 5], 4), isTrue);
      expect(tipo.esPosibleAgregar([4, 5, 4, 5], 5), isTrue);
    });

    test('puntuaciones tiene los 3 lugares definidos', () {
      expect(tipo.puntuaciones, {1: 6, 2: 4, 3: 2});
    });
  });

  group('TipoRojo', () {
    final tipo = TipoRojo();

    test('lista vacía siempre permite insertar', () {
      expect(tipo.esPosibleAgregar([], 5), isTrue);
    });

    test('rechaza el número si ya está en la lista', () {
      expect(tipo.esPosibleAgregar([1, 2, 3], 2), isFalse);
    });

    test('rechaza si la lista original ya tenía duplicados', () {
      expect(tipo.esPosibleAgregar([1, 2, 2, 3], 9), isFalse);
    });

    test('puntuaciones tiene los 3 lugares definidos', () {
      expect(tipo.puntuaciones, {1: 6, 2: 4, 3: 2});
    });
  });

  group('TipoAmarillo', () {
    final tipo = TipoAmarillo();

    test('lista vacía siempre permite insertar', () {
      expect(tipo.esPosibleAgregar([], 5), isTrue);
    });

    test('rechaza el número si ya está en la lista', () {
      expect(tipo.esPosibleAgregar([1, 2, 3], 2), isFalse);
    });

    test('puntuaciones tiene los 3 lugares definidos', () {
      expect(tipo.puntuaciones, {1: 8, 2: 6, 3: 4});
    });
  });
}