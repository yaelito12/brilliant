import 'package:bloc/bloc.dart';

import '../auth/auth_models.dart';
import '../auth/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;

  AuthBloc(this._repo) : super(const AuthState.desconocido()) {
    on<AuthIniciada>(_onIniciada);
    on<AuthRegistroSolicitado>(_onRegistro);
    on<AuthLoginSolicitado>(_onLogin);
    on<AuthLogoutSolicitado>(_onLogout);
    on<AuthBorrarCuentaSolicitado>(_onBorrarCuenta);
    on<AuthMensajesLimpiados>((_, emit) => emit(state.sinMensajes()));
  }

  Future<void> _onIniciada(AuthIniciada e, Emitter<AuthState> emit) async {
    try {
      final usuario = await _repo.restaurarSesion();
      emit(
        usuario == null
            ? const AuthState.noAutenticado()
            : AuthState.autenticado(usuario),
      );
    } on AuthException catch (ex) {
      emit(AuthState.noAutenticado(error: ex.mensajeParaUsuario));
    } catch (_) {
      emit(const AuthState.noAutenticado());
    }
  }

  Future<void> _onRegistro(AuthRegistroSolicitado e, Emitter<AuthState> emit) =>
      _entrar(
        emit,
        () => _repo.registrar(nametag: e.nametag, password: e.password),
      );

  Future<void> _onLogin(AuthLoginSolicitado e, Emitter<AuthState> emit) =>
      _entrar(
        emit,
        () => _repo.iniciarSesion(nametag: e.nametag, password: e.password),
      );

  /// Registro e inicio de sesión comparten el mismo manejo de errores.
  Future<void> _entrar(
    Emitter<AuthState> emit,
    Future<Usuario> Function() accion,
  ) async {
    if (state.cargando) return;
    emit(state.enCarga());
    try {
      emit(AuthState.autenticado(await accion()));
    } on AuthException catch (ex) {
      if (ex.code == 'validacion') {
        emit(AuthState.noAutenticado(errores: ex.campos));
      } else if (ex.code == 'nametag_en_uso') {
        emit(AuthState.noAutenticado(errores: {'nametag': ex.message}));
      } else {
        emit(AuthState.noAutenticado(error: ex.mensajeParaUsuario));
      }
    } catch (_) {
      emit(
        const AuthState.noAutenticado(error: 'Ocurrió un error inesperado.'),
      );
    }
  }

  Future<void> _onLogout(
    AuthLogoutSolicitado e,
    Emitter<AuthState> emit,
  ) async {
    await _repo.cerrarSesion();
    emit(const AuthState.noAutenticado());
  }

  Future<void> _onBorrarCuenta(
    AuthBorrarCuentaSolicitado e,
    Emitter<AuthState> emit,
  ) async {
    final usuario = state.usuario;
    if (usuario == null || state.cargando) return;
    emit(state.enCarga());
    try {
      await _repo.borrarCuenta(e.password);
      emit(const AuthState.noAutenticado(info: 'Tu cuenta fue eliminada.'));
    } on AuthException catch (ex) {
      if (ex.esSesionInvalida) {
        emit(
          const AuthState.noAutenticado(
            info: 'Tu sesión venció. Inicia sesión de nuevo.',
          ),
        );
      } else {
        emit(AuthState.autenticado(usuario, error: ex.mensajeParaUsuario));
      }
    } catch (_) {
      emit(
        AuthState.autenticado(usuario, error: 'Ocurrió un error inesperado.'),
      );
    }
  }
}
