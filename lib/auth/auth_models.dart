/// Datos públicos de la cuenta (el servidor nunca manda la contraseña).
class Usuario {
  final String id;
  final String email;
  final String nombre;

  const Usuario({required this.id, required this.email, required this.nombre});

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
    id: json['id'] as String,
    email: json['email'] as String,
    nombre: json['nombre'] as String,
  );

  @override
  bool operator ==(Object other) =>
      other is Usuario &&
      other.id == id &&
      other.email == email &&
      other.nombre == nombre;

  @override
  int get hashCode => Object.hash(id, email, nombre);
}

/// Respuesta del servidor al registrarse, iniciar sesión o renovar.
class Sesion {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final Usuario usuario;

  const Sesion({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.usuario,
  });

  factory Sesion.fromJson(Map<String, dynamic> json) => Sesion(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    expiresIn: json['expiresIn'] as int,
    usuario: Usuario.fromJson(json['user'] as Map<String, dynamic>),
  );
}

/// Error al hablar con el servidor (credenciales malas, sin red, etc.).
class AuthException implements Exception {
  /// Código HTTP; 0 si ni siquiera hubo respuesta.
  final int status;

  /// Código estable del servidor (`credenciales_invalidas`, `email_en_uso`...).
  final String code;
  final String message;

  /// Errores por campo cuando el servidor rechaza los datos (`email`, `password`...).
  final Map<String, String> campos;
  final int? reintentarEnSegundos;

  const AuthException({
    required this.status,
    required this.code,
    required this.message,
    this.campos = const {},
    this.reintentarEnSegundos,
  });

  const AuthException.red()
    : status = 0,
      code = 'sin_conexion',
      message = 'No se pudo conectar con el servidor. Revisa tu conexión.',
      campos = const {},
      reintentarEnSegundos = null;

  const AuthException.sesionExpirada()
    : status = 401,
      code = 'sesion_expirada',
      message = 'Tu sesión venció. Inicia sesión de nuevo.',
      campos = const {},
      reintentarEnSegundos = null;

  /// La sesión ya no sirve (token vencido, revocado o cuenta borrada).
  bool get esSesionInvalida =>
      code == 'refresh_invalido' ||
      code == 'sesion_expirada' ||
      code == 'no_autenticado';

  /// Texto listo para mostrar al usuario.
  String get mensajeParaUsuario {
    final espera = reintentarEnSegundos;
    if (code == 'cuenta_bloqueada' && espera != null) {
      final minutos = (espera / 60).ceil().clamp(1, 1 << 30);
      return 'Demasiados intentos fallidos. Inténtalo de nuevo en '
          '$minutos ${minutos == 1 ? 'minuto' : 'minutos'}.';
    }
    return message;
  }

  @override
  String toString() => 'AuthException($status, $code, $message)';
}
