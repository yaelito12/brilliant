bool puedeColocar(List<int> numeros, int numero) {
  // Si todavía no hay números, se puede colocar cualquiera
  if (numeros.isEmpty) {
    return true;
  }

  // Obtenemos los números diferentes que ya existen
  Set<int> diferentes = numeros.toSet();

  // Si el número ya está dentro, se puede colocar
  if (diferentes.contains(numero)) {
    return true;
  }

  // Si solamente hay un número diferente,
  // podemos agregar un segundo número
  if (diferentes.length < 2) {
    return true;
  }

  // Ya existen 2 números diferentes y el nuevo
  // sería un tercero
  return false;
}