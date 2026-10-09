import 'package:flutter_test/flutter_test.dart';
import 'package:brilliant/nivel1.dart';
import 'package:brilliant/tablero.dart';
import 'package:brilliant/tipo.dart';

void main() {
  group('Tablero de juego', () {
    final tablero = construirTableroNivel1();

    group('Forma del tablero', () {
      test('es de 7x7 y todas las 49 casillas pertenecen a una zona', () {
        expect(tablero.filas, 7);
        expect(tablero.columnas, 7);
        for (var f = 0; f < 7; f++) {
          for (var c = 0; c < 7; c++) {
            expect(tablero.zonaEn(Coordenada(f, c)), isNotNull,
                reason: 'casilla ($f, $c) sin zona');
          }
        }
      });

      test('la capacidad de cada zona es igual a sus casillas', () {
        for (final zona in tablero.zonas.values) {
          final casillas =
              tablero.mapeo.values.where((id) => id == zona.id).length;
          expect(zona.capacidad, casillas, reason: 'zona ${zona.id}');
        }
      });

      test('empieza vacío, sin puntos ni zonas completas', () {
        expect(tablero.zonas.values.every((z) => z.valores.isEmpty), isTrue);
        expect(tablero.puntuacion, 0);
        expect(tablero.ordenCompletadas, isEmpty);
      });
    });

    group('Zonas por color', () {
      int cuantas<T extends Tipo>() =>
          tablero.zonas.values.where((z) => z.tipo is T).length;

      test('hay 1 amarilla y 2 de cada otro color', () {
        expect(cuantas<TipoAmarillo>(), 1);
        expect(cuantas<TipoAzul>(), 2);
        expect(cuantas<TipoMorado>(), 2);
        expect(cuantas<TipoRojo>(), 2);
        expect(cuantas<TipoVerde>(), 2);
      });

      test('la zona amarilla son las 4 esquinas y el centro', () {
        final amarillas = tablero.mapeo.entries
            .where((e) => e.value == 'am')
            .map((e) => e.key)
            .toSet();
        expect(amarillas, {
          const Coordenada(0, 0),
          const Coordenada(0, 6),
          const Coordenada(3, 3),
          const Coordenada(6, 0),
          const Coordenada(6, 6),
        });
      });
    });

    group('Casillas iniciales', () {
      test('son 6', () {
        expect(casillasInicialesNivel1, hasLength(6));
      });

      test('ninguna está en la zona amarilla', () {
        for (final c in casillasInicialesNivel1) {
          expect(tablero.zonaEn(c)!.tipo, isNot(isA<TipoAmarillo>()));
        }
      });

      test('se pueden poner los números del 1 al 6 sin romper reglas', () {
        var t = tablero;
        var numero = 1;
        for (final c in casillasInicialesNivel1) {
          final siguiente = t.agregarNumero(c, numero++);
          expect(identical(siguiente, t), isFalse, reason: 'rechazó $c');
          t = siguiente;
        }
      });
    });
  });
}
