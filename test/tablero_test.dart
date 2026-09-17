import 'package:flutter_test/flutter_test.dart';
import '../lib/tablero.dart';
import '../lib/zona.dart';
import '../lib/tipo.dart';

void main() {
  group('Tablero 7x7', () {
    late Tablero tablero;
    late Zona zonaEsquinaSupIzq;
    late Zona zonaCentro;
    late Zona zonaEsquinaInfDer;

    setUp(() {
      zonaEsquinaSupIzq = Zona(id: 'z_sup_izq', tipo: TipoAmarillo(), capacidad: 1);
      zonaCentro = Zona(id: 'z_centro', tipo: TipoVerde(), capacidad: 3);
      zonaEsquinaInfDer = Zona(id: 'z_inf_der', tipo: TipoAzul(), capacidad: 2);

      // Simulamos partes clave de un tablero 7x7 para los tests
      tablero = Tablero(
        filas: 7,
        columnas: 7,
        zonas: {
          'z_sup_izq': zonaEsquinaSupIzq,
          'z_centro': zonaCentro,
          'z_inf_der': zonaEsquinaInfDer,
        },
        mapeo: {
          const Coordenada(0, 0): 'z_sup_izq', // Esquina superior izquierda
          const Coordenada(3, 3): 'z_centro',  // Centro del tablero 7x7
          const Coordenada(3, 4): 'z_centro',  
          const Coordenada(6, 6): 'z_inf_der', // Esquina inferior derecha
        },
      );
    });

    test('esCoordenadaValida respeta los límites de 7x7', () {
      expect(tablero.esCoordenadaValida(const Coordenada(0, 0)), isTrue);
      expect(tablero.esCoordenadaValida(const Coordenada(6, 6)), isTrue);
      
      // Fuera de límites
      expect(tablero.esCoordenadaValida(const Coordenada(-1, 0)), isFalse);
      expect(tablero.esCoordenadaValida(const Coordenada(0, 7)), isFalse);
      expect(tablero.esCoordenadaValida(const Coordenada(7, 0)), isFalse);
    });

    test('zonaEn retorna null si la coordenada está fuera de los límites de 7x7', () {
      expect(tablero.zonaEn(const Coordenada(7, 7)), isNull);
    });

    test('zonaEn retorna la zona correcta dentro de los límites', () {
      expect(tablero.zonaEn(const Coordenada(0, 0))?.id, 'z_sup_izq');
      expect(tablero.zonaEn(const Coordenada(3, 3))?.id, 'z_centro');
      expect(tablero.zonaEn(const Coordenada(6, 6))?.id, 'z_inf_der');
    });

    group('Operaciones de juego en 7x7', () {
      test('agregarNumero actualiza la zona correcta y mantiene inmutabilidad', () {
        // Jugamos en el centro
        final nuevoTablero = tablero.agregarNumero(const Coordenada(3, 3), 5);

        // Tablero original intacto
        expect(tablero.zonas['z_centro']?.valores, isEmpty);

        // Nuevo tablero modificado
        expect(nuevoTablero.zonas['z_centro']?.valores, [5]);
        // Las demás zonas del 7x7 no cambian
        expect(nuevoTablero.zonas['z_sup_izq']?.valores, isEmpty);
      });

      test('ignora la jugada si se intenta jugar fuera del 7x7', () {
        final tableroIntacto = tablero.agregarNumero(const Coordenada(7, 7), 2);
        
        // Debe retornar exactamente la misma instancia
        expect(identical(tablero, tableroIntacto), isTrue);
      });

      test('estaCompleto valida todas las zonas mapeadas', () {
        expect(tablero.estaCompleto, isFalse);

        final tableroLleno = Tablero(
          zonas: {
            'z_sup_izq': zonaEsquinaSupIzq.copyWith(valores: [4]), 
            'z_centro': zonaCentro.copyWith(valores: [1, 2, 3]), 
            'z_inf_der': zonaEsquinaInfDer.copyWith(valores: [6, 6]), 
          },
          mapeo: tablero.mapeo,
        );
        
        expect(tableroLleno.estaCompleto, isTrue);
      });
    });
  });
}