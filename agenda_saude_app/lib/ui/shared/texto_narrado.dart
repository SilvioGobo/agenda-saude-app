import '../lembretes/formato_lembretes.dart' show falarHorario;
import '../relatorios/formato_relatorios.dart' show nomeDoMes;

// Pecas dos textos que o narrador le em voz alta ("Ouvir esta tela", RF 08.2).
// Cada tela escolhe os pontos principais e monta o seu texto com estas funcoes.
// Sem Flutter: so contas com texto, faceis de testar.
//
// O que faz um texto bom de ouvir:
// - curto: so o que importa agora, e nao a tela inteira. Quem ouve nao consegue
//   "passar o olho" como quem le, entao cada frase a mais cansa;
// - frases curtas, cada uma terminando em ponto: e ali que a voz faz a pausa;
// - nada de siglas e simbolos que a voz le mal: "batimentos por minuto" e nao
//   "BPM", "miligramas por decilitro" e nao "mg/dL", horas por extenso.

// Junta as [frases] num texto so, para a voz. Cada frase termina em pontuacao
// (e ali que a voz faz a pausa) e as vazias somem.
String montarTextoNarrado(Iterable<String?> frases) {
  final partes = <String>[];
  for (final frase in frases) {
    final limpa = frase?.trim() ?? '';
    if (limpa.isEmpty) continue;
    final termina = '.!?'.contains(limpa[limpa.length - 1]);
    partes.add(termina ? limpa : '$limpa.');
  }
  return partes.join(' ');
}

// "1 copo", "3 copos".
String contar(int quantidade, String singular, String plural) =>
    quantidade == 1 ? '1 $singular' : '$quantidade $plural';

// A dose de um remedio como o paciente a digitou ("Losartana 50mg"), com a
// unidade por extenso, que a voz le melhor do que a abreviatura: "Losartana 50
// miligramas". So troca unidades coladas a um numero (mg, mcg, ml e g); o resto
// do texto fica como esta.
String falarDose(String texto) {
  String unidade(Match achado, String singular, String plural) {
    final numero = achado[1]!;
    return '$numero ${numero == '1' ? singular : plural}';
  }

  String troca(String entrada, String sigla, String singular, String plural) {
    return entrada.replaceAllMapped(
      RegExp('(\\d+(?:[.,]\\d+)?)\\s*$sigla(?![\\p{L}\\d])',
          caseSensitive: false, unicode: true),
      (achado) => unidade(achado, singular, plural),
    );
  }

  // `mcg` e `mg` antes de `g`, para o `g` de "mg" nao ser trocado de novo.
  var falado = troca(texto, 'mcg', 'micrograma', 'microgramas');
  falado = troca(falado, 'mg', 'miligrama', 'miligramas');
  falado = troca(falado, 'ml', 'mililitro', 'mililitros');
  return troca(falado, 'g', 'grama', 'gramas');
}

// "14:05" falado: "14 horas e 5 minutos".
String falarHoraDe(DateTime dataHora) {
  String doisDigitos(int valor) => valor.toString().padLeft(2, '0');
  return falarHorario(
    '${doisDigitos(dataHora.hour)}:${doisDigitos(dataHora.minute)}',
  );
}

// Quando algo aconteceu, em relacao a [agora]: "agora mesmo", "há 5 minutos",
// "hoje, às 14 horas e 32 minutos", "ontem, às 9 horas" ou "em 18 de setembro,
// às 21 horas e 5 minutos".
String falarQuando(DateTime dataHora, DateTime agora) {
  final diferenca = agora.difference(dataHora);
  if (diferenca.inMinutes < 1) return 'agora mesmo';
  if (diferenca.inMinutes < 60) {
    return 'há ${contar(diferenca.inMinutes, 'minuto', 'minutos')}';
  }

  final hoje = DateTime(agora.year, agora.month, agora.day);
  final dia = DateTime(dataHora.year, dataHora.month, dataHora.day);
  final dias = (hoje.difference(dia).inHours / 24).round();
  final hora = 'às ${falarHoraDe(dataHora)}';
  if (dias == 0) return 'hoje, $hora';
  if (dias == 1) return 'ontem, $hora';
  return 'em ${dia.day} de ${nomeDoMes(dia.month)}, $hora';
}
