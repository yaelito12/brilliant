abstract class AuthEvent {}

/// Al abrir la app: intenta continuar la sesión anterior.
class AuthIniciada extends AuthEvent {}

class AuthRegistroSolicitado extends AuthEvent {
  final String email;
  final String nombre;
  final String password;
  AuthRegistroSolicitado({
    required this.email,
    required this.nombre,
    required this.password,
  });
}

class AuthLoginSolicitado extends AuthEvent {
  final String email;
  final String password;
  AuthLoginSolicitado({required this.email, required this.password});
}

class AuthLogoutSolicitado extends AuthEvent {}

class AuthBorrarCuentaSolicitado extends AuthEvent {
  final String password;
  AuthBorrarCuentaSolicitado(this.password);
}

/// Quita los mensajes de error/información de la pantalla.
class AuthMensajesLimpiados extends AuthEvent {}
