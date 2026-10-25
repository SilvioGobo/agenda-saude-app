import '../metas/metas_personalizadas.dart';
import '../refeicoes/refeicoes_padrao.dart';
import 'refeicao_planejada.dart';
import 'usuario.dart';

class Paciente extends Usuario {
  final bool possuiDiabetes;
  final String? tipoDiabetes;
  final bool? usaInsulina;
  final String? tipoInsulina;
  final bool possuiCardiopatia;
  final String? tipoCardiopatia;
  final bool? usaMarcapasso;
  final String codigoVinculo;
  // Lado do paciente do vinculo bidirecional (RF05.4): espelha o
  // `pacientesVinculadosIds` do Acompanhante para o paciente saber quem o
  // monitora sem precisar consultar outros usuarios.
  final List<String> acompanhantesVinculadosIds;
  final bool triagemConcluida;

  // Dados fisicos/demograficos - usados para calcular IMC e personalizar
  // metas de hidratacao/exercicio/sono no futuro modulo de recomendacoes.
  final DateTime? dataNascimento;
  final String? sexoBiologico;
  final double? alturaCm;
  final double? pesoKg;
  final String? nivelAtividadeFisica;
  final String? alergias;
  final String? medicamentosEmUso;

  // Restricao de liquido definida pelo medico (ex.: insuficiencia cardiaca),
  // em ml por dia. Quando existe, a meta de hidratacao nunca passa dela.
  final int? limiteLiquidoMl;

  // Metas calculadas na triagem (ou recalculadas depois). Null em contas
  // anteriores a esse recurso: as telas caem nos valores padrao.
  final MetasPersonalizadas? metas;

  // Plano de refeicoes personalizado (RF03.4). Null = nunca personalizou; use
  // [planoDeRefeicoes], que cai no plano padrao.
  final List<RefeicaoPlanejada>? refeicoes;

  Paciente({
    required String id,
    required String nome,
    required String email,
    required String perfil,
    required this.possuiDiabetes,
    this.tipoDiabetes,
    this.usaInsulina,
    this.tipoInsulina,
    required this.possuiCardiopatia,
    this.tipoCardiopatia,
    this.usaMarcapasso,
    required this.codigoVinculo,
    this.acompanhantesVinculadosIds = const [],
    this.triagemConcluida = false,
    this.dataNascimento,
    this.sexoBiologico,
    this.alturaCm,
    this.pesoKg,
    this.nivelAtividadeFisica,
    this.alergias,
    this.medicamentosEmUso,
    this.limiteLiquidoMl,
    this.metas,
    this.refeicoes,
  }) : super(id: id, nome: nome, email: email, perfil: perfil);

  // Refeicoes que aparecem na rotina: as do paciente ou, enquanto ele nao
  // personalizou, o plano padrao para o perfil dele.
  List<RefeicaoPlanejada> get planoDeRefeicoes =>
      refeicoes ?? RefeicoesPadrao.para(possuiDiabetes: possuiDiabetes);

  // Do Firebase para o Dart
  factory Paciente.fromJson(Map<String, dynamic> json, String documentId) {
    return Paciente(
      id: documentId,
      nome: json['nome'] ?? '',
      email: json['email'] ?? '',
      perfil: json['perfil'] ?? 'Paciente',
      possuiDiabetes: json['possuiDiabetes'] ?? false,
      tipoDiabetes: json['tipoDiabetes'],
      usaInsulina: json['usaInsulina'],
      tipoInsulina: json['tipoInsulina'],
      possuiCardiopatia: json['possuiCardiopatia'] ?? false,
      tipoCardiopatia: json['tipoCardiopatia'],
      usaMarcapasso: json['usaMarcapasso'],
      codigoVinculo: json['codigoVinculo'] ?? '',
      acompanhantesVinculadosIds:
          List<String>.from(json['acompanhantesVinculadosIds'] ?? []),
      triagemConcluida: json['triagemConcluida'] ?? false,
      dataNascimento: json['dataNascimento'] != null
          ? (json['dataNascimento']).toDate()
          : null,
      sexoBiologico: json['sexoBiologico'],
      alturaCm: (json['alturaCm'] as num?)?.toDouble(),
      pesoKg: (json['pesoKg'] as num?)?.toDouble(),
      nivelAtividadeFisica: json['nivelAtividadeFisica'],
      alergias: json['alergias'],
      medicamentosEmUso: json['medicamentosEmUso'],
      limiteLiquidoMl: (json['limiteLiquidoMl'] as num?)?.toInt(),
      metas: json['metas'] is Map
          ? MetasPersonalizadas.fromJson(
              Map<String, dynamic>.from(json['metas'] as Map))
          : null,
      refeicoes: json['refeicoes'] is List
          ? (json['refeicoes'] as List)
              .map((refeicao) => RefeicaoPlanejada.fromJson(
                  Map<String, dynamic>.from(refeicao as Map)))
              .toList()
          : null,
    );
  }

  // Copia com os campos que mudam depois da triagem: o peso e o nivel de
  // atividade (atualizados ao recalcular), as metas e o plano de refeicoes.
  Paciente copyWith({
    double? pesoKg,
    String? nivelAtividadeFisica,
    MetasPersonalizadas? metas,
    List<RefeicaoPlanejada>? refeicoes,
  }) {
    return Paciente(
      id: id,
      nome: nome,
      email: email,
      perfil: perfil,
      possuiDiabetes: possuiDiabetes,
      tipoDiabetes: tipoDiabetes,
      usaInsulina: usaInsulina,
      tipoInsulina: tipoInsulina,
      possuiCardiopatia: possuiCardiopatia,
      tipoCardiopatia: tipoCardiopatia,
      usaMarcapasso: usaMarcapasso,
      codigoVinculo: codigoVinculo,
      acompanhantesVinculadosIds: acompanhantesVinculadosIds,
      triagemConcluida: triagemConcluida,
      dataNascimento: dataNascimento,
      sexoBiologico: sexoBiologico,
      alturaCm: alturaCm,
      pesoKg: pesoKg ?? this.pesoKg,
      nivelAtividadeFisica: nivelAtividadeFisica ?? this.nivelAtividadeFisica,
      alergias: alergias,
      medicamentosEmUso: medicamentosEmUso,
      limiteLiquidoMl: limiteLiquidoMl,
      metas: metas ?? this.metas,
      refeicoes: refeicoes ?? this.refeicoes,
    );
  }

  // Do Dart para o Firebase
  @override
  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'email': email,
      'perfil': perfil,
      'possuiDiabetes': possuiDiabetes,
      'tipoDiabetes': tipoDiabetes,
      'usaInsulina': usaInsulina,
      'tipoInsulina': tipoInsulina,
      'possuiCardiopatia': possuiCardiopatia,
      'tipoCardiopatia': tipoCardiopatia,
      'usaMarcapasso': usaMarcapasso,
      'codigoVinculo': codigoVinculo,
      'acompanhantesVinculadosIds': acompanhantesVinculadosIds,
      'triagemConcluida': triagemConcluida,
      'dataNascimento': dataNascimento,
      'sexoBiologico': sexoBiologico,
      'alturaCm': alturaCm,
      'pesoKg': pesoKg,
      'nivelAtividadeFisica': nivelAtividadeFisica,
      'alergias': alergias,
      'medicamentosEmUso': medicamentosEmUso,
      'limiteLiquidoMl': limiteLiquidoMl,
      'metas': metas?.toJson(),
      'refeicoes': refeicoes?.map((refeicao) => refeicao.toJson()).toList(),
    };
  }
}
