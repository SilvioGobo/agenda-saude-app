abstract class RegistroBase {
  final String id;
  final String pacienteId;
  final DateTime dataHora;

  RegistroBase({
    required this.id,
    required this.pacienteId,
    required this.dataHora,
  });

  Map<String, dynamic> toJson();
}