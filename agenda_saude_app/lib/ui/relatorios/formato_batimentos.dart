import '../../domain/models/alerta.dart';
import '../../domain/relatorios/resumo_do_dia.dart';
import 'formato_relatorios.dart';

// O grafico de BPM do relatorio do dia em frases, para o leitor de tela: o
// desenho em si nao e lido. Diz a variacao do dia, quantas leituras sairam da
// zona de seguranca e cada alerta (os primeiros [maximoDeAlertas], do mais
// antigo para o mais recente), com o horario.
String descreverGraficoDeBatimentos({
  required BatimentosDoDia batimentos,
  required List<Alerta> alertas,
  int maximoDeAlertas = 5,
}) {
  final zona = 'de ${batimentos.zonaMinima} a ${batimentos.zonaMaxima} BPM';
  final frases = <String>[
    'Gráfico dos batimentos do dia, das 0 às 24 horas. Os batimentos variaram '
        'de ${batimentos.minimo} a ${batimentos.maximo} BPM, com média de '
        '${batimentos.media?.round()}.',
    if (batimentos.foraDaZona == 0)
      'Todas as leituras ficaram dentro da zona de segurança, $zona.'
    else
      '${batimentos.foraDaZona} '
          '${batimentos.foraDaZona == 1 ? 'leitura ficou' : 'leituras ficaram'} '
          'fora da zona de segurança, $zona.',
  ];

  if (alertas.isEmpty) {
    frases.add('Nenhum alerta no dia.');
  } else {
    final cronologicos = [...alertas]
      ..sort((a, b) => a.dataHora.compareTo(b.dataHora));
    for (final alerta in cronologicos.take(maximoDeAlertas)) {
      final tipo = alerta.ehEmergencia ? 'emergência' : 'atenção';
      final bpm = alerta.bpm == null ? '' : ', com ${alerta.bpm} BPM';
      frases.add(
        'Alerta de $tipo às ${formatarHora(alerta.dataHora)}$bpm.',
      );
    }
    final restantes = cronologicos.length - maximoDeAlertas;
    if (restantes > 0) {
      frases.add('E mais $restantes ${restantes == 1 ? 'alerta' : 'alertas'}.');
    }
  }
  return frases.join(' ');
}
