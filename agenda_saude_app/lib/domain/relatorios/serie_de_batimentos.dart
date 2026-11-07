import 'dart:math' as math;

import '../models/batimento_cardiaco.dart';

// Um ponto da curva de BPM: as leituras de um intervalo (10 minutos, em geral)
// resumidas em uma media e nos extremos. O smartwatch pode mandar uma leitura a
// cada 30 segundos, o que dá dois mil pontos por dia: desenhar todos pesa na
// tela e nao melhora o que se enxerga. O menor e o maior ficam guardados para
// uma subida rapida nao sumir dentro da media.
class PontoDeBatimento {
  final DateTime inicio;
  final DateTime fim;
  final double media;
  final int minimo;
  final int maximo;
  // Quantas leituras o ponto resume; nunca zero.
  final int leituras;

  const PontoDeBatimento({
    required this.inicio,
    required this.fim,
    required this.media,
    required this.minimo,
    required this.maximo,
    required this.leituras,
  });

  // O meio do intervalo: e onde o ponto aparece no grafico.
  DateTime get meio => inicio.add(fim.difference(inicio) ~/ 2);
}

// A curva de BPM de um dia (RF 04.3, Figura 17): os pontos do [inicio] ate o
// [fim], em ordem de horario. Intervalos sem leitura nao tem ponto: um relogio
// fora do pulso aparece como buraco na curva, e nao como uma linha reta
// inventada.
class SerieDeBatimentos {
  static const int intervaloPadraoMinutos = 10;

  // Sem leitura por mais que isto, a linha para de ligar os pontos. Uma hora e o
  // mesmo prazo em que o cartao do acompanhante troca o BPM por "SEM DADOS".
  static const int lacunaPadraoMinutos = 60;

  final DateTime inicio;
  final DateTime fim;
  // O tamanho do intervalo que cada ponto resume.
  final int intervaloMinutos;
  final List<PontoDeBatimento> pontos;

  const SerieDeBatimentos({
    required this.inicio,
    required this.fim,
    this.intervaloMinutos = intervaloPadraoMinutos,
    this.pontos = const [],
  });

  // Agrupa as [leituras] em intervalos de [intervaloMinutos], contando o que cai
  // entre [inicio] (inclusive) e [fim] (exclusive); o resto e ignorado. Aceita as
  // leituras em qualquer ordem. Le cada leitura uma vez so, sem copiar a lista.
  factory SerieDeBatimentos.de(
    Iterable<BatimentoCardiaco> leituras, {
    required DateTime inicio,
    required DateTime fim,
    int intervaloMinutos = intervaloPadraoMinutos,
  }) {
    final intervalo = Duration(minutes: intervaloMinutos);
    final soma = <int, int>{};
    final menor = <int, int>{};
    final maior = <int, int>{};
    final quantidade = <int, int>{};

    for (final leitura in leituras) {
      final momento = leitura.timestamp;
      if (momento.isBefore(inicio) || !momento.isBefore(fim)) continue;
      final indice =
          momento.difference(inicio).inMicroseconds ~/ intervalo.inMicroseconds;
      final bpm = leitura.bpm;
      soma[indice] = (soma[indice] ?? 0) + bpm;
      menor[indice] = math.min(menor[indice] ?? bpm, bpm);
      maior[indice] = math.max(maior[indice] ?? bpm, bpm);
      quantidade[indice] = (quantidade[indice] ?? 0) + 1;
    }

    final indices = quantidade.keys.toList()..sort();
    return SerieDeBatimentos(
      inicio: inicio,
      fim: fim,
      intervaloMinutos: intervaloMinutos,
      pontos: [
        for (final indice in indices)
          PontoDeBatimento(
            inicio: inicio.add(intervalo * indice),
            // O ultimo intervalo pode passar da meia-noite: corta no fim do dia.
            fim: _antes(inicio.add(intervalo * (indice + 1)), fim),
            media: soma[indice]! / quantidade[indice]!,
            minimo: menor[indice]!,
            maximo: maior[indice]!,
            leituras: quantidade[indice]!,
          ),
      ],
    );
  }

  static DateTime _antes(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  bool get vazia => pontos.isEmpty;

  // O menor BPM de todas as leituras do dia; null sem leituras.
  int? get minimo =>
      vazia ? null : pontos.map((ponto) => ponto.minimo).reduce(math.min);

  // O maior BPM de todas as leituras do dia; null sem leituras.
  int? get maximo =>
      vazia ? null : pontos.map((ponto) => ponto.maximo).reduce(math.max);

  // Os pontos em trechos continuos: um novo trecho comeca quando passam mais de
  // [lacunaMinutos] sem leitura. A tela liga com linha so os pontos de um mesmo
  // trecho.
  List<List<PontoDeBatimento>> trechos({int lacunaMinutos = lacunaPadraoMinutos}) {
    final lacuna = Duration(minutes: lacunaMinutos);
    final trechos = <List<PontoDeBatimento>>[];
    for (final ponto in pontos) {
      final continua = trechos.isNotEmpty &&
          ponto.inicio.difference(trechos.last.last.fim) <= lacuna;
      if (continua) {
        trechos.last.add(ponto);
      } else {
        trechos.add([ponto]);
      }
    }
    return trechos;
  }
}
