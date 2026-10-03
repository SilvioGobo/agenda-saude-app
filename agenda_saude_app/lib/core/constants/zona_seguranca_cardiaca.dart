// Limites de batimentos por minuto (BPM) em repouso considerados dentro da
// normalidade (UC04.4). Pacientes com cardiopatia usam uma margem mais
// estreita, já que a triagem (RF02.3) determina que os alertas cardíacos
// tenham prioridade para eles.
class ZonaSegurancaCardiaca {
  ZonaSegurancaCardiaca._();

  static const int bpmMinimoPadrao = 60;
  static const int bpmMaximoPadrao = 100;

  static const int bpmMinimoCardiopata = 60;
  static const int bpmMaximoCardiopata = 90;

  // Quanto tempo seguido fora da zona caracteriza "tempo prolongado" (UC04.4)
  // e dispara o alerta de emergencia (UC06). O documento nao fixa o valor;
  // 5 minutos evita alarme falso por um pico isolado (ex.: subir escada).
  static const Duration tempoProlongadoParaAlerta = Duration(minutes: 5);

  static int bpmMinimo({required bool possuiCardiopatia}) =>
      possuiCardiopatia ? bpmMinimoCardiopata : bpmMinimoPadrao;

  static int bpmMaximo({required bool possuiCardiopatia}) =>
      possuiCardiopatia ? bpmMaximoCardiopata : bpmMaximoPadrao;

  static bool estaDentroDaZona(int bpm, {required bool possuiCardiopatia}) {
    return bpm >= bpmMinimo(possuiCardiopatia: possuiCardiopatia) &&
        bpm <= bpmMaximo(possuiCardiopatia: possuiCardiopatia);
  }
}
