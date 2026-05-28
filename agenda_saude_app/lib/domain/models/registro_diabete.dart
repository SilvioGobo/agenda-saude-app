import 'registro_base.dart';

class RegistroDiabete extends RegistroBase {
  final double nivelGlicose;
  final String momento;
  final double doseInsulina;
  final String tipoInsulina;

  RegistroDiabete({
    required String id,
    required String pacienteId,
    required DateTime dataHora,
    required this.nivelGlicose,
    required this.momento,
    required this.doseInsulina,
    required this.tipoInsulina,
  }) : super(id: id, pacienteId: pacienteId, dataHora: dataHora);

  factory RegistroDiabete.fromJson(Map<String, dynamic> json, String documentId) {
    return RegistroDiabete(
      id: documentId,
      pacienteId: json['pacienteId'] ?? '',
      dataHora: json['dataHora'] != null ? (json['dataHora']).toDate() : DateTime.now(),
      nivelGlicose: (json['nivelGlicose'] ?? 0).toDouble(),
      momento: json['momento'] ?? '',
      doseInsulina: (json['doseInsulina'] ?? 0).toDouble(),
      tipoInsulina: json['tipoInsulina'] ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'tipo': 'diabete',
      'pacienteId': pacienteId,
      'dataHora': dataHora,
      'nivelGlicose': nivelGlicose,
      'momento': momento,
      'doseInsulina': doseInsulina,
      'tipoInsulina': tipoInsulina,
    };
  }
}