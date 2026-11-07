// Textos do sono (RF03.2) usados no cartao da rotina, na tela de registro e no
// relatorio. Sem Flutter: so contas com texto, faceis de testar.

// "7 h", "7 h 30 min", "45 min". As horas vem em meias horas, mas qualquer
// valor vira minutos inteiros.
String formatarHorasDeSono(double horas) {
  final totalMinutos = (horas * 60).round();
  final h = totalMinutos ~/ 60;
  final min = totalMinutos % 60;
  if (h == 0) return '$min min';
  if (min == 0) return '$h h';
  return '$h h $min min';
}

// Como o leitor de tela fala as horas: "7 horas e 30 minutos", "1 hora",
// "30 minutos".
String falarHorasDeSono(double horas) {
  final totalMinutos = (horas * 60).round();
  final h = totalMinutos ~/ 60;
  final min = totalMinutos % 60;
  final textoHoras = h == 1 ? '1 hora' : '$h horas';
  final textoMinutos = min == 1 ? '1 minuto' : '$min minutos';
  if (h == 0) return textoMinutos;
  if (min == 0) return textoHoras;
  return '$textoHoras e $textoMinutos';
}

// "7 a 9 horas"; quando a faixa e um numero so, "8 horas".
String formatarMetaDeSono(int minHoras, int maxHoras) {
  return minHoras == maxHoras
      ? '$minHoras horas'
      : '$minHoras a $maxHoras horas';
}

// A palavra de cada nota da escala de 1 a 5 (RF 03.2). Vazio para uma nota
// fora da escala, que nao deveria existir.
String rotuloDaQualidadeDoSono(int qualidade) {
  switch (qualidade) {
    case 1:
      return 'Muito ruim';
    case 2:
      return 'Ruim';
    case 3:
      return 'Regular';
    case 4:
      return 'Bom';
    case 5:
      return 'Muito bom';
  }
  return '';
}

// "Bom (4 de 5)": a palavra e a nota, para quem le so um dos dois.
String descreverQualidadeDoSono(int qualidade) {
  final rotulo = rotuloDaQualidadeDoSono(qualidade);
  return rotulo.isEmpty ? '$qualidade de 5' : '$rotulo ($qualidade de 5)';
}
