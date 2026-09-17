import 'package:flutter_test/flutter_test.dart';
import '../lib/tablero.dart';
import '../lib/zona.dart';
import '../lib/tipo.dart';

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
  });
}