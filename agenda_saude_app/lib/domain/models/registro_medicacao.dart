import 'registro_base.dart';

// "Esta dose foi tomada": um registro por dose (remedio + horario) marcada como
// tomada no dia (RF003, Figura 14). Desmarcar apaga o registro. Guarda o nome e
// a dose do remedio na hora da marcacao para o historico continuar legivel se
// o paciente mudar ou apagar o remedio depois. `dataHora` e o instante em que
// ele marcou; `horario` e o horario previsto da dose ("08:00").
class RegistroMedicacao extends RegistroBase {
  final String medicamentoId;
  final String horario;
  final String nome;
  final String dose;

  RegistroMedicacao({
    required super.id,
    required super.pacienteId,
    required super.dataHora,
    required this.medicamentoId,
    required this.horario,
    required this.nome,
    this.dose = '',
  });

  factory RegistroMedicacao.fromJson(
    Map<String, dynamic> json,
    String documentId,
  ) {
    return RegistroMedicacao(
      id: documentId,
      pacienteId: json['pacienteId'] ?? '',
      dataHora: json['dataHora'] != null
          ? (json['dataHora']).toDate()
          : DateTime.now(),
      medicamentoId: json['medicamentoId'] ?? '',
      horario: json['horario'] ?? '',
      nome: json['nome'] ?? '',
      dose: json['dose'] ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'tipo': 'medicacao',
      'pacienteId': pacienteId,
      'dataHora': dataHora,
      'medicamentoId': medicamentoId,
      'horario': horario,
      'nome': nome,
      'dose': dose,
    };
  }

  // Identifica a dose que este registro marca: a mesma de `DosePlanejada.chave`.
  String get chave => '$medicamentoId|$horario';

  // "Losartana 50 mg"; sem dose, so o nome.
  String get descricao => dose.trim().isEmpty ? nome : '$nome ${dose.trim()}';
}
