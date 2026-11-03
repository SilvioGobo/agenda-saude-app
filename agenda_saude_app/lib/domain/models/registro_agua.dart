import 'registro_base.dart';

class RegistroAgua extends RegistroBase {
  final int quantidadeML;

  RegistroAgua({
    required super.id,
    required super.pacienteId,
    required super.dataHora,
    required this.quantidadeML,
  });

  factory RegistroAgua.fromJson(Map<String, dynamic> json, String documentId) {
    return RegistroAgua(
      id: documentId,
      pacienteId: json['pacienteId'] ?? '',
      dataHora: json['dataHora'] != null ? (json['dataHora']).toDate() : DateTime.now(),
      quantidadeML: json['quantidadeML'] ?? 0,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'tipo': 'agua',
      'pacienteId': pacienteId,
      'dataHora': dataHora,
      'quantidadeML': quantidadeML,
    };
  }
}