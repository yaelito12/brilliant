import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'tablero.dart';
import 'zona.dart';
import 'tipo.dart';
import 'bloc/juego_bloc.dart';
import 'bloc/juego_event.dart';
import 'bloc/juego_state.dart';

/// Las 6 casillas marcadas con X en el tablero del Nivel 1.
/// El jugador debe rellenarlas con números del 1 al 6 sin repetir.
final Set<Coordenada> _casillasIniciales = {
  Coordenada(0, 2),  // Fila 0, Col 2 - Zona Azul
  Coordenada(1, 5),  // Fila 1, Col 5 - Zona Morada
  Coordenada(3, 1),  // Fila 3, Col 1 - Zona Roja
  Coordenada(3, 4),  // Fila 3, Col 4 - Zona Verde
  Coordenada(5, 2),  // Fila 5, Col 2 - Zona Morada
  Coordenada(6, 4),  // Fila 6, Col 4 - Zona Roja
};

class TableroPage extends StatelessWidget {
  const TableroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => JuegoBloc(),
      child: const _TableroView(),
    );
  }
}

class _TableroView extends StatefulWidget {
  const _TableroView();

  @override
  State<_TableroView> createState() => _TableroViewState();
}

class _TableroViewState extends State<_TableroView> {
  late Tablero _tablero;

  /// Mapa de qué número el jugador ha puesto en cada casilla inicial
  final Map<Coordenada, int> _valoresIniciales = {};

  @override
  void initState() {
    super.initState();
    _tablero = _construirTableroNivel1();
  }

  Tablero _construirTableroNivel1() {
    final zonas = {
      'am1': Zona(id: 'am1', tipo: TipoAmarillo(), capacidad: 1),
      'am2': Zona(id: 'am2', tipo: TipoAmarillo(), capacidad: 1),
      'am3': Zona(id: 'am3', tipo: TipoAmarillo(), capacidad: 1),
      'am4': Zona(id: 'am4', tipo: TipoAmarillo(), capacidad: 1),
      'am5': Zona(id: 'am5', tipo: TipoAmarillo(), capacidad: 1),
      've1': Zona(id: 've1', tipo: TipoVerde(), capacidad: 6),
      've2': Zona(id: 've2', tipo: TipoVerde(), capacidad: 6),
      'az1': Zona(id: 'az1', tipo: TipoAzul(), capacidad: 4),
      'az2': Zona(id: 'az2', tipo: TipoAzul(), capacidad: 4),
      'mo1': Zona(id: 'mo1', tipo: TipoMorado(), capacidad: 6),
      'mo2': Zona(id: 'mo2', tipo: TipoMorado(), capacidad: 6),
      'ro1': Zona(id: 'ro1', tipo: TipoRojo(), capacidad: 6),
      'ro2': Zona(id: 'ro2', tipo: TipoRojo(), capacidad: 6),
    };

    final mapeo = <Coordenada, String>{};
    void mapear(String id, List<List<int>> coords) {
      for (var c in coords) {
        mapeo[Coordenada(c[0], c[1])] = id;
      }
    }

    mapear('am1', [[0, 0]]);
    mapear('am2', [[0, 6]]);
    mapear('am3', [[3, 3]]);
    mapear('am4', [[6, 0]]);
    mapear('am5', [[6, 6]]);
    mapear('ve1', [[0,1], [1,0], [1,1], [2,0], [3,0], [4,0]]);
    mapear('ve2', [[1,6], [2,5], [2,6], [3,4], [3,5], [3,6]]);
    mapear('az1', [[0,2], [1,2], [1,3], [2,3]]);
    mapear('az2', [[4,6], [5,5], [5,6], [6,5]]);
    mapear('mo1', [[0,3], [0,4], [0,5], [1,4], [1,5], [2,4]]);
    mapear('mo2', [[3,2], [4,2], [4,3], [5,2], [6,1], [6,2]]);
    mapear('ro1', [[2,1], [2,2], [3,1], [4,1], [5,0], [5,1]]);
    mapear('ro2', [[4,4], [4,5], [5,3], [5,4], [6,3], [6,4]]);

    return Tablero(filas: 7, columnas: 7, zonas: zonas, mapeo: mapeo);
  }

  bool get _todasLasCasillasInicalesLlenas {
    return _casillasIniciales.every((c) => _valoresIniciales.containsKey(c));
  }

  void _alTocarCelda(BuildContext context, Coordenada coordenada) {
    // Permitir tocar las casillas iniciales en cualquier momento (incluso si está "Listo")
    // Esto permite corregir errores
    if (!_casillasIniciales.contains(coordenada)) return;
    _mostrarSelectorNumero(context, coordenada);
  }

  void _mostrarSelectorNumero(BuildContext context, Coordenada coordenada) {
    final bloc = context.read<JuegoBloc>();
    final valorActual = _valoresIniciales[coordenada];
    final ocupadosPorOtros = _valoresIniciales.entries
        .where((e) => e.key != coordenada)
        .map((e) => e.value)
        .toSet();

    final focusNode = FocusNode();
    focusNode.requestFocus();

    void seleccionarNumero(int numero) {
      if (ocupadosPorOtros.contains(numero)) return; // No permitir si está ocupado
      Navigator.pop(context);
      setState(() {
        _valoresIniciales[coordenada] = numero;
      });
      if (!_todasLasCasillasInicalesLlenas) {
        bloc.add(ValoresInicialesIncompletos());
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return KeyboardListener(
          focusNode: focusNode,
          onKeyEvent: (event) {
            if (event is KeyDownEvent) {
              final keyLabel = event.logicalKey.keyLabel;
              if (['1', '2', '3', '4', '5', '6'].contains(keyLabel)) {
                seleccionarNumero(int.parse(keyLabel));
              } else if (event.logicalKey.keyLabel == 'Backspace' || event.logicalKey.keyLabel == 'Delete') {
                if (valorActual != null) {
                  Navigator.pop(context);
                  setState(() {
                    _valoresIniciales.remove(coordenada);
                  });
                  bloc.add(ValoresInicialesIncompletos());
                }
              }
            }
          },
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Elige un número (1-6) — sin repetir',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Puedes presionar un número en tu teclado',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (i) {
                    final numero = i + 1;
                    final estaOcupado = ocupadosPorOtros.contains(numero);
                    final esSeleccionado = valorActual == numero;

                    return GestureDetector(
                      onTap: estaOcupado ? null : () => seleccionarNumero(numero),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: estaOcupado
                              ? Colors.grey.shade300
                              : esSeleccionado
                                  ? Colors.orange.shade600
                                  : Colors.teal.shade600,
                          shape: BoxShape.circle,
                          border: esSeleccionado
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '$numero',
                            style: TextStyle(
                              color: estaOcupado ? Colors.grey.shade500 : Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: valorActual == null 
                      ? null 
                      : () {
                          Navigator.pop(context);
                          setState(() {
                            _valoresIniciales.remove(coordenada);
                          });
                          bloc.add(ValoresInicialesIncompletos());
                        },
                  icon: Icon(Icons.delete, color: valorActual == null ? Colors.grey : Colors.red),
                  label: Text('Borrar número (Supr)', style: TextStyle(color: valorActual == null ? Colors.grey : Colors.red)),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() => focusNode.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<JuegoBloc, JuegoState>(
      listener: (context, state) {
        if (state is JuegoListo) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    '¡Valores iniciales listos! El juego puede comenzar.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              backgroundColor: Colors.teal.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE8F2ED),
        appBar: AppBar(
          title: const Text(
            'Brilliant',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // --- Banner de instrucciones según estado del BLoC ---
            BlocBuilder<JuegoBloc, JuegoState>(
              builder: (context, state) {
                final estaEsperando = state is JuegoEsperandoValores;
                final pendientes = _casillasIniciales
                    .where((c) => !_valoresIniciales.containsKey(c))
                    .length;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  color: estaEsperando
                      ? Colors.orange.shade700
                      : Colors.teal.shade600,
                  child: Row(
                    children: [
                      Icon(
                        estaEsperando ? Icons.lock_outline : Icons.lock_open,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          estaEsperando
                              ? 'Toca las casillas resaltadas y pon números del 1 al 6. Faltan $pendientes casilla(s).'
                              : '¡Todo listo! Ahora puedes jugar.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // --- El tablero 7x7 ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: BlocBuilder<JuegoBloc, JuegoState>(
                        builder: (context, state) {
                          return GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _tablero.columnas,
                              crossAxisSpacing: 3.0,
                              mainAxisSpacing: 3.0,
                            ),
                            itemCount: _tablero.filas * _tablero.columnas,
                            itemBuilder: (context, index) {
                              final fila = index ~/ _tablero.columnas;
                              final columna = index % _tablero.columnas;
                              return _buildCelda(context, fila, columna, state);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // --- Botón de Comenzar ---
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0, left: 16.0, right: 16.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: BlocBuilder<JuegoBloc, JuegoState>(
                  builder: (context, state) {
                    final estaEsperando = state is JuegoEsperandoValores;
                    // Solo podemos presionar si ya llenamos todo Y el estado sigue siendo esperando.
                    // O si ya está listo, podríamos deshabilitarlo o decir "Jugando..."
                    
                    return ElevatedButton.icon(
                      onPressed: (_todasLasCasillasInicalesLlenas && estaEsperando) 
                          ? () {
                              context.read<JuegoBloc>().add(ValoresInicialesProporcionados());
                            } 
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                        !_todasLasCasillasInicalesLlenas 
                            ? 'Faltan números iniciales' 
                            : estaEsperando 
                                ? '¡Listo! Comenzar Juego' 
                                : 'Juego en progreso',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCelda(BuildContext context, int fila, int columna, JuegoState state) {
    final coordenada = Coordenada(fila, columna);
    final zona = _tablero.zonaEn(coordenada);

    if (zona == null) {
      return Container(color: Colors.transparent);
    }

    final esInicial = _casillasIniciales.contains(coordenada);
    final valorInicial = _valoresIniciales[coordenada];
    final estaEsperando = state is JuegoEsperandoValores;

    // Color base según el tipo de zona
    Color colorBase;
    if (zona.tipo is TipoVerde) {
      colorBase = const Color(0xFF66BB6A);
    } else if (zona.tipo is TipoAzul) {
      colorBase = const Color(0xFF42A5F5);
    } else if (zona.tipo is TipoRojo) {
      colorBase = const Color(0xFFEF5350);
    } else if (zona.tipo is TipoAmarillo) {
      colorBase = const Color(0xFFFFCA28);
    } else if (zona.tipo is TipoMorado) {
      colorBase = const Color(0xFFAB47BC);
    } else {
      colorBase = Colors.grey;
    }

    return GestureDetector(
      onTap: () => _alTocarCelda(context, coordenada),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorBase.withValues(alpha: 0.5),
              colorBase,
              colorBase.withAlpha(200),
            ],
          ),
          // Las casillas iniciales sin valor tienen un borde llamativo cuando
          // el juego está esperando valores
          border: esInicial && estaEsperando
              ? Border.all(
                  color: valorInicial != null
                      ? Colors.white
                      : Colors.orange.shade300,
                  width: 3,
                )
              : Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 2),
                  left: BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 2),
                  bottom: BorderSide(color: Colors.black.withValues(alpha: 0.25), width: 2),
                  right: BorderSide(color: Colors.black.withValues(alpha: 0.25), width: 2),
                ),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
          ],
        ),
        child: Stack(
          children: [
            // Número (inicial o normal)
            Center(
              child: Text(
                valorInicial != null ? '$valorInicial' : '',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF1B3B4D),
                  shadows: [
                    Shadow(
                      color: Colors.white.withValues(alpha: 0.8),
                      offset: const Offset(1, 1),
                      blurRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
            // Ícono de lápiz en casillas iniciales vacías (mientras espera)
            if (esInicial && valorInicial == null && estaEsperando)
              const Positioned(
                top: 2,
                right: 3,
                child: Icon(Icons.edit, size: 10, color: Colors.white70),
              ),
          ],
        ),
      ),
    );
  }
}

