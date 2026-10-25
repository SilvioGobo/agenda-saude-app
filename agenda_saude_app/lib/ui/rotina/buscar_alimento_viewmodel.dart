import 'package:flutter/foundation.dart';

import '../../domain/alimentos/alimento.dart';
import '../../domain/alimentos/catalogo_alimentos.dart';

// Estado da busca de alimentos: o que o paciente digitou e os alimentos do
// catalogo que combinam. A busca roda no aparelho, a cada letra.
class BuscarAlimentoViewModel extends ChangeNotifier {
  final CatalogoAlimentos _catalogo;

  BuscarAlimentoViewModel(this._catalogo);

  String _consulta = '';
  String get consulta => _consulta;

  List<Alimento> _resultados = const [];
  List<Alimento> get resultados => _resultados;

  // Ja digitou algo que da para buscar (ignorando espacos).
  bool get buscou => _consulta.trim().isNotEmpty;

  void definirConsulta(String texto) {
    _consulta = texto;
    _resultados = _catalogo.buscar(texto);
    notifyListeners();
  }
}
