// Textos do exercicio (RF03.3) usados no cartao da rotina, na tela de registro
// e no relatorio. Sem Flutter: so contas com texto, faceis de testar.

// "30 min", "1 h", "1 h 30 min".
String formatarMinutos(int minutos) {
  final h = minutos ~/ 60;
  final min = minutos % 60;
  if (h == 0) return '$min min';
  if (min == 0) return '$h h';
  return '$h h $min min';
}

// Como o leitor de tela fala a duracao: "30 minutos", "1 hora", "1 hora e 30
// minutos".
String falarMinutos(int minutos) {
  final h = minutos ~/ 60;
  final min = minutos % 60;
  final textoHoras = h == 1 ? '1 hora' : '$h horas';
  final textoMinutos = min == 1 ? '1 minuto' : '$min minutos';
  if (h == 0) return textoMinutos;
  if (min == 0) return textoHoras;
  return '$textoHoras e $textoMinutos';
}

// O "teste da conversa", que qualquer pessoa consegue fazer sem aparelho para
// saber a intensidade. Vazio para um nome que nao e uma das tres.
String descricaoDaIntensidade(String intensidade) {
  switch (intensidade) {
    case 'Leve':
      return 'Dá para conversar e até cantar.';
    case 'Moderada':
      return 'Dá para conversar, mas não para cantar.';
    case 'Intensa':
      return 'Só dá para falar frases curtas.';
  }
  return '';
}
