abstract class Usuario {
  final String id;
  final String nome;
  final String email;
  final String perfil;
  // Opcional: contas criadas antes do campo nao tem telefone. Sem ele as
  // telas escondem o botao de ligar para a pessoa (Figuras 13 e 16).
  final String? telefone;

  Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.perfil,
    this.telefone,
  });

  // Ha telefone para ligar (nao nulo nem em branco).
  bool get temTelefone => telefone?.trim().isNotEmpty ?? false;

  Map<String, dynamic> toJson();
}
