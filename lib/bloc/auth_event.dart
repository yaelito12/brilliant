abstract class AuthEvent {}

/// Al abrir la app: intenta continuar la sesión anterior.
class AuthIniciada extends AuthEvent {}

class AuthRegistroSolicitado extends AuthEvent {
  final String nametag;
  final String password;
  AuthRegistroSolicitado({required this.nametag, required this.password});
}

class AuthLoginSolicitado extends AuthEvent {
  final String nametag;
  final String password;
  AuthLoginSolicitado({required this.nametag, required this.password});
}

class AuthLogoutSolicitado extends AuthEvent {}

class AuthBorrarCuentaSolicitado extends AuthEvent {
  final String password;
  AuthBorrarCuentaSolicitado(this.password);
}

/// Quita los mensajes de error/información de la pantalla.
class AuthMensajesLimpiados extends AuthEvent {}
