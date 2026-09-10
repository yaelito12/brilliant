import 'cell.dart';
import 'region.dart';

/// Extrae los valores (enteros) de todas las celdas de [tablero]
/// que pertenecen a la región [region].
///
/// [tablero] es la lista plana de todas las celdas del juego, sin
/// importar a qué región pertenezcan. La función recorre cada celda
/// y se queda solo con el [Cell.valor] de aquellas cuya [Cell.region]
/// coincide con [region], respetando el orden en que aparecen en
/// [tablero].
///
/// Ejemplo:
/// ```dart
/// final tablero = [
///   Cell(fila: 0, columna: 0, region: Region.verde, valor: 2),
///   Cell(fila: 0, columna: 1, region: Region.azul, valor: 4),
///   Cell(fila: 1, columna: 0, region: Region.verde, valor: 6),
/// ];
///
/// extraerValoresDeBloque(tablero, Region.verde); // [2, 6]
/// ```
List<int> extraerValoresDeBloque(List<Cell> tablero, Region region) {
  final valores = <int>[];

  for (final celda in tablero) {
    if (celda.region == region) {
      valores.add(celda.valor);
    }
  }

  return valores;
}
