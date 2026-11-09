import '../../core/constants/meta_hidratacao.dart';
import '../../domain/medicacao/dose_planejada.dart';
import '../lembretes/formato_lembretes.dart' show falarHorario;
import '../relatorios/formato_relatorios.dart' show juntarComE;
import '../shared/texto_narrado.dart';

// O que o narrador le em "Minha Rotina" ("Ouvir esta tela", RF 08.2): quantos
// itens do dia ja estao feitos e, principalmente, o que FALTA. Ouvir a lista
// inteira do que ja foi feito cansaria e nao ajuda: quem ouve quer saber o que
// ainda precisa fazer.
//
// Os itens contados sao os mesmos do "dia completo" dos relatorios: agua,
// remedios (se tem algum cadastrado), refeicoes (se o plano tem alguma),
// glicemia e insulina (so para diabeticos) e sono. O exercicio fica de fora da
// conta, porque a meta dele e da semana, e entra so numa frase no fim.
//
// [medicoesPendentes] e null para quem nao tem diabetes. [dosesPendentes] vem na
// ordem do dia, do primeiro horario para o ultimo.
String narrarRotina({
  required int aguaMl,
  required int metaAguaMl,
  required int dosesTotal,
  required List<DosePlanejada> dosesPendentes,
  required int refeicoesTotal,
  required int refeicoesFeitas,
  int? medicoesPendentes,
  bool insulinaPendente = false,
  required bool sonoRegistrado,
  required int exercicioMinutosNaSemana,
  required int exercicioMetaSemanal,
}) {
  // Cada item do dia: se esta feito e, se nao, o que fazer.
  final itens = <({bool feito, List<String> faltas})>[];

  if (metaAguaMl > 0) {
    final feito = aguaMl >= metaAguaMl;
    final copos = ((metaAguaMl - aguaMl) / MetaHidratacao.mlPorCopo).ceil();
    itens.add((
      feito: feito,
      faltas: feito
          ? const []
          : ['beber mais ${contar(copos, 'copo', 'copos')} de água'],
    ));
  }

  if (dosesTotal > 0) {
    itens.add((
      feito: dosesPendentes.isEmpty,
      faltas: [
        // Uma dose so: ja diz qual e a que horas. Varias: so quantas, e o
        // detalhe da primeira vem numa frase propria, depois da lista - com
        // virgulas dentro de um item da lista, ouvindo nao da para saber onde o
        // item acaba.
        if (dosesPendentes.length == 1)
          'tomar ${_descreverDose(dosesPendentes.first)}'
        else if (dosesPendentes.length > 1)
          'tomar ${dosesPendentes.length} remédios',
      ],
    ));
  }

  if (refeicoesTotal > 0) {
    final faltam = refeicoesTotal - refeicoesFeitas;
    itens.add((
      feito: faltam <= 0,
      faltas: faltam <= 0
          ? const []
          : ['fazer ${contar(faltam, 'refeição', 'refeições')}'],
    ));
  }

  if (medicoesPendentes != null) {
    itens.add((
      feito: medicoesPendentes == 0 && !insulinaPendente,
      faltas: [
        if (medicoesPendentes > 0)
          'fazer ${contar(medicoesPendentes, 'medição', 'medições')} da glicemia',
        if (insulinaPendente) 'registrar a insulina lenta',
      ],
    ));
  }

  itens.add((
    feito: sonoRegistrado,
    faltas: sonoRegistrado ? const [] : ['registrar o sono'],
  ));

  final feitos = itens.where((item) => item.feito).length;
  final faltas = [for (final item in itens) ...item.faltas];

  return montarTextoNarrado([
    'Sua rotina de hoje',
    if (faltas.isEmpty)
      'Parabéns! Tudo da rotina de hoje já está feito'
    else ...[
      'Você completou $feitos de ${contar(itens.length, 'item', 'itens')}',
      'Falta ${juntarComE(faltas)}',
      // Com varios remedios por tomar, diz por qual comecar.
      if (dosesPendentes.length > 1)
        'O primeiro remédio é ${_descreverDose(dosesPendentes.first, virgula: true)}',
    ],
    _fraseDoExercicio(exercicioMinutosNaSemana, exercicioMetaSemanal),
  ]);
}

// "Losartana 50 miligramas às 8 horas" - ou, com [virgula], "Losartana 50
// miligramas, às 8 horas", para quando a dose e o fim da frase.
String _descreverDose(DosePlanejada dose, {bool virgula = false}) {
  return '${falarDose(dose.descricao)}${virgula ? ',' : ''} '
      'às ${falarHorario(dose.horario)}';
}

String? _fraseDoExercicio(int minutosNaSemana, int metaSemanal) {
  if (metaSemanal <= 0) return null;
  if (minutosNaSemana >= metaSemanal) {
    return 'A meta de exercício da semana já foi batida';
  }
  return 'Nesta semana, $minutosNaSemana de $metaSemanal minutos de exercício';
}

// A rotina ainda nao chegou do servidor: falar "falta tudo" seria enganoso.
const String rotinaCarregandoNarrada =
    'Sua rotina de hoje ainda está carregando. Tente ouvir de novo em '
    'instantes.';

// Alguma parte da rotina nao carregou: os numeros nao sao confiaveis.
const String rotinaComErroNarrada =
    'Não foi possível carregar a sua rotina de hoje agora.';
