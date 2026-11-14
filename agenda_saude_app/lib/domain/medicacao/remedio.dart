// Um remedio do catalogo (medicamentos com registro ativo na Anvisa, ver
// `assets/medicamentos/LEIAME.md`): o nome como no registro ("Novalgina",
// "Losartana potássica") e os principios ativos sem o sal ("Dipirona",
// "Losartana"), que sao o que a alergia compara. O remedio que o paciente
// digita por nao achar na lista vem sem principio ativo.
class Remedio {
  final String nome;
  final List<String> substancias;

  const Remedio({required this.nome, this.substancias = const []});

  factory Remedio.fromJson(Map<String, dynamic> json) {
    return Remedio(
      nome: json['nome'] ?? '',
      substancias: json['substancias'] is List
          ? List<String>.from(json['substancias'] as List)
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {'nome': nome, 'substancias': substancias};
  }

  // "Dipirona" ou "Cafeína, dipirona, orfenadrina".
  String get descricaoSubstancias {
    if (substancias.isEmpty) return '';
    final texto = substancias.join(', ');
    return texto[0] + texto.substring(1).toLowerCase();
  }
}
