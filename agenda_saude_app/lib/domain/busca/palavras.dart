// Busca por nome, a mesma para alimentos e remedios: ignora maiusculas e
// acentos ("feijao" acha "Feijão") e cada palavra digitada tem de comecar
// alguma palavra do nome ("arr coz" acha "Arroz, tipo 1, cozido").

const _comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
const _semAcento = 'aaaaaeeeeiiiiooooouuuucn';

// Minusculas, sem acento e sem pontuacao, separado em palavras:
// "Pé-de-moleque, amendoim" -> [pe, de, moleque, amendoim].
List<String> separarPalavras(String texto) {
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

// Cada termo comeca alguma das [palavras].
bool combinaComTermos(List<String> palavras, List<String> termos) {
  return termos.every(
    (termo) => palavras.any((palavra) => palavra.startsWith(termo)),
  );
}

// [palavras] tem [trecho] em sequencia: "doce de leite" tem "leite", e
// "leite de vaca integral" tem "leite de vaca".
bool contemSequencia(List<String> palavras, List<String> trecho) {
  if (trecho.isEmpty || trecho.length > palavras.length) return false;
  for (var inicio = 0; inicio + trecho.length <= palavras.length; inicio++) {
    var igual = true;
    for (var i = 0; i < trecho.length; i++) {
      if (palavras[inicio + i] != trecho[i]) {
        igual = false;
        break;
      }
    }
    if (igual) return true;
  }
  return false;
}
