import 'package:flutter_test/flutter_test.dart';
import 'package:brilliant/nivel3.dart';
import 'package:brilliant/niveles.dart';
import 'package:brilliant/tablero.dart';
import 'package:brilliant/tipo.dart';

void main() {
  group('Nivel 3', () {
    final tablero = construirTableroNivel3();

    Set<Coordenada> casillasDe(String id) => tablero.mapeo.entries
        .where((e) => e.value == id)
        .map((e) => e.key)
        .toSet();

    test('es el tercer mapa oficial', () {
      expect(nivelesOficiales[2], same(nivel3));
      expect(nivel3.nombre, 'Nivel 3');
      expect(nivel3.casillasIniciales, casillasInicialesNivel3);
    });

    test('es de 7x7 y todas las casillas pertenecen a una zona', () {
      expect(tablero.filas, 7);
      expect(tablero.columnas, 7);
      for (var f = 0; f < 7; f++) {
        for (var c = 0; c < 7; c++) {
          expect(tablero.zonaEn(Coordenada(f, c)), isNotNull,
              reason: 'casilla ($f, $c) sin zona');
        }
      }
    });

    group('Zonas', () {
      int cuantas<T extends Tipo>() =>
          tablero.zonas.values.where((z) => z.tipo is T).length;

      test('hay 2 moradas, 2 rojas y 1 de cada otro color', () {
        expect(tablero.zonas, hasLength(8));
        expect(cuantas<TipoMorado>(), 2);
        expect(cuantas<TipoRojo>(), 2);
        expect(cuantas<TipoAmarillo>(), 1);
        expect(cuantas<TipoAzul>(), 1);
        expect(cuantas<TipoVerde>(), 1);
        expect(cuantas<TipoGris>(), 1);
      });

      test('la amarilla une las 2 esquinas de arriba', () {
        expect(casillasDe('am'), {
          const Coordenada(0, 0),
          const Coordenada(0, 1),
          const Coordenada(1, 1),
          const Coordenada(0, 5),
          const Coordenada(0, 6),
          const Coordenada(1, 5),
        });
      });

      test('la gris son las 5 casillas blancas', () {
        expect(casillasDe('gr'), {
          const Coordenada(0, 3),
          const Coordenada(1, 0),
          const Coordenada(1, 6),
          const Coordenada(3, 3),
          const Coordenada(6, 3),
        });
      });

      test('la azul es la fila 4 sin los extremos', () {
        expect(casillasDe('az'), {
          for (var c = 1; c <= 5; c++) Coordenada(4, c),
        });
      });

      test('la verde tiene 9 casillas y la morada de abajo 6', () {
        expect(tablero.zonas['ve']!.capacidad, 9);
        expect(casillasDe('mo2'), {
          for (var c = 0; c < 7; c++)
            if (c != 3) Coordenada(6, c),
        });
      });

      test('la capacidad de cada zona es igual a sus casillas', () {
        for (final zona in tablero.zonas.values) {
          expect(zona.capacidad, casillasDe(zona.id).length,
              reason: 'zona ${zona.id}');
        }
      });
    });

    group('Puntos de la hoja del nivel 3', () {
      Map<int, int> puntosDe(String id) => tablero.zonas[id]!.tipo.puntuaciones;

      test('morado, azul y amarillo dan 7-5-3', () {
        expect(puntosDe('mo1'), {1: 7, 2: 5, 3: 3});
        expect(puntosDe('mo2'), {1: 7, 2: 5, 3: 3});
        expect(puntosDe('az'), {1: 7, 2: 5, 3: 3});
        expect(puntosDe('am'), {1: 7, 2: 5, 3: 3});
      });

      test('rojo 6-4-2, verde 6-5-4 y gris 8-6-4', () {
        expect(puntosDe('ro1'), {1: 6, 2: 4, 3: 2});
        expect(puntosDe('ve'), {1: 6, 2: 5, 3: 4});
        expect(puntosDe('gr'), {1: 8, 2: 6, 3: 4});
      });

      test('llenar la gris con el mismo número da 8 puntos', () {
        var t = tablero;
        for (final c in casillasDe('gr')) {
          t = t.agregarNumero(c, 2);
        }
        expect(t.zonas['gr']!.estaCompleta, isTrue);
        expect(t.puntuacion, 8);
      });

      test('llenar la verde con cualquier número da 6 puntos', () {
        var t = tablero;
        var n = 0;
        for (final c in casillasDe('ve')) {
          t = t.agregarNumero(c, n++ % 6 + 1);
        }
        expect(t.puntuacion, 6);
      });
    });

    group('Casillas iniciales', () {
      test('son 6, cada una en una zona distinta', () {
        expect(casillasInicialesNivel3, hasLength(6));
        final zonas =
            casillasInicialesNivel3.map((c) => tablero.zonaEn(c)!.id).toSet();
        expect(zonas, hasLength(6));
      });

      test('se pueden poner los números del 1 al 6 sin romper reglas', () {
        var t = tablero;
        var numero = 1;
        for (final c in casillasInicialesNivel3) {
          final siguiente = t.agregarNumero(c, numero++);
          expect(identical(siguiente, t), isFalse, reason: 'rechazó $c');
          t = siguiente;
        }
      });
    });
  });
}
