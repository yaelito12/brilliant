import 'package:flutter_test/flutter_test.dart';
import 'package:brilliant/nivel.dart';
import 'package:brilliant/nivel2.dart';
import 'package:brilliant/niveles.dart';
import 'package:brilliant/tablero.dart';
import 'package:brilliant/tipo.dart';

void main() {
  group('tableroDesdeFilas', () {
    final tablero = tableroDesdeFilas(
      {'a': TipoVerde(), 'b': TipoRojo()},
      [
        ['a', 'a', 'b'],
        ['b', 'a', 'b'],
      ],
    );

    test('toma el tamaño de las filas', () {
      expect(tablero.filas, 2);
      expect(tablero.columnas, 3);
    });

    test('cada casilla queda en la zona escrita', () {
      expect(tablero.zonaEn(const Coordenada(0, 0))!.id, 'a');
      expect(tablero.zonaEn(const Coordenada(0, 2))!.id, 'b');
      expect(tablero.zonaEn(const Coordenada(1, 0))!.id, 'b');
    });

    test('la capacidad de cada zona es su cantidad de casillas', () {
      expect(tablero.zonas['a']!.capacidad, 3);
      expect(tablero.zonas['b']!.capacidad, 3);
    });

    test('cada zona tiene el tipo indicado', () {
      expect(tablero.zonas['a']!.tipo, isA<TipoVerde>());
      expect(tablero.zonas['b']!.tipo, isA<TipoRojo>());
    });
  });

  group('Nivel 2', () {
    final tablero = construirTableroNivel2();

    test('es el segundo mapa oficial', () {
      expect(nivelesOficiales[1], same(nivel2));
      expect(nivel2.nombre, 'Nivel 2');
      expect(nivel2.casillasIniciales, casillasInicialesNivel2);
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

    test('empieza vacío, sin puntos', () {
      expect(tablero.zonas.values.every((z) => z.valores.isEmpty), isTrue);
      expect(tablero.puntuacion, 0);
    });

    group('Zonas', () {
      int cuantas<T extends Tipo>() =>
          tablero.zonas.values.where((z) => z.tipo is T).length;

      Set<Coordenada> casillasDe(String id) => tablero.mapeo.entries
          .where((e) => e.value == id)
          .map((e) => e.key)
          .toSet();

      test('hay 1 amarilla, 1 gris y 2 de cada otro color', () {
        expect(tablero.zonas, hasLength(10));
        expect(cuantas<TipoAmarillo>(), 1);
        expect(cuantas<TipoGris>(), 1);
        expect(cuantas<TipoAzul>(), 2);
        expect(cuantas<TipoMorado>(), 2);
        expect(cuantas<TipoRojo>(), 2);
        expect(cuantas<TipoVerde>(), 2);
      });

      test('la zona gris son las 2 casillas blancas del centro', () {
        expect(casillasDe('gr'), {
          const Coordenada(0, 3),
          const Coordenada(6, 3),
        });
      });

      test('la zona amarilla son 5 casillas sueltas', () {
        expect(casillasDe('am'), {
          const Coordenada(1, 1),
          const Coordenada(1, 5),
          const Coordenada(3, 3),
          const Coordenada(5, 1),
          const Coordenada(5, 5),
        });
      });

      test('las rojas tienen 6 casillas y las demás 5', () {
        for (final zona in tablero.zonas.values) {
          final esperada = switch (zona.tipo) {
            TipoRojo() => 6,
            TipoGris() => 2,
            _ => 5,
          };
          expect(zona.capacidad, esperada, reason: 'zona ${zona.id}');
        }
      });
    });

    group('Puntos de la hoja del nivel 2', () {
      Map<int, int> puntosDe(String id) => tablero.zonas[id]!.tipo.puntuaciones;

      test('amarillo da 6-4-2 (en el nivel 1 da 8-6-4)', () {
        expect(puntosDe('am'), {1: 6, 2: 4, 3: 2});
      });

      test('gris da 3-2-1', () {
        expect(puntosDe('gr'), {1: 3, 2: 2, 3: 1});
      });

      test('azul 7-5-3, verde 4-3-2, morado y rojo 6-4-2', () {
        expect(puntosDe('az1'), {1: 7, 2: 5, 3: 3});
        expect(puntosDe('ve2'), {1: 4, 2: 3, 3: 2});
        expect(puntosDe('mo1'), {1: 6, 2: 4, 3: 2});
        expect(puntosDe('ro2'), {1: 6, 2: 4, 3: 2});
      });

      test('llenar la zona gris con números iguales da 3 puntos', () {
        var t = tablero.agregarNumero(const Coordenada(0, 3), 5);
        expect(t.puntuacion, 0);
        t = t.agregarNumero(const Coordenada(6, 3), 5);
        expect(t.zonas['gr']!.estaCompleta, isTrue);
        expect(t.puntuacion, 3);
      });

      test('la zona gris rechaza un número distinto', () {
        final t = tablero.agregarNumero(const Coordenada(0, 3), 5);
        expect(identical(t.agregarNumero(const Coordenada(6, 3), 4), t),
            isTrue);
      });
    });

    group('Casillas iniciales', () {
      test('son 6, cada una en una zona distinta', () {
        expect(casillasInicialesNivel2, hasLength(6));
        final zonas =
            casillasInicialesNivel2.map((c) => tablero.zonaEn(c)!.id).toSet();
        expect(zonas, hasLength(6));
      });

      test('se pueden poner los números del 1 al 6 sin romper reglas', () {
        var t = tablero;
        var numero = 1;
        for (final c in casillasInicialesNivel2) {
          final siguiente = t.agregarNumero(c, numero++);
          expect(identical(siguiente, t), isFalse, reason: 'rechazó $c');
          t = siguiente;
        }
      });
    });
  });
}
