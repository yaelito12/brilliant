/// Determina si al insertar [numero] en [numeros], todos los elementos
/// de la lista resultante serían diferentes entre sí (sin duplicados).
///
/// Reglas:
/// - Si [numero] ya existe en [numeros], retorna `false`.
/// - Si [numeros] ya contiene duplicados internos (antes de insertar),
///   retorna `false`, porque la lista resultante tampoco tendría
///   todos los elementos distintos.
/// - En cualquier otro caso, retorna `true`.
bool insertarMantieneDistintos(List<int> numeros, int numero) {
  // Si el número ya está en la lista, al insertarlo se repetiría.
  if (numeros.contains(numero)) {
    return false;
  }

  // Si la lista original ya tenía duplicados, nunca serán "todos distintos".
  final unicos = numeros.toSet();
  if (unicos.length != numeros.length) {
    return false;
  }

  return true;
}