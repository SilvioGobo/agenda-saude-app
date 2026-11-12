import 'package:flutter/foundation.dart';

import '../../domain/alergias/alergias.dart';
import '../../domain/alimentos/alimento.dart';
import '../../domain/alimentos/catalogo_alimentos.dart';

// Estado da busca de alimentos: o que o paciente digitou e os alimentos do
// catalogo que combinam. A busca roda no aparelho, a cada letra. Os que tem
// algo das [alergias] do paciente saem marcados.
class BuscarAlimentoViewModel extends ChangeNotifier {
  final CatalogoAlimentos _catalogo;
  final List<String> alergias;

  BuscarAlimentoViewModel(this._catalogo, {this.alergias = const []});

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

  // A alergia do paciente que o alimento pode ter, ou null.
  String? alergiaDe(Alimento alimento) =>
      alergiaNoAlimento(alimento.nome, alergias);
}
