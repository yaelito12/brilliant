import 'package:flutter_test/flutter_test.dart';
import '../lib/zona.dart';
import '../lib/tipo.dart';

void main() {
  group('Zona - estaCompleta', () {
    test('no está completa si tiene menos valores que su capacidad', () {
      final zona = Zona(id: 'z1', tipo: TipoVerde(), capacidad: 5, valores: [1, 2]);
      expect(zona.estaCompleta, isFalse);
    });

    test('está completa si alcanzó su capacidad', () {
      final zona = Zona(id: 'z1', tipo: TipoVerde(), capacidad: 3, valores: [1, 2, 3]);
      expect(zona.estaCompleta, isTrue);
    });

    test('una zona nueva (sin valores) no está completa si capacidad > 0', () {
      final zona = Zona(id: 'z1', tipo: TipoVerde(), capacidad: 4);
      expect(zona.estaCompleta, isFalse);
    });
  });

  group('Zona - puedeAgregar', () {
    test('respeta la regla del tipo', () {
      final zonaAzul = Zona(id: 'z1', tipo: TipoAzul(), capacidad: 5, valores: [3, 3]);
      expect(zonaAzul.puedeAgregar(3), isTrue);
      expect(zonaAzul.puedeAgregar(7), isFalse);
    });

    test('no permite agregar si la zona ya está completa, aunque la regla lo permitiría', () {
      final zonaVerde = Zona(id: 'z1', tipo: TipoVerde(), capacidad: 2, valores: [1, 2]);
      expect(zonaVerde.puedeAgregar(9), isFalse);
    });
  });

  group('Zona - agregar / copyWith', () {
    test('agregar retorna una nueva Zona con el número al final', () {
      final zona = Zona(id: 'z1', tipo: TipoVerde(), capacidad: 5, valores: [1, 2]);
      final actualizada = zona.agregar(9);

      expect(actualizada.valores, [1, 2, 9]);
      expect(zona.valores, [1, 2]); // la original no cambia
    });

    test('copyWith mantiene id, tipo y capacidad si no se especifican', () {
      final zona = Zona(id: 'z1', tipo: TipoMorado(), capacidad: 6, valores: [1]);
      final actualizada = zona.copyWith(valores: [1, 2]);

      expect(actualizada.id, zona.id);
      expect(actualizada.capacidad, zona.capacidad);
      expect(actualizada.tipo, isA<TipoMorado>());
      expect(actualizada.valores, [1, 2]);
    });
  });

  group('Zona - igualdad', () {
    test('dos zonas con los mismos datos son iguales', () {
      final a = Zona(id: 'z1', tipo: TipoRojo(), capacidad: 4, valores: [1, 2]);
      final b = Zona(id: 'z1', tipo: TipoRojo(), capacidad: 4, valores: [1, 2]);
      expect(a, equals(b));
    });

    test('zonas con distintos valores no son iguales', () {
      final a = Zona(id: 'z1', tipo: TipoRojo(), capacidad: 4, valores: [1, 2]);
      final b = Zona(id: 'z1', tipo: TipoRojo(), capacidad: 4, valores: [1, 3]);
      expect(a == b, isFalse);
    });
  });
}