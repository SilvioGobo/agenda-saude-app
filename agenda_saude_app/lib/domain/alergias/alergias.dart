import '../busca/palavras.dart';

// Alergias do paciente (triagem e "Minhas alergias"): a alimentos, escolhidas
// no catalogo TACO, e a remedios, escolhidas pelo principio ativo no catalogo
// da Anvisa. O app avisa quando o paciente poe numa refeicao, ou na lista de
// remedios, algo que tem o que ele disse ter alergia. A comparacao e pelo
// nome, sem acento e sem maiusculas: nenhuma das duas tabelas traz os
// ingredientes, entao o aviso nao substitui o rotulo nem o medico.

// O alimento que vale para a alergia: o comeco do nome da TACO, sem o preparo
// ("Camarão, Rio Grande, grande, cozido" -> "Camarão"). Se a segunda parte
// diz de que e o alimento, ela entra: "Leite, de vaca, integral" -> "Leite de
// vaca", "Farinha, de trigo" -> "Farinha de trigo" (e nao "Farinha", que
// pegaria a de mandioca).
String nomeDaAlergiaAlimentar(String nomeDoAlimento) {
  final partes = nomeDoAlimento
      .split(',')
      .map((parte) => parte.trim())
      .where((parte) => parte.isNotEmpty)
      .toList();
  if (partes.isEmpty) return nomeDoAlimento.trim();
  final segunda = partes.length > 1 ? partes[1] : '';
  return RegExp(r'^(de|da|do|das|dos) ').hasMatch(segunda)
      ? '${partes.first} $segunda'
      : partes.first;
}

// A alergia (da lista do paciente) que o alimento pode ter, ou null. Vale o
// nome inteiro da alergia em sequencia: alergia a "Amendoim" pega "Amendoim,
// torrado, salgado" e "Paçoca, amendoim"; a "Leite de vaca" pega "Leite, de
// vaca, desnatado", mas nao "Leite, de coco".
String? alergiaNoAlimento(String nomeDoAlimento, List<String> alergias) {
  final palavras = separarPalavras(nomeDoAlimento);
  for (final alergia in alergias) {
    if (contemSequencia(palavras, separarPalavras(alergia))) return alergia;
  }
  return null;
}

// A alergia (da lista do paciente, por principio ativo) que o remedio tem, ou
// null. Compara com os principios ativos do catalogo ("Novalgina" tem
// "Dipirona") e, para o remedio digitado a mao, sem principio ativo, com as
// palavras do nome ("Dipirona 1 g").
String? alergiaNoRemedio({
  required String nome,
  List<String> substancias = const [],
  required List<String> alergias,
}) {
  final palavrasDoNome = separarPalavras(nome);
  final palavrasDasSubstancias = substancias.map(separarPalavras).toList();
  for (final alergia in alergias) {
    final trecho = separarPalavras(alergia);
    if (trecho.isEmpty) continue;
    final temNaSubstancia = palavrasDasSubstancias.any(
      (palavras) => contemSequencia(palavras, trecho),
    );
    if (temNaSubstancia || contemSequencia(palavrasDoNome, trecho)) {
      return alergia;
    }
  }
  return null;
}

// Junta [nova] a [alergias] se ainda nao estiver la (sem diferenciar acento e
// maiusculas). Devolve a lista nova.
List<String> comAlergia(List<String> alergias, String nova) {
  final chave = separarPalavras(nova).join(' ');
  if (chave.isEmpty) return alergias;
  final jaTem = alergias.any(
    (alergia) => separarPalavras(alergia).join(' ') == chave,
  );
  return jaTem ? alergias : [...alergias, nova.trim()];
}
