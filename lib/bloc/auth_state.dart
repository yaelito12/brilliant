import '../auth/auth_models.dart';

enum AuthEstado { desconocido, noAutenticado, autenticado }

class AuthState {
  final AuthEstado estado;
  final Usuario? usuario;

  /// Hay una petición al servidor en curso.
  final bool cargando;

  /// Mensaje de error general (se muestra en un recuadro rojo).
  final String? error;

  /// Errores por campo que mandó el servidor (`nametag`, `password`).
  final Map<String, String> errores;

  /// Aviso informativo (por ejemplo "Tu cuenta fue eliminada.").
  final String? info;

  const AuthState._(
    this.estado, {
    this.usuario,
    this.cargando = false,
    this.error,
    this.errores = const {},
    this.info,
  });

  /// Todavía no se sabe si hay sesión (la app está arrancando).
  const AuthState.desconocido() : this._(AuthEstado.desconocido);

  const AuthState.noAutenticado({
    bool cargando = false,
    String? error,
    Map<String, String> errores = const {},
    String? info,
  }) : this._(
         AuthEstado.noAutenticado,
         cargando: cargando,
         error: error,
         errores: errores,
         info: info,
       );

  const AuthState.autenticado(
    Usuario usuario, {
    bool cargando = false,
    String? error,
  }) : this._(
         AuthEstado.autenticado,
         usuario: usuario,
         cargando: cargando,
         error: error,
       );

  /// Mismo estado pero con una petición en curso y sin mensajes.
  AuthState enCarga() => AuthState._(estado, usuario: usuario, cargando: true);

  /// Mismo estado sin mensajes de error ni información.
  AuthState sinMensajes() => AuthState._(estado, usuario: usuario);

  bool get hayMensajes => error != null || errores.isNotEmpty || info != null;
}
