// Exercicio fisico (RF03.3): o tipo, a duracao e a intensidade de cada
// atividade que o paciente faz, e a meta de minutos da semana.
//
// A meta de cada paciente vem de `Paciente.metas` (CalculadoraMetas: 150
// minutos por semana de atividade aerobica moderada, OMS 2020). Os 150 daqui so
// valem como padrao para quem ainda nao tem metas calculadas.
class MetaExercicio {
  MetaExercicio._();

  static const int minutosPorSemana = 150;

  // Cada registro vai de 5 minutos a 4 horas, de 5 em 5 minutos. A tela comeca
  // em 30: o tamanho de uma caminhada comum.
  static const int minutosMinimos = 5;
  static const int minutosMaximos = 240;
  static const int passoMinutos = 5;
  static const int minutosIniciais = 30;

  // Os exercicios oferecidos, em botoes grandes: digitar o nome nao e opcao
  // para quem tem dificuldade com o teclado (NF004). "Outro" cobre o resto.
  static const List<String> tipos = [
    'Caminhada',
    'Alongamento',
    'Hidroginástica',
    'Dança',
    'Bicicleta',
    'Fortalecimento',
    'Pilates ou yoga',
    'Outro',
  ];

  static const List<String> intensidades = ['Leve', 'Moderada', 'Intensa'];

  // Primeiro dia (as 00:00) da semana que contem [dia]. A semana comeca no
  // domingo, como o calendario dos relatorios.
  static DateTime inicioDaSemana(DateTime dia) =>
      DateTime(dia.year, dia.month, dia.day - dia.weekday % 7);
}
