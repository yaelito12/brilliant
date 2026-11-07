import 'nivel.dart';
import 'niveles.dart';
import 'tablero.dart';

/// Reglas de un turno, sin estado. Las usan la app (para marcar jugadas
/// posibles) y el servidor (para validar las jugadas del multijugador), así
/// ambos aplican exactamente las mismas reglas.
///
/// Regla de colocación: el ancla es una casilla con número igual a uno de
/// los dados; el otro dado se coloca en una casilla vacía vecina (arriba,
/// abajo, izquierda o derecha) cuya zona acepte ese número.

/// Valor que se coloca si el ancla tiene [valorAncla]: el del otro dado.
int otroDado(List<int> dados, int valorAncla) =>
    valorAncla == dados[0] ? dados[1] : dados[0];

/// Casillas vacías vecinas de [ancla] donde la zona acepta [numero].
Set<Coordenada> destinosPosibles(
  Tablero tablero,
  Map<Coordenada, int> celdas,
  Coordenada ancla,
  int numero,
) {
  return tablero
      .vecinos(ancla)
      .where((c) => !celdas.containsKey(c))
      .where((c) => tablero.zonaEn(c)?.puedeAgregar(numero) ?? false)
      .toSet();
}

/// Casillas con número igual a un dado que tienen al menos un destino válido.
Set<Coordenada> anclasPosibles(
  Tablero tablero,
  Map<Coordenada, int> celdas,
  List<int> dados,
) {
  return celdas.entries
      .where((e) => dados.contains(e.value))
      .where(
        (e) => destinosPosibles(tablero, celdas, e.key, otroDado(dados, e.value))
            .isNotEmpty,
      )
      .map((e) => e.key)
      .toSet();
}

/// true si con [dados] se puede usar [ancla] para poner un número en [destino].
/// Devuelve el número que se colocaría, o null si la jugada no es válida.
int? numeroDeJugada(
  Tablero tablero,
  Map<Coordenada, int> celdas,
  List<int> dados,
  Coordenada ancla,
  Coordenada destino,
) {
  final valorAncla = celdas[ancla];
  if (valorAncla == null || !dados.contains(valorAncla)) return null;
  final numero = otroDado(dados, valorAncla);
  return destinosPosibles(tablero, celdas, ancla, numero).contains(destino)
      ? numero
      : null;
}

/// Revisa los 6 números iniciales que pone el jugador antes de empezar:
/// uno en cada casilla inicial del nivel, del 1 al 6, sin repetir, y que la
/// zona de cada casilla lo acepte. Devuelve el error o null si están bien.
String? errorEnValoresIniciales(Nivel nivel, Map<Coordenada, int> valores) {
  if (valores.length != nivel.casillasIniciales.length ||
      !valores.keys.every(nivel.casillasIniciales.contains)) {
    return 'Hay que poner un número en cada casilla inicial.';
  }
  if (valores.values.any((n) => n < 1 || n > 6)) {
    return 'Los números iniciales van del 1 al 6.';
  }
  if (valores.values.toSet().length != valores.length) {
    return 'Los números iniciales no se pueden repetir.';
  }
  var tablero = nivel.construirTablero();
  for (final MapEntry(key: c, value: n) in valores.entries) {
    if (!(tablero.zonaEn(c)?.puedeAgregar(n) ?? false)) {
      return 'La zona de la casilla $c no acepta el $n.';
    }
    tablero = tablero.agregarNumero(c, n);
  }
  return null;
}

/// Nivel oficial con ese número, o null si no existe.
Nivel? nivelPorNumero(int numero) {
  for (final n in nivelesOficiales) {
    if (n.numero == numero) return n;
  }
  return null;
}
