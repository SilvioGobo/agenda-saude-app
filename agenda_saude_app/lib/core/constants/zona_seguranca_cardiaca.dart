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

  // Intervalo minimo entre dois avisos de "ATENÇÃO" ao acompanhante (RF06).
  // Um BPM oscilando na borda da zona (ex.: 99, 101, 98, 102) entra e sai de
  // "ATENÇÃO" a cada leitura; sem esse intervalo o acompanhante receberia
  // uma notificacao por oscilacao.
  static const Duration intervaloMinimoEntreAvisos = Duration(minutes: 15);

  // Ate quanto tempo depois de medida uma leitura ainda diz como o paciente
  // esta agora. Passado esse tempo, o card do acompanhante (Figura 15) mostra
  // "SEM DADOS", com o horario da ultima leitura, em vez de um "ESTÁVEL" que
  // pode nao valer mais (app do paciente fechado, relogio fora do pulso...).
  static const Duration validadeDaLeitura = Duration(hours: 1);

  static int bpmMinimo({required bool possuiCardiopatia}) =>
      possuiCardiopatia ? bpmMinimoCardiopata : bpmMinimoPadrao;

  static int bpmMaximo({required bool possuiCardiopatia}) =>
      possuiCardiopatia ? bpmMaximoCardiopata : bpmMaximoPadrao;

  static bool estaDentroDaZona(int bpm, {required bool possuiCardiopatia}) {
    return bpm >= bpmMinimo(possuiCardiopatia: possuiCardiopatia) &&
        bpm <= bpmMaximo(possuiCardiopatia: possuiCardiopatia);
  }

  static bool estaAcimaDaZona(int bpm, {required bool possuiCardiopatia}) {
    final maximo = possuiCardiopatia ? bpmMaximoCardiopata : bpmMaximoPadrao;
    return bpm > maximo;
  }
}
