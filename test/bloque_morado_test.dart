
import 'package:flutter_test/flutter_test.dart';
import '../lib/bloque_morado.dart';

bool puedeColocar(List<int> numeros, int numero) {
  if (numeros.isEmpty) {
    return true;
  }

  Set<int> diferentes = numeros.toSet();

  if (diferentes.contains(numero)) {
    return true;
  }

  if (diferentes.length < 2) {
    return true;
  }

  return false;
}

void main() {
  group('Pruebas de la sección morada', () {

    test('Debe permitir colocar un número cuando la lista está vacía', () {
      expect(puedeColocar([], 4), true);
    });

    test('Debe permitir un segundo número diferente', () {
      expect(puedeColocar([4], 5), true);
    });

    test('Debe permitir colocar nuevamente el primer número', () {
      expect(puedeColocar([4, 5], 4), true);
    });

    test('Debe permitir colocar nuevamente el segundo número', () {
      expect(puedeColocar([4, 5], 5), true);
    });

    test('No debe permitir un tercer número diferente', () {
      expect(puedeColocar([4, 5], 2), false);
    });

    test('No debe permitir un tercer número aunque ya haya repetidos', () {
      expect(puedeColocar([4, 5, 4, 5], 6), false);
    });

    test('Debe permitir el primer número después de varios turnos', () {
      expect(puedeColocar([4, 5, 4, 5], 4), true);
    });

    test('Debe permitir el segundo número después de varios turnos', () {
      expect(puedeColocar([4, 5, 4, 5], 5), true);
    });

    test('Debe permitir solamente dos números diferentes', () {
      expect(puedeColocar([2, 2, 2], 5), true);
      expect(puedeColocar([2, 5, 2, 5], 2), true);
      expect(puedeColocar([2, 5, 2, 5], 3), false);
    });
  });
}