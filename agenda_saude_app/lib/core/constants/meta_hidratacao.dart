// Hidratacao (RF03.1). O mockup do checklist (Figura 14 do TCC) conta a agua
// em copos - "5/8 copos" -, entao tudo e medido em copos de 250 ml.
//
// A meta de cada paciente vem de `Paciente.metas` (CalculadoraMetas, a partir
// da triagem). Os 8 copos / 2 litros daqui, a orientacao geral para adultos,
// so valem como padrao para quem ainda nao tem metas calculadas.
class MetaHidratacao {
  MetaHidratacao._();

  static const int mlPorCopo = 250;
  static const int copos = 8;
  static const int mlDiaria = mlPorCopo * copos;
}
