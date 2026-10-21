import 'package:flutter_test/flutter_test.dart';
import 'package:brilliant/tipo.dart';

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

  group('TipoGris', () {
    final tipo = TipoGris();

    test('bloque vacío siempre acepta el primer número', () {
      expect(tipo.esPosibleAgregar([], 2), isTrue);
    });

    test('acepta el número si es igual a los ya puestos', () {
      expect(tipo.esPosibleAgregar([2], 2), isTrue);
    });

    test('rechaza un número distinto a los ya puestos', () {
      expect(tipo.esPosibleAgregar([2], 5), isFalse);
    });

    test('puntuaciones por defecto son 3, 2 y 1', () {
      expect(tipo.puntuaciones, {1: 3, 2: 2, 3: 1});
    });
  });

  group('TipoNaranjaBajo (1-3)', () {
    final tipo = TipoNaranjaBajo();

    test('acepta del 1 al 3, aunque se repitan', () {
      for (var n = 1; n <= 3; n++) {
        expect(tipo.esPosibleAgregar([], n), isTrue, reason: '$n');
      }
      expect(tipo.esPosibleAgregar([2, 2], 2), isTrue);
    });

    test('rechaza del 4 al 6', () {
      for (var n = 4; n <= 6; n++) {
        expect(tipo.esPosibleAgregar([], n), isFalse, reason: '$n');
      }
    });

    test('describe su rango', () {
      expect(tipo.minimo, 1);
      expect(tipo.maximo, 3);
      expect(tipo.descripcion, 'Solo números del 1 al 3');
    });

    test('puntuaciones por defecto son 6, 4 y 3', () {
      expect(tipo.puntuaciones, {1: 6, 2: 4, 3: 3});
    });
  });

  group('TipoNaranjaAlto (4-6)', () {
    final tipo = TipoNaranjaAlto();

    test('acepta del 4 al 6, aunque se repitan', () {
      for (var n = 4; n <= 6; n++) {
        expect(tipo.esPosibleAgregar([], n), isTrue, reason: '$n');
      }
      expect(tipo.esPosibleAgregar([5, 5], 5), isTrue);
    });

    test('rechaza del 1 al 3', () {
      for (var n = 1; n <= 3; n++) {
        expect(tipo.esPosibleAgregar([], n), isFalse, reason: '$n');
      }
    });

    test('describe su rango', () {
      expect(tipo.descripcion, 'Solo números del 4 al 6');
    });

    test('las dos naranjas comparten color', () {
      expect(tipo.color, TipoNaranjaBajo().color);
    });
  });

  group('Puntos por nivel', () {
    test('puntos() arma el mapa del 1º, 2º y 3º lugar', () {
      expect(puntos(6, 4, 2), {1: 6, 2: 4, 3: 2});
    });

    test('sin puntos del nivel se usan los del color', () {
      expect(TipoAmarillo().puntosNivel, isNull);
      expect(TipoAmarillo().puntuaciones, TipoAmarillo().puntuacionesBase);
    });

    test('los puntos del nivel reemplazan a los del color', () {
      final tipo = TipoAmarillo(puntos(6, 4, 2));
      expect(tipo.puntuaciones, {1: 6, 2: 4, 3: 2});
      expect(tipo.puntuacionesBase, {1: 8, 2: 6, 3: 4});
    });

    test('los puntos del nivel no cambian la regla del color', () {
      final tipo = TipoAzul(puntos(8, 6, 4));
      expect(tipo.esPosibleAgregar([3], 3), isTrue);
      expect(tipo.esPosibleAgregar([3], 4), isFalse);
    });
  });
}