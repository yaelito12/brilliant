import 'package:flutter_test/flutter_test.dart';
import 'package:brilliant/tablero.dart';
import 'package:brilliant/zona.dart';
import 'package:brilliant/tipo.dart';
import 'package:brilliant/nivel1.dart';

void main() {
  group('Tablero 7x7 - Pruebas de Integración con Reglas de Zonas', () {
    late Tablero tablero;
    
    late Zona zonaAmarilla;
    late Zona zonaVerde;
    late Zona zonaAzul;
    late Zona zonaMorada;
    late Zona zonaRoja;

    setUp(() {
      zonaAmarilla = Zona(id: 'z_amarilla', tipo: TipoAmarillo(), capacidad: 2);
      zonaVerde = Zona(id: 'z_verde', tipo: TipoVerde(), capacidad: 2);
      zonaAzul = Zona(id: 'z_azul', tipo: TipoAzul(), capacidad: 2);
      zonaMorada = Zona(id: 'z_morado', tipo: TipoMorado(), capacidad: 3);
      zonaRoja = Zona(id: 'z_roja', tipo: TipoRojo(), capacidad: 2);

      tablero = Tablero(
        filas: 7,
        columnas: 7,
        zonas: {
          'z_amarilla': zonaAmarilla,
          'z_verde': zonaVerde,
          'z_azul': zonaAzul,
          'z_morado': zonaMorada,
          'z_roja': zonaRoja,
        },
        mapeo: {
          const Coordenada(0, 0): 'z_amarilla',
          const Coordenada(1, 0): 'z_verde',
          const Coordenada(2, 0): 'z_azul',
          const Coordenada(3, 0): 'z_morado',
          const Coordenada(4, 0): 'z_roja',
        },
      );
    });

    test('esCoordenadaValida respeta los límites de 7x7', () {
      expect(tablero.esCoordenadaValida(const Coordenada(0, 0)), isTrue);
      expect(tablero.esCoordenadaValida(const Coordenada(6, 6)), isTrue);
      
      expect(tablero.esCoordenadaValida(const Coordenada(-1, 0)), isFalse);
      expect(tablero.esCoordenadaValida(const Coordenada(0, 7)), isFalse);
    });

    group('Reglas por Color desde el Tablero', () {
      
      test('AMARILLO: El tablero rechaza el movimiento si el número se repite', () {
        // Primero metemos un 5 en la zona amarilla (jugada válida)
        var t1 = tablero.agregarNumero(const Coordenada(0, 0), 5);
        expect(t1.zonas['z_amarilla']?.valores, [5]);

        // Luego intentamos meter otro 5 (jugada inválida para el amarillo)
        var t2 = t1.agregarNumero(const Coordenada(0, 0), 5);
        
        // El tablero debe retornar la misma instancia intacta (t1), ignorando el nuevo 5
        expect(identical(t1, t2), isTrue);
      });

      test('AZUL: El tablero rechaza el movimiento si el número es diferente', () {
        var t1 = tablero.agregarNumero(const Coordenada(2, 0), 3); // Primer número
        
        // Intentamos meter un 4 (inválido porque en azul todos deben ser iguales al 3)
        var t2 = t1.agregarNumero(const Coordenada(2, 0), 4);
        
        expect(identical(t1, t2), isTrue); // Movimiento ignorado
      });

      test('MORADO: El tablero rechaza un tercer número diferente', () {
        var t1 = tablero.agregarNumero(const Coordenada(3, 0), 1);
        var t2 = t1.agregarNumero(const Coordenada(3, 0), 2);
        
        // Intentamos meter un 3 (inválido porque morado permite máximo 2 distintos)
        var t3 = t2.agregarNumero(const Coordenada(3, 0), 3);
        
        expect(identical(t2, t3), isTrue); // Movimiento ignorado
      });

      test('ROJO: El tablero rechaza el movimiento si el número se repite', () {
        var t1 = tablero.agregarNumero(const Coordenada(4, 0), 8);
        
        // Intentamos meter otro 8 (inválido porque rojo exige todos distintos)
        var t2 = t1.agregarNumero(const Coordenada(4, 0), 8);
        
        expect(identical(t1, t2), isTrue); // Movimiento ignorado
      });

      test('LÍMITE DE CAPACIDAD: El tablero rechaza si la zona ya está llena (ej. Verde)', () {
        // La zona verde tiene capacidad: 2. Metemos 2 números.
        var t1 = tablero.agregarNumero(const Coordenada(1, 0), 1);
        var t2 = t1.agregarNumero(const Coordenada(1, 0), 2);
        
        expect(t2.zonas['z_verde']?.estaCompleta, isTrue);

        // Intentamos meter un TERCER número (inválido porque ya llegó a capacidad 2)
        var t3 = t2.agregarNumero(const Coordenada(1, 0), 3);
        
        expect(identical(t2, t3), isTrue); // Movimiento ignorado
      });
      
    });

    group('Puntuación por zona', () {
      // 3 zonas rojas y 2 verdes de una casilla cada una
      Tablero tableroDePrueba() => Tablero(
            zonas: {
              for (final id in ['r1', 'r2', 'r3'])
                id: Zona(id: id, tipo: TipoRojo(), capacidad: 1),
              for (final id in ['v1', 'v2'])
                id: Zona(id: id, tipo: TipoVerde(), capacidad: 1),
            },
            mapeo: {
              const Coordenada(0, 0): 'r1',
              const Coordenada(0, 1): 'r2',
              const Coordenada(0, 2): 'r3',
              const Coordenada(1, 0): 'v1',
              const Coordenada(1, 1): 'v2',
            },
          );

      test('dos zonas verdes dan 4 cada una (8 en total, no 4 + 3)', () {
        var t = tableroDePrueba();

        t = t.agregarNumero(const Coordenada(1, 0), 1);
        expect(t.puntosDe('v1'), 4);
        expect(t.puntuacion, 4);

        t = t.agregarNumero(const Coordenada(1, 1), 1);
        expect(t.puntosDe('v2'), 4);
        expect(t.puntuacion, 8);
      });

      test('cada zona roja da 6 aunque ya haya otras rojas llenas', () {
        var t = tableroDePrueba();
        for (var c = 0; c < 3; c++) {
          t = t.agregarNumero(Coordenada(0, c), 1);
        }

        expect(t.puntosDe('r1'), 6);
        expect(t.puntosDe('r2'), 6);
        expect(t.puntosDe('r3'), 6);
        expect(t.puntuacion, 18);
      });

      test('tablero de juego: la zona amarilla solo puntúa al llenar sus 5 casillas', () {
        var t = construirTableroNivel1();
        final amarillas = [
          const Coordenada(0, 0),
          const Coordenada(0, 6),
          const Coordenada(3, 3),
          const Coordenada(6, 0),
          const Coordenada(6, 6),
        ];

        for (var i = 0; i < 4; i++) {
          t = t.agregarNumero(amarillas[i], i + 1);
        }
        expect(t.puntuacion, 0);

        // Las amarillas no pueden repetir número entre ellas
        expect(identical(t.agregarNumero(amarillas[4], 1), t), isTrue);

        t = t.agregarNumero(amarillas[4], 5);
        expect(t.zonas['am']!.estaCompleta, isTrue);
        expect(t.puntuacion, 8);
      });

      test('zonas de distinto color suman sus puntos', () {
        var t = tableroDePrueba();
        t = t.agregarNumero(const Coordenada(0, 0), 1); // rojo: 6
        t = t.agregarNumero(const Coordenada(1, 0), 1); // verde: 4

        expect(t.puntuacion, 10);
      });
    });

    group('Vecinos y casillas', () {
      test('una esquina tiene 2 vecinos', () {
        expect(
          tablero.vecinos(const Coordenada(0, 0)).toSet(),
          {const Coordenada(1, 0), const Coordenada(0, 1)},
        );
      });

      test('un borde tiene 3 vecinos', () {
        expect(tablero.vecinos(const Coordenada(0, 3)), hasLength(3));
      });

      test('una casilla del centro tiene 4 vecinos (sin diagonales)', () {
        expect(
          tablero.vecinos(const Coordenada(3, 3)).toSet(),
          {
            const Coordenada(2, 3),
            const Coordenada(4, 3),
            const Coordenada(3, 2),
            const Coordenada(3, 4),
          },
        );
      });

      test('zonaEn devuelve null fuera del tablero o en casillas sin zona', () {
        expect(tablero.zonaEn(const Coordenada(-1, 0)), isNull);
        expect(tablero.zonaEn(const Coordenada(6, 6)), isNull); // sin mapear
        expect(tablero.zonaEn(const Coordenada(0, 0))?.id, 'z_amarilla');
      });

      test('agregar en una casilla sin zona no cambia el tablero', () {
        expect(
          identical(tablero.agregarNumero(const Coordenada(6, 6), 3), tablero),
          isTrue,
        );
      });

      test('agregarNumero no modifica el tablero original', () {
        tablero.agregarNumero(const Coordenada(1, 0), 4);
        expect(tablero.zonas['z_verde']!.valores, isEmpty);
      });
    });

    group('Fin del tablero y orden de zonas', () {
      test('ordenCompletadas guarda las zonas en el orden en que se llenan', () {
        var t = tablero.agregarNumero(const Coordenada(1, 0), 1); // verde 1/2
        expect(t.ordenCompletadas, isEmpty);

        t = t.agregarNumero(const Coordenada(4, 0), 1); // roja 1/2
        t = t.agregarNumero(const Coordenada(4, 0), 2); // roja completa
        t = t.agregarNumero(const Coordenada(1, 0), 2); // verde completa
        expect(t.ordenCompletadas, ['z_roja', 'z_verde']);
      });

      test('estaCompleto solo es true cuando todas las zonas están llenas', () {
        var t = Tablero(
          zonas: {'v': Zona(id: 'v', tipo: TipoVerde(), capacidad: 2)},
          mapeo: {const Coordenada(0, 0): 'v'},
        );
        expect(t.estaCompleto, isFalse);
        t = t.agregarNumero(const Coordenada(0, 0), 1);
        expect(t.estaCompleto, isFalse);
        t = t.agregarNumero(const Coordenada(0, 0), 2);
        expect(t.estaCompleto, isTrue);
      });

      test('una zona incompleta no da puntos', () {
        final t = tablero.agregarNumero(const Coordenada(1, 0), 1);
        expect(t.puntosDe('z_verde'), 0);
        expect(t.puntuacion, 0);
      });
    });
  });
}
