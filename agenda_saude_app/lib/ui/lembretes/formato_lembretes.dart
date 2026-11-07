// Como os horarios dos lembretes aparecem e sao falados.

// "08:30" para o leitor de tela: "8 horas e 30 minutos"; "08:00": "8 horas".
String falarHorario(String horario) {
  final hora = int.parse(horario.substring(0, 2));
  final minuto = int.parse(horario.substring(3, 5));
  final horas = hora == 1 ? '1 hora' : '$hora horas';
  if (minuto == 0) return horas;
  final minutos = minuto == 1 ? '1 minuto' : '$minuto minutos';
  return '$horas e $minutos';
}
