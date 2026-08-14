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
    this.triagemConcluida = false,
    this.dataNascimento,
    this.sexoBiologico,
    this.alturaCm,
    this.pesoKg,
    this.nivelAtividadeFisica,
    this.alergias,
    this.medicamentosEmUso,
  }) : super(id: id, nome: nome, email: email, perfil: perfil);

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
      'triagemConcluida': triagemConcluida,
      'dataNascimento': dataNascimento,
      'sexoBiologico': sexoBiologico,
      'alturaCm': alturaCm,
      'pesoKg': pesoKg,
      'nivelAtividadeFisica': nivelAtividadeFisica,
      'alergias': alergias,
      'medicamentosEmUso': medicamentosEmUso,
    };
  }
}
