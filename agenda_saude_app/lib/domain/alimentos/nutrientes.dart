// Quantidade de energia e nutrientes de um alimento, refeicao ou dia. Os
// valores sao somaveis: o total do dia e a soma dos totais das refeicoes.
class Nutrientes {
  final double kcal;
  final double proteinaG;
  final double gorduraG;
  final double carboidratoG;
  final double fibraG;
  final double sodioMg;

  const Nutrientes({
    this.kcal = 0,
    this.proteinaG = 0,
    this.gorduraG = 0,
    this.carboidratoG = 0,
    this.fibraG = 0,
    this.sodioMg = 0,
  });

  static const Nutrientes zero = Nutrientes();

  Nutrientes operator +(Nutrientes outro) {
    return Nutrientes(
      kcal: kcal + outro.kcal,
      proteinaG: proteinaG + outro.proteinaG,
      gorduraG: gorduraG + outro.gorduraG,
      carboidratoG: carboidratoG + outro.carboidratoG,
      fibraG: fibraG + outro.fibraG,
      sodioMg: sodioMg + outro.sodioMg,
    );
  }

  static Nutrientes somar(Iterable<Nutrientes> valores) {
    return valores.fold(zero, (soma, valor) => soma + valor);
  }
}
