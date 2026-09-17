import 'zona.dart';

/// Representa una posición física en la cuadrícula del tablero.
class Coordenada {
  final int fila;
  final int columna;

  const Coordenada(this.fila, this.columna);

  @override
  bool operator ==(Object other) =>
      other is Coordenada && other.fila == fila && other.columna == columna;

  @override
  int get hashCode => Object.hash(fila, columna);

  @override
  String toString() => '($fila, $columna)';
}

/// Representa el estado completo del juego en una cuadrícula de 7x7.
class Tablero {
  final int filas;
  final int columnas;
  
  /// Diccionario con todas las zonas del nivel, accesibles por su ID.
  final Map<String, Zona> zonas;
  
  /// Mapeo de qué coordenada pertenece a qué ID de Zona.
  final Map<Coordenada, String> mapeo;

  const Tablero({
    this.filas = 7,
    this.columnas = 7,
    required this.zonas,
    required this.mapeo,
  });

  /// Verifica si una coordenada está dentro de los límites de 7x7.
  bool esCoordenadaValida(Coordenada c) {
    return c.fila >= 0 && c.fila < filas && c.columna >= 0 && c.columna < columnas;
  }

  /// Retorna la Zona correspondiente a una coordenada específica.
  Zona? zonaEn(Coordenada coordenada) {
    if (!esCoordenadaValida(coordenada)) return null;
    
    final zonaId = mapeo[coordenada];
    if (zonaId == null) return null;
    return zonas[zonaId];
  }

  /// Retorna true si todas las zonas han alcanzado su capacidad[cite: 6].
  bool get estaCompleto {
    return zonas.values.every((zona) => zona.estaCompleta);
  }

  /// Intenta agregar un número en una coordenada.
  /// Si la jugada es válida, retorna un nuevo Tablero actualizado.
  /// Si es inválida o está fuera de límites, retorna el mismo Tablero sin cambios.
  Tablero agregarNumero(Coordenada coordenada, int numero) {
    final zona = zonaEn(coordenada);
    
    if (zona == null) return this;

    // Verificamos si la zona permite agregar este número según su Tipo[cite: 5, 6].
    if (zona.puedeAgregar(numero)) {
      final zonaActualizada = zona.agregar(numero);
      
      final nuevasZonas = Map<String, Zona>.from(zonas);
      nuevasZonas[zonaActualizada.id] = zonaActualizada;

      return Tablero(
        filas: filas,
        columnas: columnas,
        zonas: nuevasZonas,
        mapeo: mapeo,
      );
    }
    
    return this; 
  }
}