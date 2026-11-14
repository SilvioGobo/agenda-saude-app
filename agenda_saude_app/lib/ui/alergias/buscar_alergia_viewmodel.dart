import 'package:flutter/foundation.dart';

// Uma opcao da busca de alergia: o nome que fica na lista do paciente
// ("Camarão", "Dipirona") e, as vezes, uma linha a mais que explica de onde
// ela veio ("Princípio ativo do Novalgina").
class OpcaoDeAlergia {
  final String nome;
  final String? detalhe;

  const OpcaoDeAlergia(this.nome, {this.detalhe});
}

// Estado da busca de alergia: a mesma tela para alimentos e remedios, so muda
// a funcao que busca, que chega quando o catalogo termina de carregar.
class BuscarAlergiaViewModel extends ChangeNotifier {
  BuscarAlergiaViewModel(
    Future<List<OpcaoDeAlergia> Function(String consulta)> busca,
  ) {
    _carregar(busca);
  }

  List<OpcaoDeAlergia> Function(String consulta)? _buscar;

  bool _carregando = true;
  bool get carregando => _carregando;

  bool _erroAoCarregar = false;
  bool get erroAoCarregar => _erroAoCarregar;

  String _consulta = '';
  String get consulta => _consulta;

  List<OpcaoDeAlergia> _resultados = const [];
  List<OpcaoDeAlergia> get resultados => _resultados;

  // Ja digitou algo que da para buscar (ignorando espacos).
  bool get buscou => _consulta.trim().isNotEmpty;

  void definirConsulta(String texto) {
    _consulta = texto;
    _resultados = _buscar?.call(texto) ?? const [];
    notifyListeners();
  }

  Future<void> _carregar(
    Future<List<OpcaoDeAlergia> Function(String consulta)> busca,
  ) async {
    try {
      _buscar = await busca;
      _resultados = _buscar!(_consulta);
    } catch (erro) {
      debugPrint('Falha ao carregar a lista da alergia: $erro');
      _erroAoCarregar = true;
    }
    _carregando = false;
    if (!_descartado) notifyListeners();
  }

  bool _descartado = false;

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
