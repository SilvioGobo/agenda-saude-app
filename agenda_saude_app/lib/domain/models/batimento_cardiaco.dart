class BatimentoCardiaco {
  final String id;
  final String pacienteId;
  final int bpm;
  final DateTime timestamp;

  BatimentoCardiaco({
    required this.id,
    required this.pacienteId,
    required this.bpm,
    required this.timestamp,
  });

  factory BatimentoCardiaco.fromJson(Map<String, dynamic> json, String documentId) {
    return BatimentoCardiaco(
      id: documentId,
      pacienteId: json['pacienteId'] ?? '',
      bpm: json['bpm'] ?? 0,
      timestamp: json['timestamp'] != null ? (json['timestamp']).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pacienteId': pacienteId,
      'bpm': bpm,
      'timestamp': timestamp,
    };
  }
}