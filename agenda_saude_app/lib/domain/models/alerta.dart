class Alerta {
  final String id;
  final String pacienteId;
  final String mensagem;
  final DateTime dataHora;
  final bool lido;

  Alerta({
    required this.id,
    required this.pacienteId,
    required this.mensagem,
    required this.dataHora,
    this.lido = false,
  });

  factory Alerta.fromJson(Map<String, dynamic> json, String documentId) {
    return Alerta(
      id: documentId,
      pacienteId: json['pacienteId'] ?? '',
      mensagem: json['mensagem'] ?? '',
      dataHora: json['dataHora'] != null ? (json['dataHora']).toDate() : DateTime.now(),
      lido: json['lido'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pacienteId': pacienteId,
      'mensagem': mensagem,
      'dataHora': dataHora,
      'lido': lido,
    };
  }
}