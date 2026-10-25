import 'registro_base.dart';

// Registro do controle de diabetes (RF008, UC "Gerenciar Uso de Insulina"):
// uma medicao de glicemia e/ou uma aplicacao de insulina em um [momento] do
// dia (ex.: "Ao acordar"). Os dois valores sao opcionais porque nem todo
// registro tem os dois: quem tem diabetes tipo 2 sem insulina so mede a
// glicemia, e a insulina lenta das 22h e so a dose.
class RegistroDiabete extends RegistroBase {
  // mg/dL; null quando o registro e so de insulina.
  final double? nivelGlicose;
  final String momento;
  // Unidades aplicadas; null quando nao houve aplicacao.
  final double? doseInsulina;
  final String? tipoInsulina;

  RegistroDiabete({
    required String id,
    required String pacienteId,
    required DateTime dataHora,
    this.nivelGlicose,
    required this.momento,
    this.doseInsulina,
    this.tipoInsulina,
  }) : super(id: id, pacienteId: pacienteId, dataHora: dataHora);

  bool get temGlicemia => nivelGlicose != null;

  bool get temInsulina => doseInsulina != null;

  factory RegistroDiabete.fromJson(Map<String, dynamic> json, String documentId) {
    return RegistroDiabete(
      id: documentId,
      pacienteId: json['pacienteId'] ?? '',
      dataHora: json['dataHora'] != null ? (json['dataHora']).toDate() : DateTime.now(),
      nivelGlicose: (json['nivelGlicose'] as num?)?.toDouble(),
      momento: json['momento'] ?? '',
      doseInsulina: (json['doseInsulina'] as num?)?.toDouble(),
      tipoInsulina: json['tipoInsulina'],
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
