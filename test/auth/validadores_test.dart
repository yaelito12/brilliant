import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/auth/validadores.dart';

void main() {
  test('nametag al crear la cuenta', () {
    expect(validarNametag(''), isNotNull);
    expect(validarNametag('ab'), isNotNull); // muy corto
    expect(validarNametag('a' * 21), isNotNull); // muy largo
    expect(validarNametag('con espacio'), isNotNull);
    expect(validarNametag('Ánder'), isNotNull); // sin acentos
    expect(validarNametag('<script>'), isNotNull);
    expect(validarNametag('Ana'), isNull);
    expect(validarNametag(' Ana_99.x-y '), isNull);
  });

  test('nametag al iniciar sesión solo exige que no esté vacío', () {
    expect(validarNametagExistente(''), isNotNull);
    expect(validarNametagExistente('   '), isNotNull);
    expect(validarNametagExistente('Ana'), isNull);
  });

  test('contraseña nueva: entre 6 y 128 caracteres', () {
    expect(validarPasswordNueva(''), isNotNull);
    expect(validarPasswordNueva('12345'), isNotNull);
    expect(validarPasswordNueva('123456'), isNull);
    expect(validarPasswordNueva('a' * 129), isNotNull);
  });

  test('contraseña existente solo exige que no esté vacía', () {
    expect(validarPasswordExistente(''), isNotNull);
    expect(validarPasswordExistente('x'), isNull);
  });

  test('confirmación', () {
    final v = validarConfirmacion(() => 'secreta-123');
    expect(v('otra'), isNotNull);
    expect(v('secreta-123'), isNull);
  });
}
