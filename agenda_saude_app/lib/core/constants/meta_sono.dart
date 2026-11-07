// Sono (RF03.2): quantas horas o paciente dormiu e como foi a qualidade do
// descanso, numa escala de 1 a 5.
//
// A meta de cada paciente vem de `Paciente.metas` (CalculadoraMetas, a partir
// da idade). Os 7 a 9 horas daqui - a faixa da National Sleep Foundation para
// adultos - so valem como padrao para quem ainda nao tem metas calculadas.
class MetaSono {
  MetaSono._();

  static const int minHoras = 7;
  static const int maxHoras = 9;

  // O registro da noite vai de meia hora a 14 horas, de meia em meia hora. A
  // tela comeca na meta minima: a maioria das noites fica perto dela.
  static const double horasMinimas = 0.5;
  static const double horasMaximas = 14;
  static const double passoHoras = 0.5;
  static const double horasIniciais = 7;

  // "Avaliacao qualitativa (ex.: escala de 1 a 5)" do RF 03.2.
  static const int qualidadeMinima = 1;
  static const int qualidadeMaxima = 5;
}
