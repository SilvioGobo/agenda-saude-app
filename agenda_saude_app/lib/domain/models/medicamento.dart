// Um remedio do paciente (RF003, Figura 14 do TCC): o nome ("Losartana"), a
// dose ("50 mg", texto livre) e os horarios, em "HH:MM", em que ele toma. Fica
// numa lista dentro de `usuarios/{uid}.medicamentos`, e o `id` liga o remedio
// aos `RegistroMedicacao` do dia, entao precisa continuar o mesmo quando o
// paciente muda o nome, a dose ou os horarios.
class Medicamento {
  final String id;
  final String nome;
  final String dose;
  // Em "HH:MM", do mais cedo para o mais tarde.
  final List<String> horarios;

  const Medicamento({
    required this.id,
    required this.nome,
    this.dose = '',
    this.horarios = const [],
  });

  factory Medicamento.fromJson(Map<String, dynamic> json) {
    return Medicamento(
      id: json['id'] ?? '',
      nome: json['nome'] ?? '',
      dose: json['dose'] ?? '',
      horarios: json['horarios'] is List
          ? List<String>.from(json['horarios'] as List)
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'dose': dose,
      'horarios': horarios,
    };
  }

  // "Losartana 50 mg"; sem dose, so o nome.
  String get descricao => dose.trim().isEmpty ? nome : '$nome ${dose.trim()}';
}
