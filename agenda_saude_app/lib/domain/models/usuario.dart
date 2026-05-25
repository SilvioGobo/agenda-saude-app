abstract class Usuario {
  final String id;
  final String nome;
  final String email;
  final String perfil;

  Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.perfil,
  });


  Map<String, dynamic> toJson();
}