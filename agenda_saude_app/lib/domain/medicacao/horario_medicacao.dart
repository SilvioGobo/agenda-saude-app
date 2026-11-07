// O horario de uma dose de remedio, sempre guardado como "HH:MM" ("08:00").

// O horario no formato "HH:MM" a partir do que a pessoa digitar: "0800", "800",
// "8:00", "08:00", "8h30" ou so a hora ("8", "20"). Devolve null quando nao e
// um horario (a hora vai de 0 a 23 e os minutos de 0 a 59).
String? normalizarHorario(String entrada) {
  final texto = entrada.trim();

  int hora;
  int minuto;
  final comSeparador = RegExp(r'^(\d{1,2})[:hH.](\d{2})$').firstMatch(texto);
  if (comSeparador != null) {
    hora = int.parse(comSeparador.group(1)!);
    minuto = int.parse(comSeparador.group(2)!);
  } else if (RegExp(r'^\d{3,4}$').hasMatch(texto)) {
    // "800" e "0800": os dois ultimos digitos sao os minutos.
    final digitos = texto.padLeft(4, '0');
    hora = int.parse(digitos.substring(0, 2));
    minuto = int.parse(digitos.substring(2));
  } else if (RegExp(r'^\d{1,2}$').hasMatch(texto)) {
    hora = int.parse(texto);
    minuto = 0;
  } else {
    return null;
  }

  if (hora > 23 || minuto > 59) return null;
  return '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}';
}
