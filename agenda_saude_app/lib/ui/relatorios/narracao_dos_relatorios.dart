import '../../domain/relatorios/resumo_do_dia.dart';
import '../../domain/relatorios/resumo_do_mes.dart';
import '../insulina/formatacao_diabete.dart' show falarGlicemia;
import '../shared/texto_narrado.dart';
import 'formato_relatorios.dart' show descreverDia, juntarComE, nomeDoMes;

// O que o narrador le nos relatorios ("Ouvir esta tela", RF 08.2). Como as
// proprias telas, os textos falam do periodo sem dizer "voce" nem o nome, para
// servirem ao paciente e ao acompanhante. Vao so aos pontos principais - como foi
// a rotina, o que pede atencao e como estiveram os batimentos -, e nao a cada
// cartao: os numeros detalhados ficam na tela.

// O relatorio de um dia: como a rotina fechou e o que faltou, o que pede
// atencao (emergencias de batimentos e glicemia fora da faixa) e os batimentos.
String narrarRelatorioDoDia(ResumoDoDia resumo) {
  return montarTextoNarrado([
    'Relatório de ${descreverDia(resumo.dia)}',
    _situacaoDoDia(resumo),
    ..._pontosDeAtencao(resumo),
    _batimentosDoDia(resumo.batimentos),
  ]);
}

String _situacaoDoDia(ResumoDoDia resumo) {
  // Os mesmos itens, com as mesmas palavras, do selo do dia na tela. Sem
  // artigos, para "Faltou:" valer para todos (nao ha "faltou os remedios").
  final itens = [
    ('meta de água', resumo.hidratacao.metaAtingida),
    if (resumo.medicacao.total > 0) ('remédios', resumo.medicacao.todasTomadas),
    if (resumo.refeicoes.total > 0) ('refeições', resumo.refeicoes.todasFeitas),
    if (resumo.diabetes != null) ('glicemia', resumo.diabetes!.completo),
    ('sono', resumo.sono.registrou),
  ];
  final faltaram = [
    for (final (nome, cumprido) in itens)
      if (!cumprido) nome,
  ];

  switch (resumo.situacao) {
    case SituacaoDoDia.completo:
      return 'Rotina completa. Tudo foi cumprido';
    case SituacaoDoDia.parcial:
      return 'Rotina parcial. Faltou: ${juntarComE(faltaram)}';
    case SituacaoDoDia.semRegistro:
      return 'Nada da rotina foi anotado neste dia';
  }
}

// O que o acompanhante precisa ouvir primeiro: as mesmas coisas que a tela
// pinta de vermelho.
List<String> _pontosDeAtencao(ResumoDoDia resumo) {
  final pontos = <String>[];

  // Os alertas vem do mais recente para o mais antigo.
  final emergencias =
      resumo.alertas.where((alerta) => alerta.ehEmergencia).toList();
  if (emergencias.length == 1) {
    final alerta = emergencias.single;
    final bpm =
        alerta.bpm == null ? '' : ', com ${alerta.bpm} batimentos por minuto';
    pontos.add(
      'Atenção: houve um alerta de emergência nos batimentos, às '
      '${falarHoraDe(alerta.dataHora)}$bpm',
    );
  } else if (emergencias.length > 1) {
    pontos.add(
      'Atenção: houve ${emergencias.length} alertas de emergência nos '
      'batimentos, o último às ${falarHoraDe(emergencias.first.dataHora)}',
    );
  }

  final glicemia = resumo.diabetes?.glicemia;
  if (glicemia != null) {
    if (glicemia.baixas > 0) {
      pontos.add(
        'Glicemia baixa ${contar(glicemia.baixas, 'vez', 'vezes')}: a menor '
        'foi ${falarGlicemia(glicemia.menor!)}',
      );
    }
    if (glicemia.muitoAltas > 0) {
      pontos.add(
        'Glicemia muito alta ${contar(glicemia.muitoAltas, 'vez', 'vezes')}: '
        'a maior foi ${falarGlicemia(glicemia.maior!)}',
      );
    }
  }
  return pontos;
}

String _batimentosDoDia(BatimentosDoDia batimentos) {
  if (!batimentos.temLeituras) {
    return 'O smartwatch não mediu batimentos neste dia';
  }
  final media = 'média de ${batimentos.media!.round()} por minuto';
  final fora = batimentos.foraDaZona;
  if (fora == 0) {
    return 'Batimentos sempre dentro da zona de segurança, com $media';
  }
  final leituras = fora == 1
      ? '1 leitura ficou fora'
      : '$fora leituras ficaram fora';
  return 'Batimentos com $media. $leituras da zona de segurança';
}

// O relatorio do mes: quantos dias da rotina fecharam completos, a agua, a
// glicemia (so para diabeticos) e os alertas de batimentos.
String narrarRelatorioDoMes(ResumoDoMes resumo) {
  final titulo = 'Relatório de ${nomeDoMes(resumo.mes.month)} de '
      '${resumo.mes.year}';

  if (!resumo.temDiasEncerrados) {
    return montarTextoNarrado([
      titulo,
      'Ainda não terminou nenhum dia deste mês',
      'O relatório aparece a partir de amanhã',
    ]);
  }

  final dias = [
    if (resumo.diasCompletos > 0) '${resumo.diasCompletos} com a rotina completa',
    if (resumo.diasParciais > 0) '${resumo.diasParciais} com a rotina parcial',
    if (resumo.diasSemRegistro > 0) '${resumo.diasSemRegistro} sem registro',
  ];
  final encerrados = contar(resumo.diasEncerrados, 'dia encerrado', 'dias encerrados');

  return montarTextoNarrado([
    titulo,
    '$encerrados neste mês: ${juntarComE(dias)}',
    resumo.diasMetaDeAgua == 0
        ? 'Nenhum dia bateu a meta de água'
        : 'Meta de água batida em ${contar(resumo.diasMetaDeAgua, 'dia', 'dias')}',
    ..._glicemiaDoMes(resumo),
    _alertasDoMes(resumo),
  ]);
}

List<String> _glicemiaDoMes(ResumoDoMes resumo) {
  if (!resumo.temDiabetes) return const [];
  final glicemia = resumo.glicemia;
  return [
    if (glicemia.medicoes > 0)
      'Glicemia média de ${falarGlicemia(glicemia.media!)}',
    if (resumo.diasComHipoglicemia.isNotEmpty)
      'Glicemia baixa ${_nosDias(resumo.diasComHipoglicemia)}',
    if (resumo.diasComGlicemiaMuitoAlta.isNotEmpty)
      'Glicemia muito alta ${_nosDias(resumo.diasComGlicemiaMuitoAlta)}',
  ];
}

String _alertasDoMes(ResumoDoMes resumo) {
  final emergencias = resumo.emergencias;
  final avisos = resumo.avisos;
  if (emergencias == 0 && avisos == 0) {
    return 'Os batimentos não geraram alertas neste mês';
  }
  final partes = [
    if (emergencias > 0)
      '${contar(emergencias, 'alerta de emergência', 'alertas de emergência')} '
          '${_nosDias(resumo.diasComEmergencia)}',
    if (avisos > 0) contar(avisos, 'alerta de atenção', 'alertas de atenção'),
  ];
  return 'Batimentos: ${juntarComE(partes)}';
}

// "no dia 4", "nos dias 4 e 12".
String _nosDias(List<int> dias) {
  if (dias.length == 1) return 'no dia ${dias.first}';
  return 'nos dias ${juntarComE([for (final dia in dias) '$dia'])}';
}

// O relatorio ainda nao chegou: falar numeros agora seria enganoso.
const String relatorioCarregandoNarrado =
    'O relatório ainda está carregando. Tente ouvir de novo em instantes.';

const String relatorioComErroNarrado =
    'Não foi possível carregar o relatório agora.';
