class Alerta {
  // Niveis de alerta gerados a partir do BPM do smartwatch:
  // - atencao: o painel do paciente acabou de passar a mostrar "ATENÇÃO"
  //   (leitura mais recente fora da zona de seguranca) - RF06;
  // - emergencia: BPM fora da zona por tempo prolongado (UC04.4 -> UC06).
  static const String tipoAtencao = 'atencao';
  static const String tipoEmergencia = 'emergencia';

  final String id;
  final String pacienteId;
  final String tipo;
  final String mensagem;
  // Leitura de BPM que disparou o alerta, quando houver.
  final int? bpm;
  final DateTime dataHora;
  final bool lido;

  Alerta({
    required this.id,
    required this.pacienteId,
    required this.tipo,
    required this.mensagem,
    this.bpm,
    required this.dataHora,
    this.lido = false,
  });

  bool get ehEmergencia => tipo == tipoEmergencia;

  factory Alerta.fromJson(Map<String, dynamic> json, String documentId) {
    return Alerta(
      id: documentId,
      pacienteId: json['pacienteId'] ?? '',
      // alertas gravados antes de existir o campo eram todos de emergencia
      tipo: json['tipo'] ?? tipoEmergencia,
      mensagem: json['mensagem'] ?? '',
      bpm: json['bpm'],
      dataHora: json['dataHora'] != null ? (json['dataHora']).toDate() : DateTime.now(),
      lido: json['lido'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pacienteId': pacienteId,
      'tipo': tipo,
      'mensagem': mensagem,
      'bpm': bpm,
      'dataHora': dataHora,
      'lido': lido,
    };
  }
}
