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

  static bool estaDentroDaZona(int bpm, {required bool possuiCardiopatia}) {
    final minimo = possuiCardiopatia ? bpmMinimoCardiopata : bpmMinimoPadrao;
    final maximo = possuiCardiopatia ? bpmMaximoCardiopata : bpmMaximoPadrao;
    return bpm >= minimo && bpm <= maximo;
  }
}
