import 'registro_base.dart';

class RegistroSono extends RegistroBase {
  final DateTime dataFim;
  final double horasTotais;
  final int qualidade;

  RegistroSono({
    required String id,
    required String pacienteId,
    required DateTime dataHora, // Representa o início do sono
    required this.dataFim,
    required this.horasTotais,
    required this.qualidade,
  }) : super(id: id, pacienteId: pacienteId, dataHora: dataHora);

  factory RegistroSono.fromJson(Map<String, dynamic> json, String documentId) {
    return RegistroSono(
      id: documentId,
      pacienteId: json['pacienteId'] ?? '',
      dataHora: json['dataHora'] != null ? (json['dataHora']).toDate() : DateTime.now(),
      dataFim: json['dataFim'] != null ? (json['dataFim']).toDate() : DateTime.now(),
      horasTotais: (json['horasTotais'] ?? 0).toDouble(),
      qualidade: json['qualidade'] ?? 0,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'tipo': 'sono',
      'pacienteId': pacienteId,
      'dataHora': dataHora,
      'dataFim': dataFim,
      'horasTotais': horasTotais,
      'qualidade': qualidade,
    };
  }
}