// Validaciones del lado del cliente (comodidad). El servidor repite todas.

String? validarEmail(String? valor) {
  final s = (valor ?? '').trim();
  if (s.isEmpty) return 'Escribe tu correo.';
  if (s.length > 254 || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
    return 'El correo no es válido.';
  }
  return null;
}

String? validarNombre(String? valor) {
  final s = (valor ?? '').trim();
  if (s.isEmpty) return 'Escribe tu nombre.';
  if (s.length < 2) return 'El nombre debe tener al menos 2 caracteres.';
  if (s.length > 30) return 'El nombre no puede pasar de 30 caracteres.';
  return null;
}

/// Contraseña al crear la cuenta.
String? validarPasswordNueva(String? valor) {
  final s = valor ?? '';
  if (s.isEmpty) return 'Escribe una contraseña.';
  if (s.length < 10) return 'Debe tener al menos 10 caracteres.';
  if (s.length > 128) return 'No puede pasar de 128 caracteres.';
  return null;
}

/// Contraseña al iniciar sesión o confirmar un borrado.
String? validarPasswordExistente(String? valor) =>
    (valor ?? '').isEmpty ? 'Escribe tu contraseña.' : null;

String? Function(String?) validarConfirmacion(String Function() password) =>
    (valor) =>
        (valor ?? '') == password() ? null : 'Las contraseñas no coinciden.';
