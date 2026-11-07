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
class OcorrenciaDeLembrete {
  // Comeco do payload de toda notificacao de lembrete: e como o app reconhece
  // as suas entre as agendadas no aparelho.
  static const String prefixoDoPayload = 'lembrete:';

  final Lembrete lembrete;
  // Dia e hora no horario do aparelho.
  final DateTime dataHora;

  const OcorrenciaDeLembrete(this.lembrete, this.dataHora);

  String get _dia {
    final mes = dataHora.month.toString().padLeft(2, '0');
    final dia = dataHora.day.toString().padLeft(2, '0');
    return '${dataHora.year}-$mes-$dia';
  }

  // O mesmo lembrete no mesmo dia tem sempre o mesmo id.
  int get id => idDaNotificacao('${lembrete.chave}@$_dia');

  String get payload => '$prefixoDoPayload${lembrete.chave}@$_dia';
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
  // evita perder as mais proximas. Vale a mais proxima primeiro.
  static const int limiteDeAgendamentos = 60;

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

  // [cumpridosHoje] sao as chaves ja cumpridas hoje: o lembrete delas some so
  // de hoje, os dias seguintes continuam agendados.
  static PlanoDeLembretes planejar({
    required List<Lembrete> lembretes,
    required Set<String> cumpridosHoje,
    required DateTime agora,
    int dias = diasAFrente,
    int limite = limiteDeAgendamentos,
  }) {
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final inicio = agora.add(margem);

    final agendar = <OcorrenciaDeLembrete>[];
    final cumpridos = <int>[];

    for (var deslocamento = 0; deslocamento < dias; deslocamento++) {
      // Somar ao dia do calendario (e nao 24h) mantem o horario certo na
      // virada do horario de verao.
      final dia = DateTime(hoje.year, hoje.month, hoje.day + deslocamento);
      for (final lembrete in lembretes) {
        final ocorrencia = OcorrenciaDeLembrete(lembrete, lembrete.em(dia));
        if (deslocamento == 0 && cumpridosHoje.contains(lembrete.chave)) {
          cumpridos.add(ocorrencia.id);
          continue;
        }
        if (ocorrencia.dataHora.isAfter(inicio)) agendar.add(ocorrencia);
      }
    }

    agendar.sort((a, b) {
      final porHora = a.dataHora.compareTo(b.dataHora);
      return porHora != 0
          ? porHora
          : a.lembrete.chave.compareTo(b.lembrete.chave);
    });

    return PlanoDeLembretes(
      agendar: agendar.take(limite).toList(),
      cumpridosHoje: cumpridos,
    );
  }
}
