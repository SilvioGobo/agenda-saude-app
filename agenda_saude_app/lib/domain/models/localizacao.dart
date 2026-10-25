// Ultima localizacao conhecida do paciente, que os acompanhantes vinculados
// consultam para saber onde ele esta. Um unico doc por paciente na colecao
// `localizacoes`, com o doc id igual ao UID dele: cada atualizacao sobrescreve
// a anterior, entao o app nao guarda o caminho que o paciente fez (NF005).
//
// `ativo` diz se o paciente esta compartilhando. Ao desligar, o doc fica so
// com `ativo: false`, sem coordenadas; ao ligar, as coordenadas chegam assim
// que o GPS do celular dele encontrar a posicao.
class Localizacao {
  final String pacienteId;
  final bool ativo;
  final double? latitude;
  final double? longitude;
  // Raio de incerteza informado pelo GPS, em metros.
  final double? precisaoMetros;
  // Momento em que o GPS mediu a posicao (nao o da gravacao no Firestore).
  final DateTime? dataHora;

  Localizacao({
    required this.pacienteId,
    required this.ativo,
    this.latitude,
    this.longitude,
    this.precisaoMetros,
    this.dataHora,
  });

  bool get temPosicao =>
      latitude != null && longitude != null && dataHora != null;

  factory Localizacao.fromJson(Map<String, dynamic> json, String documentId) {
    return Localizacao(
      pacienteId: json['pacienteId'] ?? documentId,
      ativo: json['ativo'] ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      precisaoMetros: (json['precisaoMetros'] as num?)?.toDouble(),
      dataHora: json['dataHora'] != null ? (json['dataHora']).toDate() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pacienteId': pacienteId,
      'ativo': ativo,
      'latitude': latitude,
      'longitude': longitude,
      'precisaoMetros': precisaoMetros,
      'dataHora': dataHora,
    };
  }
}
