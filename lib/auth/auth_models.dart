/// Datos públicos de la cuenta (el servidor nunca manda la contraseña).
/// El [nametag] es el nombre con el que se inicia sesión y que ven los demás.
class Usuario {
  final String id;
  final String nametag;

  const Usuario({required this.id, required this.nametag});

  factory Usuario.fromJson(Map<String, dynamic> json) =>
      Usuario(id: json['id'] as String, nametag: json['nametag'] as String);

  @override
  bool operator ==(Object other) =>
      other is Usuario && other.id == id && other.nametag == nametag;

  @override
  int get hashCode => Object.hash(id, nametag);
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

  /// Código estable del servidor (`credenciales_invalidas`, `nametag_en_uso`...).
  final String code;
  final String message;

  /// Errores por campo cuando el servidor rechaza los datos (`nametag`, `password`).
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
      code == 'no_autenticado' ||
      esSesionReemplazada;

  /// Se inició sesión con la cuenta en otro dispositivo (solo se permite una
  /// sesión a la vez).
  bool get esSesionReemplazada => code == 'sesion_reemplazada';

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

/// Aviso que ve el dispositivo cuya sesión se cerró porque se entró con la
/// misma cuenta en otro lado.
const mensajeSesionReemplazada =
    'Se inició sesión con tu cuenta en otro dispositivo, así que aquí se cerró. '
    'Solo se puede usar una sesión a la vez.';

const mensajeSesionVencida = 'Tu sesión venció. Inicia sesión de nuevo.';
