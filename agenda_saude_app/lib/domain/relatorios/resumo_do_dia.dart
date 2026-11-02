import '../../core/constants/faixas_glicemia.dart';
import '../../core/constants/meta_hidratacao.dart';
import '../../core/constants/momentos_glicemia.dart';
import '../models/alerta.dart';
import '../models/refeicao_planejada.dart';
import '../models/registro_diabete.dart';
import '../models/registro_refeicao.dart';

// Como foi um dia da rotina do paciente (RF05). "Completo": todos os itens da
// rotina dele foram cumpridos (meta de agua, todas as refeicoes e, para
// diabeticos, o checklist de glicemia inteiro). "Parcial": ha registro, mas
// falta algo. "Sem registro": nada foi anotado.
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

  const BatimentosDoDia({
    required this.leituras,
    this.media,
    this.minimo,
    this.maximo,
    this.foraDaZona = 0,
    required this.zonaMinima,
    required this.zonaMaxima,
  });

  bool get temLeituras => leituras > 0;
}

// Resumo de um dia da rotina do paciente: o que o relatorio mostra para o
// paciente e para o acompanhante.
class ResumoDoDia {
  final DateTime dia;
  final HidratacaoDoDia hidratacao;
  final RefeicoesDoDia refeicoes;
  // Null para quem nao tem diabetes.
  final DiabetesDoDia? diabetes;
  final BatimentosDoDia batimentos;
  // Alertas gerados no dia, do mais recente para o mais antigo.
  final List<Alerta> alertas;

  const ResumoDoDia({
    required this.dia,
    required this.hidratacao,
    required this.refeicoes,
    required this.diabetes,
    required this.batimentos,
    required this.alertas,
  });

  // So a rotina conta como "registro": batimentos e alertas vem sozinhos do
  // smartwatch, nao de algo que o paciente fez.
  bool get temRegistros =>
      hidratacao.registrou ||
      refeicoes.registrou ||
      (diabetes?.registrou ?? false);

  // Itens da rotina que se aplicam a este paciente: agua, refeicoes (se o plano
  // tem alguma) e glicemia (se tem diabetes).
  int get itensTotais =>
      1 + (refeicoes.total > 0 ? 1 : 0) + (diabetes != null ? 1 : 0);

  int get itensCompletos =>
      (hidratacao.metaAtingida ? 1 : 0) +
      (refeicoes.todasFeitas ? 1 : 0) +
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
