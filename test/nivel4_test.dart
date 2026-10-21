import 'package:flutter_test/flutter_test.dart';
import 'package:brilliant/nivel4.dart';
import 'package:brilliant/niveles.dart';
import 'package:brilliant/tablero.dart';
import 'package:brilliant/tipo.dart';

void main() {
  group('Nivel 4', () {
    final tablero = construirTableroNivel4();

    Set<Coordenada> casillasDe(String id) => tablero.mapeo.entries
        .where((e) => e.value == id)
        .map((e) => e.key)
        .toSet();

    test('es el cuarto y último mapa oficial', () {
      expect(nivelesOficiales, hasLength(4));
      expect(nivelesOficiales.last, same(nivel4));
      expect(nivel4.nombre, 'Nivel 4');
      expect(nivel4.casillasIniciales, casillasInicialesNivel4);
    });

    test('es de 7x7 y todas las casillas pertenecen a una zona', () {
      for (var f = 0; f < 7; f++) {
        for (var c = 0; c < 7; c++) {
          expect(tablero.zonaEn(Coordenada(f, c)), isNotNull,
              reason: 'casilla ($f, $c) sin zona');
        }
      }
    });

    group('Zonas', () {
      test('la fila de arriba es naranja 4-6 y la de abajo naranja 1-3', () {
        expect(tablero.zonas['na']!.tipo, isA<TipoNaranjaAlto>());
        expect(tablero.zonas['nb']!.tipo, isA<TipoNaranjaBajo>());
        expect(casillasDe('na'), {for (var c = 0; c < 7; c++) Coordenada(0, c)});
        expect(casillasDe('nb'), {for (var c = 0; c < 7; c++) Coordenada(6, c)});
      });

      test('las amarillas son los 6 extremos de las filas 1, 3 y 5', () {
        expect(casillasDe('am'), {
          for (final f in [1, 3, 5]) ...[Coordenada(f, 0), Coordenada(f, 6)],
        });
      });

      test('las verdes son 4 y forman una sola zona', () {
        expect(casillasDe('ve'), {
          const Coordenada(1, 3),
          const Coordenada(3, 1),
          const Coordenada(3, 5),
          const Coordenada(5, 3),
        });
      });

      test('la morada es la cruz del centro de 7 casillas', () {
        expect(tablero.zonas['mo']!.capacidad, 7);
        expect(casillasDe('mo'), contains(const Coordenada(3, 3)));
      });

      test('hay 2 zonas rojas de 6 casillas', () {
        expect(tablero.zonas['ro1']!.capacidad, 6);
        expect(tablero.zonas['ro2']!.capacidad, 6);
      });

      test('la azul tiene 6 casillas', () {
        expect(tablero.zonas['az']!.capacidad, 6);
      });
    });

    group('Puntos de la hoja del nivel 4', () {
      Map<int, int> puntosDe(String id) => tablero.zonas[id]!.tipo.puntuaciones;

      test('amarillo y azul 8-6-4, morado 7-5-3', () {
        expect(puntosDe('am'), {1: 8, 2: 6, 3: 4});
        expect(puntosDe('az'), {1: 8, 2: 6, 3: 4});
        expect(puntosDe('mo'), {1: 7, 2: 5, 3: 3});
      });

      test('rojo 6-4-2, verde 3-2-1 y naranjas 6-4-3', () {
        expect(puntosDe('ro1'), {1: 6, 2: 4, 3: 2});
        expect(puntosDe('ve'), {1: 3, 2: 2, 3: 1});
        expect(puntosDe('na'), {1: 6, 2: 4, 3: 3});
        expect(puntosDe('nb'), {1: 6, 2: 4, 3: 3});
      });

      test('la naranja de arriba rechaza un 2', () {
        expect(
          identical(tablero.agregarNumero(const Coordenada(0, 0), 2), tablero),
          isTrue,
        );
      });

      test('llenar la naranja de abajo con 1-3 da 6 puntos', () {
        var t = tablero;
        for (var c = 0; c < 7; c++) {
          t = t.agregarNumero(Coordenada(6, c), c % 3 + 1);
        }
        expect(t.zonas['nb']!.estaCompleta, isTrue);
        expect(t.puntuacion, 6);
      });
    });

    group('Casillas iniciales', () {
      test('son 6, cada una en una zona distinta', () {
        expect(casillasInicialesNivel4, hasLength(6));
        final zonas =
            casillasInicialesNivel4.map((c) => tablero.zonaEn(c)!.id).toSet();
        expect(zonas, hasLength(6));
      });

      test('una cae en cada naranja', () {
        final zonas =
            casillasInicialesNivel4.map((c) => tablero.zonaEn(c)!.id).toSet();
        expect(zonas, containsAll(['na', 'nb']));
      });

      test('admiten del 1 al 6 sin repetir respetando las naranjas', () {
        final valores = {
          const Coordenada(0, 4): 5,
          const Coordenada(2, 2): 4,
          const Coordenada(2, 5): 6,
          const Coordenada(3, 0): 1,
          const Coordenada(5, 4): 2,
          const Coordenada(6, 1): 3,
        };
        expect(valores.keys.toSet(), casillasInicialesNivel4);
        var t = tablero;
        valores.forEach((c, n) {
          final siguiente = t.agregarNumero(c, n);
          expect(identical(siguiente, t), isFalse, reason: 'rechazó $c');
          t = siguiente;
        });
      });
    });
  });
}
