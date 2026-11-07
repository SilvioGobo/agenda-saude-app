import '../models/medicamento.dart';

// Uma dose que o paciente deve tomar no dia: um remedio num horario. O
// checklist "Medicacoes" tem uma linha por dose (Figura 14: "Losartana 50mg
// 08:00"); um remedio tomado em dois horarios sao duas doses.
class DosePlanejada {
  final String medicamentoId;
  final String nome;
  final String dose;
  // Em "HH:MM".
  final String horario;

  const DosePlanejada({
    required this.medicamentoId,
    required this.nome,
    this.dose = '',
    required this.horario,
  });

  // O que liga a dose aos registros do dia: o mesmo remedio em dois horarios
  // tem duas chaves.
  String get chave => '$medicamentoId|$horario';

  // "Losartana 50 mg"; sem dose, so o nome.
  String get descricao => dose.trim().isEmpty ? nome : '$nome ${dose.trim()}';

  // Todas as doses dos [medicamentos], do primeiro horario do dia para o
  // ultimo; no mesmo horario, em ordem de nome.
  static List<DosePlanejada> doDia(List<Medicamento> medicamentos) {
    final doses = [
      for (final medicamento in medicamentos)
        for (final horario in medicamento.horarios)
          DosePlanejada(
            medicamentoId: medicamento.id,
            nome: medicamento.nome,
            dose: medicamento.dose,
            horario: horario,
          ),
    ];
    doses.sort((a, b) {
      final porHorario = a.horario.compareTo(b.horario);
      return porHorario != 0 ? porHorario : a.nome.compareTo(b.nome);
    });
    return doses;
  }
}
