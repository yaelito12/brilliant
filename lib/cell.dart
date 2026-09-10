import 'region.dart';

/// Representa una celda del tablero como estructura de datos
/// (no un cuadro visual, sino un dato con posición, región y valor).
class Cell {
  final int fila;
  final int columna;
  final Region region;
  final int valor;

  const Cell({
    required this.fila,
    required this.columna,
    required this.region,
    required this.valor,
  });

  @override
  String toString() =>
      'Cell(fila: $fila, columna: $columna, region: $region, valor: $valor)';

  @override
  bool operator ==(Object other) =>
      other is Cell &&
      other.fila == fila &&
      other.columna == columna &&
      other.region == region &&
      other.valor == valor;

  @override
  int get hashCode => Object.hash(fila, columna, region, valor);
}
