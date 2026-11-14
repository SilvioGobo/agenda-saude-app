import '../busca/palavras.dart';
import 'remedio.dart';

// Um principio ativo achado na busca da alergia. [remedio] e o nome do
// remedio por onde ele foi achado, quando o paciente digitou a marca
// ("novalgina" acha "Dipirona", do remedio "Novalgina").
class SubstanciaEncontrada {
  final String nome;
  final String? remedio;

  const SubstanciaEncontrada(this.nome, {this.remedio});
}

// Lista de remedios pesquisavel pelo nome ou pelo principio ativo, com a
// mesma busca do catalogo de alimentos (sem acento, pelo comeco das palavras).
class CatalogoRemedios {
  final List<Remedio> remedios;
  final List<List<String>> _palavrasDoNome;
  final List<List<String>> _palavrasComSubstancias;

  CatalogoRemedios(this.remedios)
    : _palavrasDoNome = [
        for (final remedio in remedios) separarPalavras(remedio.nome),
      ],
      _palavrasComSubstancias = [
        for (final remedio in remedios)
          separarPalavras('${remedio.nome} ${remedio.substancias.join(' ')}'),
      ];

  // Remedios que combinam com [consulta]. Primeiro os que tem a busca no nome
  // (os que comecam por ela antes), depois os que so tem no principio ativo:
  // "metformina" mostra "Cloridrato de metformina" e depois "Glifage".
  List<Remedio> buscar(String consulta, {int limite = 40}) {
    final termos = separarPalavras(consulta);
    if (termos.isEmpty) return const [];

    final achados = <(int, Remedio, String)>[];
    for (var i = 0; i < remedios.length; i++) {
      final nome = _palavrasDoNome[i];
      if (nome.isEmpty) continue;
      final int ordem;
      if (combinaComTermos(nome, termos)) {
        ordem = nome.first.startsWith(termos.first) ? 0 : 1;
      } else if (combinaComTermos(_palavrasComSubstancias[i], termos)) {
        ordem = 2;
      } else {
        continue;
      }
      achados.add((ordem, remedios[i], nome.join(' ')));
    }

    achados.sort((a, b) {
      final porOrdem = a.$1.compareTo(b.$1);
      return porOrdem != 0 ? porOrdem : a.$3.compareTo(b.$3);
    });
    return achados.take(limite).map((achado) => achado.$2).toList();
  }

  // Para a alergia: principios ativos, sem repetir. Primeiro os que tem a
  // busca no proprio nome ("dipi" acha "Dipirona"); depois os dos remedios
  // que tem a busca no nome ("novalgina" acha "Dipirona", do Novalgina).
  List<SubstanciaEncontrada> buscarSubstancias(
    String consulta, {
    int limite = 40,
  }) {
    final termos = separarPalavras(consulta);
    if (termos.isEmpty) return const [];

    final pelaSubstancia = <(int, String, String)>[];
    for (final (nome, palavras) in _substancias) {
      if (!combinaComTermos(palavras, termos)) continue;
      final ordem = palavras.first.startsWith(termos.first) ? 0 : 1;
      pelaSubstancia.add((ordem, nome, palavras.join(' ')));
    }
    pelaSubstancia.sort((a, b) {
      final porOrdem = a.$1.compareTo(b.$1);
      return porOrdem != 0 ? porOrdem : a.$3.compareTo(b.$3);
    });

    final achados = [
      for (final achado in pelaSubstancia) SubstanciaEncontrada(achado.$2),
    ];
    final jaAchadas = {
      for (final achado in pelaSubstancia) separarPalavras(achado.$2).join(' '),
    };
    for (final remedio in buscar(consulta, limite: limite)) {
      for (final substancia in remedio.substancias) {
        final chave = separarPalavras(substancia).join(' ');
        if (!jaAchadas.add(chave)) continue;
        achados.add(SubstanciaEncontrada(substancia, remedio: remedio.nome));
      }
    }
    return achados.take(limite).toList();
  }

  // Montada so na primeira busca de alergia.
  late final List<(String, List<String>)> _substancias = () {
    final porChave = <String, String>{};
    for (final remedio in remedios) {
      for (final substancia in remedio.substancias) {
        final chave = separarPalavras(substancia).join(' ');
        if (chave.isNotEmpty) porChave.putIfAbsent(chave, () => substancia);
      }
    }
    return [for (final nome in porChave.values) (nome, separarPalavras(nome))];
  }();
}
