import 'registro_base.dart';

// Uma noite de sono (RF03.2). O paciente informa so as horas dormidas e a
// qualidade (1 a 5) e registra ao acordar: por isso `dataHora` e `dataFim`
// guardam o mesmo instante, o do registro. Ele tambem decide a que dia a noite
// pertence na rotina e nos relatorios - a noite conta no dia em que a pessoa
// acorda, e as consultas por dia (pacienteId + tipo + dataHora) funcionam como
// nos outros registros. O inicio do sono e `dataFim` menos `horasTotais`.
class RegistroSono extends RegistroBase {
  final DateTime dataFim;
  final double horasTotais;
  final int qualidade;

  RegistroSono({
    required super.id,
    required super.pacienteId,
    required super.dataHora, // Instante do registro (ao acordar)
    required this.dataFim,
    required this.horasTotais,
    required this.qualidade,
  });

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