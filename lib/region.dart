/// Representa cada uno de los 5 bloques de color del tablero.
///
/// Cada región tiene su propia regla para aceptar números:
/// - [amarillo] y [rojo]: usan `insertarMantieneDistintos` (no se
///   permiten números repetidos dentro del bloque).
/// - [verde]: usa `insertarBloqueVerde` (acepta cualquier número).
/// - [azul]: usa `insertarBloqueAzul` (todos los números deben ser iguales).
/// - [morado]: usa `puedeColocar` (acepta hasta 2 números distintos).
enum Region {
  amarillo,
  verde,
  azul,
  morado,
  rojo,
}
