import '../../core/constants/momentos_glicemia.dart';
import '../medicacao/dose_planejada.dart';
import '../medicacao/horario_medicacao.dart';
import '../models/paciente.dart';

// O que o lembrete avisa; define o titulo da notificacao.
enum TipoLembrete { remedio, glicemia, insulina }

// Um aviso diario do paciente (RF 07.3): tomar um remedio, medir a glicemia ou
// aplicar a insulina lenta, sempre no mesmo horario "HH:MM". A [chave] e a
// mesma que liga o registro do dia ao item do checklist, e e ela que faz o aviso
// sumir quando o paciente registra.
class Lembrete {
  final String chave;
  final TipoLembrete tipo;
  final String titulo;
  final String texto;
  // O aviso em poucas palavras, para a lista da tela de lembretes ("Tomar
  // Losartana 50 mg").
  final String resumo;
  // O que e, sem o verbo: o remedio com a dose ("Losartana 50 mg"), o momento
  // da glicemia ("Ao acordar") ou "Insulina lenta". Vai no aviso de pendencia
  // (RF 06.3), no aparelho e no push do acompanhante.
  final String descricao;
  // Em "HH:MM".
  final String horario;
  // O momento da glicemia (`MomentoGlicemia.nome`) de um lembrete de glicemia ou
  // de insulina, para o paciente mudar o horario dele; null nos remedios, cujo
  // horario se muda em "Meus remedios".
  final String? nomeDoMomento;

  const Lembrete({
    required this.chave,
    required this.tipo,
    required this.titulo,
    required this.texto,
    required this.resumo,
    this.descricao = '',
    required this.horario,
    this.nomeDoMomento,
  });

  // O aviso de pendencia (RF 06.3): toca no horario-limite, se o paciente ainda
  // nao registrou a tarefa.
  String get tituloDaPendencia {
    switch (tipo) {
      case TipoLembrete.remedio:
        return 'Remédio ainda não marcado';
      case TipoLembrete.glicemia:
        return 'Glicemia ainda não anotada';
      case TipoLembrete.insulina:
        return 'Insulina ainda não anotada';
    }
  }

  String get textoDaPendencia {
    final oQue = descricao.isEmpty ? '' : '$descricao, ';
    switch (tipo) {
      case TipoLembrete.remedio:
        return '${oQue}das $horario. Se já tomou, marque em Minha Rotina.';
      case TipoLembrete.glicemia:
        return '${oQue}das $horario. Se já mediu, anote em Minha Rotina.';
      case TipoLembrete.insulina:
        return '${oQue}das $horario. Se já aplicou, anote em Minha Rotina.';
    }
  }

  // A tarefa como vai para `usuarios/{uid}.tarefasDiarias`: e por essa lista
  // que a Cloud Function `verificarPendencias` sabe o que conferir e quando
  // (RF 06.3, "verificacao automatica da lista de tarefas diarias").
  Map<String, dynamic> toJsonTarefa() {
    return {
      'chave': chave,
      'tipo': tipo.name,
      'descricao': descricao,
      'horario': horario,
    };
  }

  int get hora => int.parse(horario.substring(0, 2));

  int get minuto => int.parse(horario.substring(3, 5));

  // O instante deste lembrete no [dia], no horario do aparelho.
  DateTime em(DateTime dia) =>
      DateTime(dia.year, dia.month, dia.day, hora, minuto);

  // A dose de um remedio (a mesma chave de `RegistroMedicacao.chave`).
  static String chaveDoRemedio(String chaveDaDose) => 'remedio|$chaveDaDose';

  // A medicao de glicemia de um momento do dia ([nomeDoMomento] e o que
  // `RegistroDiabete.momento` guarda, ex.: "Ao acordar").
  static String chaveDaGlicemia(String nomeDoMomento) =>
      'glicemia|$nomeDoMomento';

  // A insulina de um momento do dia (a lenta das 22h).
  static String chaveDaInsulina(String nomeDoMomento) =>
      'insulina|$nomeDoMomento';

  // Todos os lembretes do paciente, do primeiro horario do dia para o ultimo:
  // uma notificacao por dose de remedio e, para diabeticos (RF 07.3), uma por
  // medicao de glicemia e a da insulina lenta de quem usa insulina.
  // [horariosDosMomentos] sao os horarios que o paciente escolheu para os
  // momentos da glicemia (nome do momento -> "HH:MM"); sem escolha, vale o
  // horario padrao do momento. Horario que nao e valido e ignorado.
  static List<Lembrete> doPaciente(
    Paciente paciente, {
    Map<String, String> horariosDosMomentos = const {},
  }) {
    final lembretes = <Lembrete>[];

    for (final dose in DosePlanejada.doDia(paciente.medicamentos)) {
      final horario = normalizarHorario(dose.horario);
      if (horario == null) continue;
      lembretes.add(
        Lembrete(
          chave: chaveDoRemedio(dose.chave),
          tipo: TipoLembrete.remedio,
          titulo: 'Hora do remédio',
          texto: '${dose.descricao}. Depois de tomar, marque em Minha Rotina.',
          resumo: 'Tomar ${dose.descricao}',
          descricao: dose.descricao,
          horario: horario,
        ),
      );
    }

    if (paciente.possuiDiabetes) {
      final momentos =
          MomentoGlicemia.doDia(usaInsulina: paciente.usaInsulina == true);
      for (final momento in momentos) {
        final horario = _horarioDoMomento(momento, horariosDosMomentos);
        if (horario == null) continue;
        lembretes.add(
          momento.medeGlicemia
              ? Lembrete(
                  chave: chaveDaGlicemia(momento.nome),
                  tipo: TipoLembrete.glicemia,
                  titulo: 'Hora de medir a glicemia',
                  texto:
                      '${momento.nome}. Depois de medir, anote em Minha Rotina.',
                  resumo: 'Medir a glicemia (${_minuscula(momento.nome)})',
                  descricao: momento.nome,
                  horario: horario,
                  nomeDoMomento: momento.nome,
                )
              : Lembrete(
                  chave: chaveDaInsulina(momento.nome),
                  tipo: TipoLembrete.insulina,
                  titulo: 'Hora da insulina lenta',
                  texto: 'Aplique a dose e anote em Minha Rotina.',
                  resumo: 'Aplicar a insulina lenta',
                  descricao: 'Insulina lenta',
                  horario: horario,
                  nomeDoMomento: momento.nome,
                ),
        );
      }
    }

    lembretes.sort((a, b) {
      final porHorario = a.horario.compareTo(b.horario);
      return porHorario != 0 ? porHorario : a.chave.compareTo(b.chave);
    });
    return lembretes;
  }

  static String _minuscula(String texto) =>
      texto.isEmpty ? texto : texto[0].toLowerCase() + texto.substring(1);

  static String? _horarioDoMomento(
    MomentoGlicemia momento,
    Map<String, String> escolhidos,
  ) {
    final escolhido = escolhidos[momento.nome];
    final normalizado = escolhido == null ? null : normalizarHorario(escolhido);
    return normalizado ?? momento.horarioPadrao;
  }
}
