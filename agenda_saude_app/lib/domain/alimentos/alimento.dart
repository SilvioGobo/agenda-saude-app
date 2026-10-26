import 'nutrientes.dart';

// Um alimento do catalogo (Tabela Brasileira de Composicao de Alimentos -
// TACO, 4a edicao, NEPA/UNICAMP): nome e valores nutricionais por 100 g de
// parte comestivel. O `id` e o numero do alimento na Tabela 1 da TACO.
class Alimento {
  final int id;
  final String nome;
  final String? grupo;
  final int kcal;
  final double proteinaG;
  final double gorduraG;
  final double carboidratoG;
  final double fibraG;
  final int sodioMg;

  const Alimento({
    required this.id,
    required this.nome,
    this.grupo,
    required this.kcal,
    required this.proteinaG,
    required this.gorduraG,
    required this.carboidratoG,
    this.fibraG = 0,
    this.sodioMg = 0,
  });

  factory Alimento.fromJson(Map<String, dynamic> json) {
    return Alimento(
      id: (json['id'] as num).toInt(),
      nome: json['nome'] ?? '',
      grupo: json['grupo'],
      kcal: (json['kcal'] as num?)?.toInt() ?? 0,
      proteinaG: (json['proteinaG'] as num?)?.toDouble() ?? 0,
      gorduraG: (json['gorduraG'] as num?)?.toDouble() ?? 0,
      carboidratoG: (json['carboidratoG'] as num?)?.toDouble() ?? 0,
      fibraG: (json['fibraG'] as num?)?.toDouble() ?? 0,
      sodioMg: (json['sodioMg'] as num?)?.toInt() ?? 0,
    );
  }

  // O que [gramas] deste alimento fornecem.
  Nutrientes paraGramas(double gramas) {
    final fator = gramas / 100;
    return Nutrientes(
      kcal: kcal * fator,
      proteinaG: proteinaG * fator,
      gorduraG: gorduraG * fator,
      carboidratoG: carboidratoG * fator,
      fibraG: fibraG * fator,
      sodioMg: sodioMg * fator,
    );
  }
}
