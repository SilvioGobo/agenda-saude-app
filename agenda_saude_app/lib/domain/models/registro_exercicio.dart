import 'registro_base.dart';

class RegistroExercicio extends RegistroBase {
  final String tipoExercicio;
  final int duracaoMinutos;
  final String intensidade;

  RegistroExercicio({
    required String id,
    required String pacienteId,
    required DateTime dataHora,
    required this.tipoExercicio,
    required this.duracaoMinutos,
    required this.intensidade,
  }) : super(id: id, pacienteId: pacienteId, dataHora: dataHora);

  factory RegistroExercicio.fromJson(Map<String, dynamic> json, String documentId) {
    return RegistroExercicio(
      id: documentId,
      pacienteId: json['pacienteId'] ?? '',
      dataHora: json['dataHora'] != null ? (json['dataHora']).toDate() : DateTime.now(),
      tipoExercicio: json['tipoExercicio'] ?? '',
      duracaoMinutos: json['duracaoMinutos'] ?? 0,
      intensidade: json['intensidade'] ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'tipo': 'exercicio',
      'pacienteId': pacienteId,
      'dataHora': dataHora,
      'tipoExercicio': tipoExercicio,
      'duracaoMinutos': duracaoMinutos,
      'intensidade': intensidade,
    };
  }
}