import 'package:flutter_test/flutter_test.dart';
import '../lib/cell.dart';
import '../lib/region.dart';
import '../lib/extraer_valores.dart';

void main() {
  group('extraerValoresDeBloque', () {
    test('regresa lista vacía si el tablero está vacío', () {
      expect(extraerValoresDeBloque([], Region.verde), isEmpty);
    });

    test('regresa lista vacía si no hay celdas de esa región', () {
      final tablero = [
        Cell(fila: 0, columna: 0, region: Region.azul, valor: 4),
        Cell(fila: 0, columna: 1, region: Region.morado, valor: 3),
      ];

      expect(extraerValoresDeBloque(tablero, Region.verde), isEmpty);
    });

    test('extrae solo los valores de la región pedida', () {
      final tablero = [
        Cell(fila: 0, columna: 0, region: Region.verde, valor: 2),
        Cell(fila: 0, columna: 1, region: Region.azul, valor: 4),
        Cell(fila: 1, columna: 0, region: Region.verde, valor: 6),
      ];

      expect(extraerValoresDeBloque(tablero, Region.verde), [2, 6]);
    });

    test('respeta el orden en que aparecen las celdas en el tablero', () {
      final tablero = [
        Cell(fila: 0, columna: 0, region: Region.rojo, valor: 5),
        Cell(fila: 2, columna: 3, region: Region.rojo, valor: 1),
        Cell(fila: 1, columna: 1, region: Region.rojo, valor: 3),
      ];

      expect(extraerValoresDeBloque(tablero, Region.rojo), [5, 1, 3]);
    });

    test('funciona para cada una de las 5 regiones', () {
      final tablero = [
        Cell(fila: 0, columna: 0, region: Region.amarillo, valor: 1),
        Cell(fila: 0, columna: 1, region: Region.verde, valor: 2),
        Cell(fila: 0, columna: 2, region: Region.azul, valor: 3),
        Cell(fila: 0, columna: 3, region: Region.morado, valor: 4),
        Cell(fila: 0, columna: 4, region: Region.rojo, valor: 5),
      ];

      expect(extraerValoresDeBloque(tablero, Region.amarillo), [1]);
      expect(extraerValoresDeBloque(tablero, Region.verde), [2]);
      expect(extraerValoresDeBloque(tablero, Region.azul), [3]);
      expect(extraerValoresDeBloque(tablero, Region.morado), [4]);
      expect(extraerValoresDeBloque(tablero, Region.rojo), [5]);
    });

    test('incluye celdas con el mismo valor repetido en la región', () {
      final tablero = [
        Cell(fila: 0, columna: 0, region: Region.azul, valor: 6),
        Cell(fila: 0, columna: 1, region: Region.azul, valor: 6),
        Cell(fila: 0, columna: 2, region: Region.azul, valor: 6),
      ];

      expect(extraerValoresDeBloque(tablero, Region.azul), [6, 6, 6]);
    });
  });
}
