import 'dart:ui';
 
abstract class Tipo {
  Color get color;
  String get descripcion;
  bool esPosibleAgregar(List<int> actuales, int posible);
  Map<int, int> get puntuaciones;
}
 
class TipoVerde extends Tipo {
  @override
  Color get color => const Color(0xFF4CAF50);
 
  @override
  String get descripcion => 'Se puede colocar cualquier número';
 
  @override
  bool esPosibleAgregar(List<int> actuales, int posible) {
    return true;
  }
 
  @override
  Map<int, int> get puntuaciones => {
        1: 4,
        2: 3,
        3: 2,
      };
}
 
class TipoAzul extends Tipo {
  @override
  Color get color => const Color(0xFF2196F3);
 
  @override
  String get descripcion => 'Todos los números deben de ser iguales';
 
  @override
  bool esPosibleAgregar(List<int> actuales, int posible) {
    return actuales.isEmpty || actuales.every((element) => element == posible);
  }
 
  @override
  Map<int, int> get puntuaciones => {
        1: 7,
        2: 5,
        3: 3,
      };
}
 
class TipoMorado extends Tipo {
  @override
  Color get color => const Color(0xFF9C27B0);
 
  @override
  String get descripcion => 'Máximo dos números diferentes por zona';
 
  @override
  bool esPosibleAgregar(List<int> actuales, int posible) {
    final distintos = actuales.toSet()..add(posible);
    return distintos.length <= 2;
  }
 
  @override
  Map<int, int> get puntuaciones => {
        1: 6,
        2: 4,
        3: 2,
      };
}
 
class TipoRojo extends Tipo {
  @override
  Color get color => const Color(0xFFF44336);
 
  @override
  String get descripcion => 'Todos los números deben ser diferentes';
 
  @override
  bool esPosibleAgregar(List<int> actuales, int posible) {
    if (actuales.contains(posible)) {
      return false;
    }
    return actuales.toSet().length == actuales.length;
  }
 
  @override
  Map<int, int> get puntuaciones => {
        1: 6,
        2: 4,
        3: 2,
      };
}
 
class TipoAmarillo extends Tipo {
  @override
  Color get color => const Color(0xFFFFEB3B);
 
  @override
  String get descripcion => 'Todos los números deben ser diferentes';
 
  @override
  bool esPosibleAgregar(List<int> actuales, int posible) {
    if (actuales.contains(posible)) {
      return false;
    }
    return actuales.toSet().length == actuales.length;
  }
 
  @override
  Map<int, int> get puntuaciones => {
        1: 8,
        2: 6,
        3: 4,
      };
}