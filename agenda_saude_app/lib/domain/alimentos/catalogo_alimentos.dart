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
      _palavras = [for (final alimento in alimentos) _separar(alimento.nome)];

  Alimento? porId(int id) => _porId[id];

  // Alimentos que combinam com [consulta], os que comecam pela primeira
  // palavra digitada primeiro e depois em ordem alfabetica.
  List<Alimento> buscar(String consulta, {int limite = 40}) {
    final termos = _separar(consulta);
    if (termos.isEmpty) return const [];

    final achados = <(int, Alimento, String)>[];
    for (var i = 0; i < alimentos.length; i++) {
      final palavras = _palavras[i];
      if (palavras.isEmpty) continue;
      final combina = termos.every(
        (termo) => palavras.any((palavra) => palavra.startsWith(termo)),
      );
      if (!combina) continue;
      final comecaPelaBusca = palavras.first.startsWith(termos.first) ? 0 : 1;
      achados.add((comecaPelaBusca, alimentos[i], palavras.join(' ')));
    }

    achados.sort((a, b) {
      final porInicio = a.$1.compareTo(b.$1);
      return porInicio != 0 ? porInicio : a.$3.compareTo(b.$3);
    });
    return achados.take(limite).map((achado) => achado.$2).toList();
  }

  static const _comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  static const _semAcento = 'aaaaaeeeeiiiiooooouuuucn';

  // Minusculas, sem acento e sem pontuacao, separado em palavras.
  static List<String> _separar(String texto) {
    final normalizado = StringBuffer();
    for (final caractere in texto.toLowerCase().split('')) {
      final indice = _comAcento.indexOf(caractere);
      normalizado.write(indice >= 0 ? _semAcento[indice] : caractere);
    }
    return normalizado
        .toString()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((palavra) => palavra.isNotEmpty)
        .toList();
  }
}
