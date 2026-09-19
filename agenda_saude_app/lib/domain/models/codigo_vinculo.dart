// Entrada da colecao `codigos_vinculo`, usada pelo Acompanhante para descobrir
// qual Paciente esta por tras de um codigo (RF05.4). O doc id e o proprio
// codigo, entao a consulta e um `get` direto - o que permite que as security
// rules liberem so a leitura pontual, sem expor a lista de pacientes nem o
// documento completo do paciente antes do vinculo existir (NF005).
class CodigoVinculo {
  final String codigo;
  final String pacienteId;
  final String nomePaciente;

  CodigoVinculo({
    required this.codigo,
    required this.pacienteId,
    required this.nomePaciente,
  });

  factory CodigoVinculo.fromJson(Map<String, dynamic> json, String documentId) {
    return CodigoVinculo(
      codigo: documentId,
      pacienteId: json['pacienteId'] ?? '',
      nomePaciente: json['nomePaciente'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pacienteId': pacienteId,
      'nomePaciente': nomePaciente,
    };
  }
}
