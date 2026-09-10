
/// Reglas del bloque azul: solo puede recibir números iguales.
/// - Si el bloque está vacío, cualquier número es válido.
/// - Si el bloque ya tiene números, todos deben ser iguales entre sí
///   Y además deben ser iguales al [numero] que se quiere insertar.
bool insertarBloqueAzul(List<int> numeros, int numero) {
  if (numeros.isEmpty) {
    return true;
  }

  final primero = numeros.first;
  final yaSonTodosIguales = numeros.every((n) => n == primero);

  return yaSonTodosIguales && primero == numero;
}