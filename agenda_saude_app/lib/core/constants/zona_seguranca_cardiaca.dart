import '../../domain/models/limites_alerta.dart';

// Limites de batimentos por minuto (BPM) em repouso considerados dentro da
// normalidade (UC04.4). Pacientes com cardiopatia usam uma margem mais
// estreita, ja que a triagem (RF02.3) determina que os alertas cardiacos
// tenham prioridade para eles.
//
// O acompanhante pode trocar esses padroes pelos limites do paciente (RF 06.1,
// [LimitesAlerta]): todas as contas abaixo recebem os [limites] do paciente e,
// sem eles, usam os padroes pela triagem. Assim o alerta com o app aberto, o
// alerta com o app fechado, o painel, o card do acompanhante e os relatorios
// usam sempre a mesma zona.
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

  static int bpmMinimo({
    required bool possuiCardiopatia,
    LimitesAlerta? limites,
  }) =>
      limites?.bpmMinimo ??
      (possuiCardiopatia ? bpmMinimoCardiopata : bpmMinimoPadrao);

  static int bpmMaximo({
    required bool possuiCardiopatia,
    LimitesAlerta? limites,
  }) =>
      limites?.bpmMaximo ??
      (possuiCardiopatia ? bpmMaximoCardiopata : bpmMaximoPadrao);

  static bool estaDentroDaZona(
    int bpm, {
    required bool possuiCardiopatia,
    LimitesAlerta? limites,
  }) {
    return bpm >=
            bpmMinimo(possuiCardiopatia: possuiCardiopatia, limites: limites) &&
        bpm <= bpmMaximo(possuiCardiopatia: possuiCardiopatia, limites: limites);
  }

  static bool estaAcimaDaZona(
    int bpm, {
    required bool possuiCardiopatia,
    LimitesAlerta? limites,
  }) {
    return bpm >
        bpmMaximo(possuiCardiopatia: possuiCardiopatia, limites: limites);
  }
}
