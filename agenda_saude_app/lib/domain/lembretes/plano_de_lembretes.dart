import '../../core/constants/pendencia_atividade.dart';
import '../models/registro_diabete.dart';
import '../models/registro_medicacao.dart';
import 'lembrete.dart';

// Id de 31 bits para o plugin de notificacoes, que so aceita inteiros de 32
// bits com sinal. Sai do texto (FNV-1a), entao o mesmo texto da sempre o mesmo
// id - em qualquer execucao do app, o que `String.hashCode` nao garante.
int idDaNotificacao(String texto) {
  var hash = 0x811c9dc5;
  for (final unidade in texto.codeUnits) {
    hash ^= unidade;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

// Um lembrete num dia especifico: e isto que vira uma notificacao agendada.
// Cada dia e uma notificacao propria (e nao uma repeticao diaria) porque o
// aviso de hoje precisa poder sumir quando o paciente registra, sem apagar o
// de amanha.
//
// Cada lembrete do dia tem tambem o aviso de pendencia (RF 06.3, [pendencia]):
// toca no horario-limite (o horario do lembrete mais a tolerancia de
// PendenciaAtividade) e some, como o lembrete, quando o paciente registra.
class OcorrenciaDeLembrete {
  // Comeco do payload de toda notificacao de lembrete: e como o app reconhece
  // as suas entre as agendadas no aparelho.
  static const String prefixoDoPayload = 'lembrete:';

  // Fim do id e do payload do aviso de pendencia.
  static const String sufixoDaPendencia = '#pendencia';

  final Lembrete lembrete;
  // Dia e hora em que o aviso toca, no horario do aparelho.
  final DateTime dataHora;
  final bool pendencia;

  const OcorrenciaDeLembrete(this.lembrete, this.dataHora)
      : pendencia = false;

  // O aviso de pendencia do lembrete que toca em [horarioDoLembrete].
  OcorrenciaDeLembrete.pendencia(this.lembrete, DateTime horarioDoLembrete)
      : dataHora = horarioDoLembrete.add(PendenciaAtividade.tolerancia),
        pendencia = true;

  // O dia da tarefa, que e o do lembrete: e por ele que o aviso de hoje some
  // quando o paciente registra hoje.
  DateTime get _diaDaTarefa => pendencia
      ? dataHora.subtract(PendenciaAtividade.tolerancia)
      : dataHora;

  String get _dia {
    final quando = _diaDaTarefa;
    final mes = quando.month.toString().padLeft(2, '0');
    final dia = quando.day.toString().padLeft(2, '0');
    return '${quando.year}-$mes-$dia';
  }

  String get _sufixo => pendencia ? sufixoDaPendencia : '';

  // O mesmo lembrete no mesmo dia tem sempre o mesmo id (e o aviso de
  // pendencia dele, outro id fixo).
  int get id => idDaNotificacao('${lembrete.chave}@$_dia$_sufixo');

  String get payload => '$prefixoDoPayload${lembrete.chave}@$_dia$_sufixo';

  String get titulo =>
      pendencia ? lembrete.tituloDaPendencia : lembrete.titulo;

  String get texto => pendencia ? lembrete.textoDaPendencia : lembrete.texto;
}

// O que o app precisa deixar agendado no aparelho agora.
class PlanoDeLembretes {
  // As notificacoes a agendar, da mais proxima para a mais distante.
  final List<OcorrenciaDeLembrete> agendar;
  // Ids dos lembretes de hoje que o paciente ja cumpriu. A notificacao de um
  // deles pode ja estar na bandeja (o horario passou) e precisa sair de la.
  final List<int> cumpridosHoje;

  const PlanoDeLembretes({
    this.agendar = const [],
    this.cumpridosHoje = const [],
  });
}

// Decide quais notificacoes de lembrete ficam agendadas no aparelho.
class PlanejadorDeLembretes {
  PlanejadorDeLembretes._();

  // Quantos dias a frente ficam agendados. Os dias seguintes entram sempre que
  // o app abre ou o paciente registra algo.
  static const int diasAFrente = 7;

  // O iOS aceita no maximo 64 notificacoes agendadas por app; ficar abaixo disso
  // evita perder as mais proximas. Vale a mais proxima primeiro. O limite e o
  // dos lembretes; os avisos de pendencia vem a mais (ver [diasDePendencia]).
  static const int limiteDeAgendamentos = 60;

  // Os avisos de pendencia (RF 06.3) ficam agendados so para hoje e amanha: o
  // app refaz o plano sempre que abre ou o paciente registra algo, e assim eles
  // nao tiram dos lembretes o lugar dos proximos dias no limite acima.
  static const int diasDePendencia = 2;

  // Um aviso para daqui a segundos nao chega a tempo de ser agendado (o plugin
  // recusa data que ja passou): fica de fora.
  static const Duration margem = Duration(seconds: 30);

  // As chaves dos lembretes que os registros de hoje cumprem: uma dose de remedio
  // marcada, ou um momento da glicemia registrado (medicao, insulina ou as duas).
  static Set<String> chavesCumpridas({
    Iterable<RegistroMedicacao> medicacoes = const [],
    Iterable<RegistroDiabete> diabete = const [],
  }) {
    return {
      for (final registro in medicacoes)
        Lembrete.chaveDoRemedio(registro.chave),
      for (final registro in diabete) ...[
        Lembrete.chaveDaGlicemia(registro.momento),
        Lembrete.chaveDaInsulina(registro.momento),
      ],
    };
  }

  // [cumpridosHoje] sao as chaves ja cumpridas hoje: o lembrete delas (e o
  // aviso de pendencia) some so de hoje, os dias seguintes continuam agendados.
  // O aviso de pendencia que passaria da meia-noite (tarefa depois das 23h)
  // fica so com o acompanhante: o app so acompanha os registros de hoje e nao
  // saberia se a tarefa de ontem foi feita.
  static PlanoDeLembretes planejar({
    required List<Lembrete> lembretes,
    required Set<String> cumpridosHoje,
    required DateTime agora,
    int dias = diasAFrente,
    int limite = limiteDeAgendamentos,
  }) {
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final inicio = agora.add(margem);

    final lembretesAgendados = <OcorrenciaDeLembrete>[];
    final pendencias = <OcorrenciaDeLembrete>[];
    final cumpridos = <int>[];

    for (var deslocamento = 0; deslocamento < dias; deslocamento++) {
      // Somar ao dia do calendario (e nao 24h) mantem o horario certo na
      // virada do horario de verao.
      final dia = DateTime(hoje.year, hoje.month, hoje.day + deslocamento);
      for (final lembrete in lembretes) {
        final horario = lembrete.em(dia);
        final ocorrencia = OcorrenciaDeLembrete(lembrete, horario);
        final pendencia = OcorrenciaDeLembrete.pendencia(lembrete, horario);
        final pendenciaNoMesmoDia = pendencia.dataHora.day == horario.day;
        if (deslocamento == 0 && cumpridosHoje.contains(lembrete.chave)) {
          cumpridos.add(ocorrencia.id);
          if (pendenciaNoMesmoDia) cumpridos.add(pendencia.id);
          continue;
        }
        if (ocorrencia.dataHora.isAfter(inicio)) {
          lembretesAgendados.add(ocorrencia);
        }
        if (deslocamento < diasDePendencia &&
            pendenciaNoMesmoDia &&
            pendencia.dataHora.isAfter(inicio)) {
          pendencias.add(pendencia);
        }
      }
    }

    lembretesAgendados.sort(_porHorario);
    return PlanoDeLembretes(
      agendar: [...lembretesAgendados.take(limite), ...pendencias]
        ..sort(_porHorario),
      cumpridosHoje: cumpridos,
    );
  }

  // Do aviso mais proximo para o mais distante; no mesmo horario, pela chave e,
  // da mesma chave, o lembrete antes do aviso de pendencia.
  static int _porHorario(OcorrenciaDeLembrete a, OcorrenciaDeLembrete b) {
    final porHora = a.dataHora.compareTo(b.dataHora);
    if (porHora != 0) return porHora;
    final porChave = a.lembrete.chave.compareTo(b.lembrete.chave);
    if (porChave != 0) return porChave;
    return (a.pendencia ? 1 : 0) - (b.pendencia ? 1 : 0);
  }
}
