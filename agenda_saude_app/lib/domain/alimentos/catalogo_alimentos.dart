import '../alergias/alergias.dart';
import '../busca/palavras.dart';
import 'alimento.dart';

// Lista de alimentos pesquisavel por nome. A busca ignora maiusculas e
// acentos ("feijao" acha "Feijão") e exige que cada palavra digitada comece
// alguma palavra do nome ("arr coz" acha "Arroz, tipo 1, cozido").
class CatalogoAlimentos {
  final List<Alimento> alimentos;
  final Map<int, Alimento> _porId;
  final List<List<String>> _palavras;

  CatalogoAlimentos(this.alimentos)
    : _porId = {for (final alimento in alimentos) alimento.id: alimento},
      _palavras = [
        for (final alimento in alimentos) separarPalavras(alimento.nome),
      ];

  Alimento? porId(int id) => _porId[id];

  // Alimentos que combinam com [consulta], os que comecam pela primeira
  // palavra digitada primeiro e depois em ordem alfabetica.
  List<Alimento> buscar(String consulta, {int limite = 40}) {
    final termos = separarPalavras(consulta);
    if (termos.isEmpty) return const [];

    final achados = <(int, Alimento, String)>[];
    for (var i = 0; i < alimentos.length; i++) {
      final palavras = _palavras[i];
      if (palavras.isEmpty || !combinaComTermos(palavras, termos)) continue;
      final comecaPelaBusca = palavras.first.startsWith(termos.first) ? 0 : 1;
      achados.add((comecaPelaBusca, alimentos[i], palavras.join(' ')));
    }

    achados.sort((a, b) {
      final porInicio = a.$1.compareTo(b.$1);
      return porInicio != 0 ? porInicio : a.$3.compareTo(b.$3);
    });
    return achados.take(limite).map((achado) => achado.$2).toList();
  }

  // Para a alergia: os alimentos sem o preparo (ver nomeDaAlergiaAlimentar),
  // sem repetir. "camar" acha "Camarão" uma vez so, e nao cada preparo dele.
  // Mesma ordem de [buscar].
  List<String> buscarAlergias(String consulta, {int limite = 40}) {
    final termos = separarPalavras(consulta);
    if (termos.isEmpty) return const [];

    final achados = <(int, String, String)>[];
    for (final (nome, palavras) in _alergias) {
      if (!combinaComTermos(palavras, termos)) continue;
      final comecaPelaBusca = palavras.first.startsWith(termos.first) ? 0 : 1;
      achados.add((comecaPelaBusca, nome, palavras.join(' ')));
    }

    achados.sort((a, b) {
      final porInicio = a.$1.compareTo(b.$1);
      return porInicio != 0 ? porInicio : a.$3.compareTo(b.$3);
    });
    return achados.take(limite).map((achado) => achado.$2).toList();
  }

  // Montada so na primeira busca de alergia. A TACO escreve alguns nomes de
  // dois jeitos ("Abobora" e "Abóbora"): fica o com acento.
  late final List<(String, List<String>)> _alergias = () {
    final porChave = <String, String>{};
    for (final alimento in alimentos) {
      final nome = nomeDaAlergiaAlimentar(alimento.nome);
      final chave = separarPalavras(nome).join(' ');
      if (chave.isEmpty) continue;
      final atual = porChave[chave];
      if (atual == null || _acentos(nome) > _acentos(atual)) {
        porChave[chave] = nome;
      }
    }
    return [
      for (final nome in porChave.values) (nome, separarPalavras(nome)),
    ];
  }();

  static int _acentos(String texto) =>
      texto.runes.where((caractere) => caractere > 127).length;
}
