import 'package:flutter/foundation.dart';

import '../../domain/alergias/alergias.dart';
import '../../domain/medicacao/catalogo_remedios.dart';
import '../../domain/medicacao/remedio.dart';

// Estado da busca de remedios: o catalogo (carregado na abertura), o que o
// paciente digitou e os remedios que combinam, pelo nome ou pelo principio
// ativo. Os que tem algo das [alergias] do paciente saem marcados. Quem nao
// acha o seu remedio pode usar o nome digitado.
class BuscarRemedioViewModel extends ChangeNotifier {
  // O mesmo limite do nome digitado em "Meus remedios".
  static const int tamanhoMaximoNome = 40;

  final List<String> alergias;

  BuscarRemedioViewModel(
    Future<CatalogoRemedios> catalogo, {
    this.alergias = const [],
  }) {
    _carregar(catalogo);
  }

  CatalogoRemedios? _catalogo;

  bool _carregando = true;
  bool get carregando => _carregando;

  // A lista nao abriu: so da para usar o nome digitado.
  bool _erroAoCarregar = false;
  bool get erroAoCarregar => _erroAoCarregar;

  String _consulta = '';
  String get consulta => _consulta;

  List<Remedio> _resultados = const [];
  List<Remedio> get resultados => _resultados;

  // Ja digitou algo que da para buscar (ignorando espacos).
  bool get buscou => _consulta.trim().isNotEmpty;

  // O remedio com o nome digitado, para quem nao acha o seu na lista: sem
  // principio ativo, com a primeira letra maiuscula. Null sem nada digitado.
  Remedio? get digitado {
    final nome = _consulta.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (nome.isEmpty) return null;
    return Remedio(nome: nome[0].toUpperCase() + nome.substring(1));
  }

  void definirConsulta(String texto) {
    _consulta = texto;
    _resultados = _catalogo?.buscar(texto) ?? const [];
    notifyListeners();
  }

  // A alergia do paciente que o remedio tem, ou null.
  String? alergiaDe(Remedio remedio) => alergiaNoRemedio(
    nome: remedio.nome,
    substancias: remedio.substancias,
    alergias: alergias,
  );

  Future<void> _carregar(Future<CatalogoRemedios> catalogo) async {
    try {
      _catalogo = await catalogo;
      _resultados = _catalogo!.buscar(_consulta);
    } catch (erro) {
      debugPrint('Falha ao carregar o catalogo de remedios: $erro');
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
