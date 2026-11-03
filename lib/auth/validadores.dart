// Validaciones del lado del cliente (comodidad). El servidor repite todas.

/// Nametag al crear la cuenta: 3 a 20 caracteres, solo letras sin acentos,
/// números, punto, guion y guion bajo (sin espacios).
String? validarNametag(String? valor) {
  final s = (valor ?? '').trim();
  if (s.isEmpty) return 'Escribe tu nametag.';
  if (s.length < 3) return 'Debe tener al menos 3 caracteres.';
  if (s.length > 20) return 'No puede pasar de 20 caracteres.';
  if (!RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(s)) {
    return 'Solo letras, números, punto, guion y guion bajo.';
  }
  return null;
}

/// Nametag al iniciar sesión: solo que no esté vacío.
String? validarNametagExistente(String? valor) =>
    (valor ?? '').trim().isEmpty ? 'Escribe tu nametag.' : null;

/// Contraseña al crear la cuenta.
String? validarPasswordNueva(String? valor) {
  final s = valor ?? '';
  if (s.isEmpty) return 'Escribe una contraseña.';
  if (s.length < 6) return 'Debe tener al menos 6 caracteres.';
  if (s.length > 128) return 'No puede pasar de 128 caracteres.';
  return null;
}

/// Contraseña al iniciar sesión o confirmar un borrado.
String? validarPasswordExistente(String? valor) =>
    (valor ?? '').isEmpty ? 'Escribe tu contraseña.' : null;

String? Function(String?) validarConfirmacion(String Function() password) =>
    (valor) =>
        (valor ?? '') == password() ? null : 'Las contraseñas no coinciden.';
