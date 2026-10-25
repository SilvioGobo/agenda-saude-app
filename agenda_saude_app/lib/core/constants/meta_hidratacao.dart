// Meta diaria de hidratacao (RF03.1). O mockup do checklist (Figura 14 do TCC)
// conta a agua em copos - "5/8 copos" -, entao a meta e de 8 copos de 250 ml,
// os 2 litros por dia que sao a orientacao geral para adultos. O documento nao
// fixa o valor: se a equipe medica pedir outra meta (ex.: restricao de liquido
// para cardiopata), e so mudar aqui.
class MetaHidratacao {
  MetaHidratacao._();

  static const int mlPorCopo = 250;
  static const int copos = 8;
  static const int mlDiaria = mlPorCopo * copos;
}
