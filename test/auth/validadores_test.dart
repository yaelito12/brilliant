import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/auth/validadores.dart';

void main() {
  test('correo', () {
    expect(validarEmail(''), isNotNull);
    expect(validarEmail('sin-arroba'), isNotNull);
    expect(validarEmail('a@b'), isNotNull);
    expect(validarEmail('a b@c.com'), isNotNull);
    expect(validarEmail(' ana@example.com '), isNull);
  });

  test('nombre', () {
    expect(validarNombre(''), isNotNull);
    expect(validarNombre('A'), isNotNull);
    expect(validarNombre('A' * 31), isNotNull);
    expect(validarNombre('Ana'), isNull);
  });

  test('contraseña nueva: entre 10 y 128 caracteres', () {
    expect(validarPasswordNueva(''), isNotNull);
    expect(validarPasswordNueva('123456789'), isNotNull);
    expect(validarPasswordNueva('1234567890'), isNull);
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
