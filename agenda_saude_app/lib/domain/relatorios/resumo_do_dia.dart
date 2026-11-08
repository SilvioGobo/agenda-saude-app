import '../../core/constants/faixas_glicemia.dart';
import '../../core/constants/meta_hidratacao.dart';
import '../../core/constants/momentos_glicemia.dart';
import '../medicacao/dose_planejada.dart';
import '../models/alerta.dart';
import '../models/medicamento.dart';
import '../models/refeicao_planejada.dart';
import '../models/registro_diabete.dart';
import '../models/registro_exercicio.dart';
import '../models/registro_medicacao.dart';
import '../models/registro_refeicao.dart';
import '../models/registro_sono.dart';
import 'serie_de_batimentos.dart';

// Como foi um dia da rotina do paciente (RF05). "Completo": todos os itens da
// rotina dele foram cumpridos (meta de agua, todas as refeicoes, todas as doses
// de remedio, o registro do sono e, para diabeticos, o checklist de glicemia
// inteiro). O exercicio nao
// entra nessa conta: a meta dele e da semana, nao do dia, e um dia de descanso
// nao deixa a rotina incompleta - mas um dia so com exercicio ja tem registro.
// "Parcial": ha registro, mas falta algo. "Sem registro": nada foi anotado.
enum SituacaoDoDia { semRegistro, parcial, completo }

// Agua do dia frente a meta do paciente.
class HidratacaoDoDia {
  final int totalMl;
  final int metaMl;
  // Quantos registros de copo existem; zero = nenhuma agua foi anotada.
  final int registros;

  const HidratacaoDoDia({
    required this.totalMl,
    required this.metaMl,
    required this.registros,
  });

  int get copos => totalMl ~/ MetaHidratacao.mlPorCopo;

  int get metaCopos => metaMl ~/ MetaHidratacao.mlPorCopo;

  // De 0 a 1; passar da meta nao estoura a barra.
  double get progresso =>
      metaMl <= 0 ? 0 : (totalMl / metaMl).clamp(0.0, 1.0).toDouble();

  bool get registrou => registros > 0;

  bool get metaAtingida => registrou && totalMl >= metaMl;
}

// Uma refeicao do plano e, se o paciente a marcou, quando.
class RefeicaoDoDia {
  final RefeicaoPlanejada refeicao;
  final DateTime? feitaEm;

  const RefeicaoDoDia({required this.refeicao, this.feitaEm});

  bool get feita => feitaEm != null;
}

// Refeicoes do plano do paciente e quais ele marcou como feitas no dia.
class RefeicoesDoDia {
  final List<RefeicaoDoDia> planejadas;
  // Refeicoes marcadas que nao estao mais no plano (ele o mudou depois): nao
  // contam como "feitas" do plano, mas continuam sendo registro do dia.
  final List<RegistroRefeicao> foraDoPlano;

  const RefeicoesDoDia({required this.planejadas, this.foraDoPlano = const []});

  // Cada refeicao vale uma vez por dia: se foi marcada em dois aparelhos,
  // vale a primeira marcacao.
  factory RefeicoesDoDia.de({
    required List<RefeicaoPlanejada> plano,
    required List<RegistroRefeicao> registros,
  }) {
    final primeiraMarcacao = <String, RegistroRefeicao>{};
    for (final registro in registros) {
      final atual = primeiraMarcacao[registro.refeicaoId];
      if (atual == null || registro.dataHora.isBefore(atual.dataHora)) {
        primeiraMarcacao[registro.refeicaoId] = registro;
      }
    }

    final idsDoPlano = plano.map((refeicao) => refeicao.id).toSet();
    return RefeicoesDoDia(
      planejadas: [
        for (final refeicao in plano)
          RefeicaoDoDia(
            refeicao: refeicao,
            feitaEm: primeiraMarcacao[refeicao.id]?.dataHora,
          ),
      ],
      foraDoPlano: primeiraMarcacao.values
          .where((registro) => !idsDoPlano.contains(registro.refeicaoId))
          .toList()
        ..sort((a, b) => a.dataHora.compareTo(b.dataHora)),
    );
  }

  int get feitas => planejadas.where((item) => item.feita).length;

  int get total => planejadas.length;

  bool get todasFeitas => total > 0 && feitas == total;

  // De 0 a 1.
  double get progresso => total == 0 ? 0 : feitas / total;

  bool get registrou => feitas > 0 || foraDoPlano.isNotEmpty;
}

// Uma dose do dia (um remedio num horario) e, se o paciente a marcou, quando.
class DoseDoDia {
  final DosePlanejada dose;
  final DateTime? tomadaEm;

  const DoseDoDia({required this.dose, this.tomadaEm});

  bool get tomada => tomadaEm != null;
}

// As doses de remedio do paciente no dia (RF003) e quais ele marcou como
// tomadas. Usa a lista de remedios de HOJE: ela nao tem historico, entao mudar
// os remedios muda a leitura dos dias antigos - como no plano de refeicoes.
class MedicacaoDoDia {
  final List<DoseDoDia> planejadas;
  // Doses marcadas que nao estao mais na lista (o paciente mudou o remedio ou o
  // horario depois): nao contam como "tomadas" da lista, mas continuam sendo
  // registro do dia.
  final List<RegistroMedicacao> foraDoPlano;

  const MedicacaoDoDia({required this.planejadas, this.foraDoPlano = const []});

  // Cada dose vale uma vez por dia: se foi marcada em dois aparelhos, vale a
  // primeira marcacao.
  factory MedicacaoDoDia.de({
    required List<Medicamento> medicamentos,
    required List<RegistroMedicacao> registros,
  }) {
    final primeiraMarcacao = <String, RegistroMedicacao>{};
    for (final registro in registros) {
      final atual = primeiraMarcacao[registro.chave];
      if (atual == null || registro.dataHora.isBefore(atual.dataHora)) {
        primeiraMarcacao[registro.chave] = registro;
      }
    }

    final doses = DosePlanejada.doDia(medicamentos);
    final chavesDoPlano = doses.map((dose) => dose.chave).toSet();
    return MedicacaoDoDia(
      planejadas: [
        for (final dose in doses)
          DoseDoDia(dose: dose, tomadaEm: primeiraMarcacao[dose.chave]?.dataHora),
      ],
      foraDoPlano: primeiraMarcacao.entries
          .where((entrada) => !chavesDoPlano.contains(entrada.key))
          .map((entrada) => entrada.value)
          .toList()
        ..sort((a, b) => a.dataHora.compareTo(b.dataHora)),
    );
  }

  int get tomadas => planejadas.where((item) => item.tomada).length;

  int get total => planejadas.length;

  bool get todasTomadas => total > 0 && tomadas == total;

  // De 0 a 1.
  double get progresso => total == 0 ? 0 : tomadas / total;

  bool get registrou => tomadas > 0 || foraDoPlano.isNotEmpty;
}

// A noite de sono do dia frente a meta do paciente (RF03.2). O paciente
// registra ao acordar, entao a noite conta no dia em que ele acordou. Para o
// "dia completo" basta ter registrado a noite: o paciente nao controla o quanto
// dormiu, e anotar uma noite ruim nao deve deixar o dia incompleto.
class SonoDoDia {
  // A noite registrada no dia; null = o paciente nao registrou.
  final RegistroSono? registro;
  final int metaMinHoras;
  final int metaMaxHoras;

  const SonoDoDia({
    this.registro,
    required this.metaMinHoras,
    required this.metaMaxHoras,
  });

  // Se ha mais de uma noite no dia (dois aparelhos), vale a mais recente, como
  // no cartao da rotina.
  factory SonoDoDia.de(
    List<RegistroSono> registros, {
    required int metaMinHoras,
    required int metaMaxHoras,
  }) {
    RegistroSono? maisRecente;
    for (final registro in registros) {
      if (maisRecente == null || registro.dataHora.isAfter(maisRecente.dataHora)) {
        maisRecente = registro;
      }
    }
    return SonoDoDia(
      registro: maisRecente,
      metaMinHoras: metaMinHoras,
      metaMaxHoras: metaMaxHoras,
    );
  }

  bool get registrou => registro != null;

  // Dormiu pelo menos o minimo da meta; passar do maximo nao tira a meta.
  bool get metaAtingida {
    final noite = registro;
    return noite != null && noite.horasTotais >= metaMinHoras;
  }
}

// Os exercicios do dia (RF03.3) e, quando se sabe, o progresso da meta de
// minutos da semana ate o fim desse dia. A meta e semanal (150 min, OMS), entao
// o exercicio so conta como registro do dia, nunca como item que falta.
class ExercicioDoDia {
  // Os exercicios do dia, do mais antigo para o mais recente.
  final List<RegistroExercicio> registros;
  // Minutos de exercicio da semana (domingo a sabado) ate o fim deste dia; null
  // quando so se leu o dia (o resumo do mes), sem a semana inteira.
  final int? minutosNaSemana;
  final int metaSemanalMinutos;

  const ExercicioDoDia({
    this.registros = const [],
    this.minutosNaSemana,
    required this.metaSemanalMinutos,
  });

  // [daSemana]: os exercicios da semana ate o fim do dia, quando foram lidos.
  factory ExercicioDoDia.de(
    List<RegistroExercicio> doDia, {
    List<RegistroExercicio>? daSemana,
    required int metaSemanalMinutos,
  }) {
    return ExercicioDoDia(
      registros: [...doDia]..sort((a, b) => a.dataHora.compareTo(b.dataHora)),
      minutosNaSemana: daSemana?.fold<int>(
        0,
        (soma, registro) => soma + registro.duracaoMinutos,
      ),
      metaSemanalMinutos: metaSemanalMinutos,
    );
  }

  bool get fez => registros.isNotEmpty;

  int get minutos => registros.fold(
        0,
        (soma, registro) => soma + registro.duracaoMinutos,
      );

  bool get temProgressoDaSemana => minutosNaSemana != null;

  // De 0 a 1; passar da meta nao estoura a barra.
  double get progressoDaSemana {
    final semana = minutosNaSemana;
    if (semana == null || metaSemanalMinutos <= 0) return 0;
    return (semana / metaSemanalMinutos).clamp(0.0, 1.0).toDouble();
  }

  bool get metaDaSemanaAtingida {
    final semana = minutosNaSemana;
    return semana != null && semana >= metaSemanalMinutos;
  }

  // Quanto faltava para a meta da semana ao fim do dia; zero se ja foi atingida
  // (ou se a semana nao foi lida).
  int get minutosQueFaltavam {
    final semana = minutosNaSemana;
    if (semana == null || semana >= metaSemanalMinutos) return 0;
    return metaSemanalMinutos - semana;
  }
}

// Um item fixo do checklist de glicemia e o registro feito nele (null se
// ficou pendente).
class ItemGlicemiaDoDia {
  final MomentoGlicemia momento;
  final RegistroDiabete? registro;

  const ItemGlicemiaDoDia({required this.momento, this.registro});

  bool get feito => registro != null;
}

// Numeros das glicemias de um conjunto de registros (um dia ou um mes). As
// faixas sao as de [FaixasGlicemia]: "baixas" e tudo abaixo de 70 mg/dL, "altas"
// tudo acima de 180 e "muito altas" tudo acima de 250 (estas tambem contam
// como altas).
class EstatisticasGlicemia {
  final int medicoes;
  final double? media;
  final double? menor;
  final double? maior;
  final int naFaixa;
  final int baixas;
  final int altas;
  final int muitoAltas;

  const EstatisticasGlicemia({
    required this.medicoes,
    this.media,
    this.menor,
    this.maior,
    this.naFaixa = 0,
    this.baixas = 0,
    this.altas = 0,
    this.muitoAltas = 0,
  });

  factory EstatisticasGlicemia.de(Iterable<RegistroDiabete> registros) {
    final valores = registros
        .where((registro) => registro.temGlicemia)
        .map((registro) => registro.nivelGlicose!)
        .toList();
    if (valores.isEmpty) return const EstatisticasGlicemia(medicoes: 0);

    var naFaixa = 0, baixas = 0, altas = 0, muitoAltas = 0;
    for (final valor in valores) {
      switch (FaixasGlicemia.classificar(valor)) {
        case ClassificacaoGlicemia.muitoBaixa:
        case ClassificacaoGlicemia.baixa:
          baixas++;
        case ClassificacaoGlicemia.naFaixa:
          naFaixa++;
        case ClassificacaoGlicemia.alta:
          altas++;
        case ClassificacaoGlicemia.muitoAlta:
          altas++;
          muitoAltas++;
      }
    }

    return EstatisticasGlicemia(
      medicoes: valores.length,
      media: valores.reduce((a, b) => a + b) / valores.length,
      menor: valores.reduce((a, b) => a < b ? a : b),
      maior: valores.reduce((a, b) => a > b ? a : b),
      naFaixa: naFaixa,
      baixas: baixas,
      altas: altas,
      muitoAltas: muitoAltas,
    );
  }

  // Hipoglicemia ou glicemia muito alta: as duas que o app trata como alerta
  // de saude (vermelho).
  bool get temCritica => baixas > 0 || muitoAltas > 0;
}

// Glicemia e insulina do dia (RF008); so existe para quem tem diabetes.
class DiabetesDoDia {
  // Os momentos fixos do dia na ordem da tela de rotina.
  final List<ItemGlicemiaDoDia> checklist;
  // Registros fora dos momentos fixos ("Outra medição"), do mais antigo para
  // o mais recente.
  final List<RegistroDiabete> outrasMedicoes;
  // Todos os registros do dia, do mais antigo para o mais recente.
  final List<RegistroDiabete> registros;
  final EstatisticasGlicemia glicemia;
  // Soma das doses aplicadas e quantas aplicacoes foram.
  final double insulinaTotal;
  final int aplicacoes;

  const DiabetesDoDia({
    required this.checklist,
    required this.outrasMedicoes,
    required this.registros,
    required this.glicemia,
    required this.insulinaTotal,
    required this.aplicacoes,
  });

  factory DiabetesDoDia.de(
    List<RegistroDiabete> registros, {
    required bool usaInsulina,
  }) {
    final ordenados = [...registros]
      ..sort((a, b) => a.dataHora.compareTo(b.dataHora));
    final momentos = MomentoGlicemia.doDia(usaInsulina: usaInsulina);
    final nomesFixos = momentos.map((momento) => momento.nome).toSet();

    final checklist = momentos.map((momento) {
      // Se o momento foi registrado mais de uma vez, vale o mais recente.
      RegistroDiabete? registro;
      for (final candidato in ordenados) {
        if (candidato.momento == momento.nome) registro = candidato;
      }
      return ItemGlicemiaDoDia(momento: momento, registro: registro);
    }).toList();

    final doses = ordenados.where((registro) => registro.temInsulina);
    return DiabetesDoDia(
      checklist: checklist,
      outrasMedicoes: ordenados
          .where((registro) => !nomesFixos.contains(registro.momento))
          .toList(),
      registros: ordenados,
      glicemia: EstatisticasGlicemia.de(ordenados),
      insulinaTotal: doses.fold(0.0, (soma, r) => soma + r.doseInsulina!),
      aplicacoes: doses.length,
    );
  }

  // Medicoes de glicemia previstas no dia (4) e quantas foram feitas.
  int get medicoesPrevistas =>
      checklist.where((item) => item.momento.medeGlicemia).length;

  int get medicoesFeitas => checklist
      .where((item) => item.momento.medeGlicemia && item.feito)
      .length;

  bool get completo => checklist.every((item) => item.feito);

  bool get registrou => registros.isNotEmpty;
}

// Batimentos do smartwatch no dia, na zona de seguranca do paciente (a dos
// cardiopatas e mais estreita).
class BatimentosDoDia {
  final int leituras;
  final double? media;
  final int? minimo;
  final int? maximo;
  // Leituras abaixo do minimo ou acima do maximo da zona.
  final int foraDaZona;
  final int zonaMinima;
  final int zonaMaxima;
  // A curva do dia para o grafico (RF 04.3): as leituras resumidas em um ponto a
  // cada 10 minutos. Null quando so se contaram as leituras, sem o dia.
  final SerieDeBatimentos? serie;

  const BatimentosDoDia({
    required this.leituras,
    this.media,
    this.minimo,
    this.maximo,
    this.foraDaZona = 0,
    required this.zonaMinima,
    required this.zonaMaxima,
    this.serie,
  });

  bool get temLeituras => leituras > 0;

  // Ha curva para desenhar.
  bool get temSerie => serie != null && !serie!.vazia;
}

// Resumo de um dia da rotina do paciente: o que o relatorio mostra para o
// paciente e para o acompanhante.
class ResumoDoDia {
  final DateTime dia;
  final HidratacaoDoDia hidratacao;
  final RefeicoesDoDia refeicoes;
  final MedicacaoDoDia medicacao;
  final SonoDoDia sono;
  final ExercicioDoDia exercicio;
  // Null para quem nao tem diabetes.
  final DiabetesDoDia? diabetes;
  final BatimentosDoDia batimentos;
  // Alertas gerados no dia, do mais recente para o mais antigo.
  final List<Alerta> alertas;

  const ResumoDoDia({
    required this.dia,
    required this.hidratacao,
    required this.refeicoes,
    required this.medicacao,
    required this.sono,
    required this.exercicio,
    required this.diabetes,
    required this.batimentos,
    required this.alertas,
  });

  // So a rotina conta como "registro": batimentos e alertas vem sozinhos do
  // smartwatch, nao de algo que o paciente fez.
  bool get temRegistros =>
      hidratacao.registrou ||
      refeicoes.registrou ||
      medicacao.registrou ||
      sono.registrou ||
      exercicio.fez ||
      (diabetes?.registrou ?? false);

  // Itens da rotina que se aplicam a este paciente: agua, refeicoes (se o plano
  // tem alguma), remedios (se tem algum cadastrado), sono e glicemia (se tem
  // diabetes).
  int get itensTotais =>
      1 +
      (refeicoes.total > 0 ? 1 : 0) +
      (medicacao.total > 0 ? 1 : 0) +
      1 +
      (diabetes != null ? 1 : 0);

  int get itensCompletos =>
      (hidratacao.metaAtingida ? 1 : 0) +
      (refeicoes.todasFeitas ? 1 : 0) +
      (medicacao.todasTomadas ? 1 : 0) +
      (sono.registrou ? 1 : 0) +
      (diabetes?.completo == true ? 1 : 0);

  SituacaoDoDia get situacao {
    if (!temRegistros) return SituacaoDoDia.semRegistro;
    return itensCompletos == itensTotais
        ? SituacaoDoDia.completo
        : SituacaoDoDia.parcial;
  }

  int get emergencias => alertas.where((alerta) => alerta.ehEmergencia).length;

  // Alertas de "atencao" (BPM saiu da zona, sem chegar a emergencia).
  int get avisos => alertas.length - emergencias;

  // Algo que o acompanhante precisa ver: emergencia de batimentos, hipoglicemia
  // ou glicemia muito alta.
  bool get temAlertaGrave =>
      emergencias > 0 || (diabetes?.glicemia.temCritica ?? false);
}
