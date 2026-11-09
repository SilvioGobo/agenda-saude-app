import '../../domain/models/alerta.dart';
import '../relatorios/formato_relatorios.dart'
    show capitalizar, primeiroNomeDe;
import '../shared/texto_narrado.dart';
import 'formato_alertas.dart' show mancheteDoAlerta;

// O que o narrador le nas telas de alerta ("Ouvir esta tela", RF 08.2).

// Quantas notificacoes a lista le em voz alta: as mais novas. Ler todas
// cansaria, e as outras estao na tela.
const int _maximoDeNotificacoesLidas = 3;

// A lista ainda nao chegou: dizer "nenhuma notificacao" seria enganoso.
const String notificacoesCarregandoNarradas =
    'As notificações ainda estão carregando. Tente ouvir de novo em instantes.';

// A tela de Notificacoes: quantas ha para ler e as mais recentes, com quem e o
// paciente, o que aconteceu, os batimentos (so nos alertas de BPM) e ha quanto
// tempo. Sao lidas primeiro as
// nao lidas; se todas ja foram lidas, so a ultima. [alertas] vem do mais
// recente para o mais antigo, como na tela.
String narrarNotificacoes({
  required List<Alerta> alertas,
  required String Function(String pacienteId) nomeDoPaciente,
  required DateTime agora,
}) {
  if (alertas.isEmpty) {
    return montarTextoNarrado([
      'Nenhuma notificação por enquanto',
      'Quando algum paciente precisar de atenção, você será avisado aqui e no '
          'celular',
    ]);
  }

  String ler(Alerta alerta) {
    final paciente = primeiroNomeDe(nomeDoPaciente(alerta.pacienteId));
    // A manchete e a da faixa do topo do painel do acompanhante, uma por tipo de
    // alerta: emergencia e atencao (batimentos), pendencia de atividade e sem
    // dados do smartwatch. Dizer "atencao" para todos os que nao sao emergencia
    // enganaria: a pendencia e o "sem dados" nao tem a ver com os batimentos.
    final manchete = mancheteDoAlerta(alerta, paciente);
    final bpm = alerta.ehDeBatimento && alerta.bpm != null
        ? ': ${alerta.bpm} batimentos por minuto'
        : '';
    return '$manchete$bpm, ${falarQuando(alerta.dataHora, agora)}';
  }

  final naoLidos = alertas.where((alerta) => !alerta.lido).toList();
  if (naoLidos.isEmpty) {
    return montarTextoNarrado([
      'Nenhuma notificação nova',
      'A última foi: ${ler(alertas.first)}',
    ]);
  }

  final lidos = naoLidos.take(_maximoDeNotificacoesLidas);
  final restantes = naoLidos.length - lidos.length;
  return montarTextoNarrado([
    'Você tem '
        '${contar(naoLidos.length, 'notificação não lida', 'notificações não lidas')}',
    ...lidos.map(ler),
    if (restantes > 0)
      'E mais ${contar(restantes, 'notificação', 'notificações')}',
  ]);
}

// A tela de emergencia do acompanhante (Figura 16): o aviso, quem esta mal e
// com quais batimentos, e o que fazer. E o texto que o narrador fala sozinho ao
// abrir a tela e que o botao repete.
//
// [nomePaciente] e o primeiro nome (ou "o paciente"); [motivo] e o motivo do
// alerta em letras minusculas ("batimentos cardíacos elevados").
String narrarEmergencia({
  required String nomePaciente,
  required String motivo,
  int? bpm,
  required DateTime dataHora,
  required DateTime agora,
  required bool podeLigarParaPaciente,
  required bool temLocalizacao,
}) {
  final batimentos = bpm == null ? '' : ': $bpm batimentos por minuto';
  final contato = podeLigarParaPaciente
      ? 'Ligue agora para $nomePaciente para saber como está'
      : 'Fale com $nomePaciente agora para saber como está';

  return montarTextoNarrado([
    'Alerta crítico!',
    capitalizar(
      '$nomePaciente está com $motivo$batimentos, ${falarQuando(dataHora, agora)}',
    ),
    contato,
    // O numero soletrado: "cento e noventa e dois" nao e como se fala o 192.
    'Se não atender ou relatar mal-estar, ligue para o SAMU, número um, nove, dois',
    if (temLocalizacao)
      'Toque em Ver localização para saber onde $nomePaciente está',
  ]);
}
