import 'package:brilliant/auth/auth_api.dart';
import 'package:brilliant/auth/auth_models.dart';
import 'package:brilliant/auth/auth_repository.dart';
import 'package:brilliant/auth/token_storage.dart';

const usuarioAna = Usuario(id: 'u1', nametag: 'Ana');

Sesion sesion({int n = 1, int expiresIn = 900}) => Sesion(
  accessToken: 'access-$n',
  refreshToken: 'refresh-$n',
  expiresIn: expiresIn,
  usuario: usuarioAna,
);

AuthException errorApi(int status, String code, [String msg = 'msg']) =>
    AuthException(status: status, code: code, message: msg);

/// API falsa: cada operación se programa con un closure y se anotan las llamadas.
class FakeApi extends AuthApi {
  FakeApi() : super(baseUrl: 'http://fake');

  final llamadas = <String>[];
  Future<Sesion> Function()? onRegistro;
  Future<Sesion> Function()? onLogin;
  Future<Sesion> Function(String refresh)? onRefresh;
  Future<void> Function()? onLogout;
  Future<void> Function(String token, String password)? onBorrar;

  /// Comprobación de sesión (GET /account/me). Por defecto, sesión abierta.
  Future<Usuario> Function(String token)? onYo;

  @override
  Future<Usuario> yo(String accessToken) {
    llamadas.add('yo:$accessToken');
    return (onYo ?? (_) async => usuarioAna)(accessToken);
  }

  @override
  Future<Sesion> registrar({
    required String nametag,
    required String password,
  }) {
    llamadas.add('registrar');
    return onRegistro!();
  }

  @override
  Future<Sesion> iniciarSesion({
    required String nametag,
    required String password,
  }) {
    llamadas.add('login');
    return onLogin!();
  }

  @override
  Future<Sesion> refrescar(String refreshToken) {
    llamadas.add('refrescar:$refreshToken');
    return onRefresh!(refreshToken);
  }

  @override
  Future<void> cerrarSesion(String refreshToken) {
    llamadas.add('logout:$refreshToken');
    return (onLogout ?? () async {})();
  }

  @override
  Future<void> borrarCuenta({
    required String accessToken,
    required String password,
  }) {
    llamadas.add('borrar:$accessToken');
    return onBorrar!(accessToken, password);
  }
}

/// Repositorio con API y almacén falsos.
({AuthRepository repo, FakeApi api, MemoryTokenStorage almacen, Reloj reloj})
crearRepo() {
  final api = FakeApi();
  final almacen = MemoryTokenStorage();
  final reloj = Reloj();
  final repo = AuthRepository(api: api, almacen: almacen, ahora: reloj.call);
  return (repo: repo, api: api, almacen: almacen, reloj: reloj);
}

class Reloj {
  DateTime ahora = DateTime(2026, 1, 1);
  DateTime call() => ahora;
  void avanzar(Duration d) => ahora = ahora.add(d);
}
