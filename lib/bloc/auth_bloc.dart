import 'dart:async';

import 'package:bloc/bloc.dart';

import '../auth/auth_models.dart';
import '../auth/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;

  /// Cada cuánto se comprueba con el servidor que la sesión siga abierta
  /// mientras hay sesión (null = nunca; así las pruebas no dejan timers).
  /// Con esto, si se entra con la cuenta en otro dispositivo, este se entera
  /// en menos de ese tiempo aunque no esté haciendo nada.
  final Duration? verificarCada;
  Timer? _verificacion;

  AuthBloc(this._repo, {this.verificarCada}) : super(const AuthState.desconocido()) {
    on<AuthSesionCerrada>(_onSesionCerrada);
    on<AuthSesionVerificada>(_onVerificar);
    on<AuthIniciada>(_onIniciada);
    on<AuthRegistroSolicitado>(_onRegistro);
    on<AuthLoginSolicitado>(_onLogin);
    on<AuthLogoutSolicitado>(_onLogout);
    on<AuthBorrarCuentaSolicitado>(_onBorrarCuenta);
    on<AuthMensajesLimpiados>((_, emit) => emit(state.sinMensajes()));
  }

  @override
  void onChange(Change<AuthState> change) {
    super.onChange(change);
    // La revisión periódica corre solo mientras hay sesión.
    final cada = verificarCada;
    final conSesion = change.nextState.estado == AuthEstado.autenticado;
    if (conSesion && cada != null && _verificacion == null) {
      _verificacion = Timer.periodic(cada, (_) => add(AuthSesionVerificada()));
    } else if (!conSesion) {
      _verificacion?.cancel();
      _verificacion = null;
    }
  }

  Future<void> _onSesionCerrada(AuthSesionCerrada e, Emitter<AuthState> emit) async {
    if (state.estado != AuthEstado.autenticado) return;
    await _repo.cerrarSesionLocal();
    emit(AuthState.noAutenticado(info: e.mensaje));
  }

  Future<void> _onVerificar(AuthSesionVerificada e, Emitter<AuthState> emit) async {
    if (state.estado != AuthEstado.autenticado || state.cargando) return;
    try {
      await _repo.verificarSesion();
    } on AuthException catch (ex) {
      if (!ex.esSesionInvalida || state.estado != AuthEstado.autenticado) return;
      emit(AuthState.noAutenticado(
        info: ex.esSesionReemplazada ? mensajeSesionReemplazada : mensajeSesionVencida,
      ));
    } catch (_) {
      // Sin red u otro error pasajero: se reintenta en la próxima revisión.
    }
  }

  @override
  Future<void> close() {
    _verificacion?.cancel();
    return super.close();
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
      if (ex.esSesionReemplazada) {
        emit(const AuthState.noAutenticado(info: mensajeSesionReemplazada));
        return;
      }
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
