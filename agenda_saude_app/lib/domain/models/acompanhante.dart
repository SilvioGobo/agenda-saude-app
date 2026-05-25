import 'usuario.dart';

class Acompanhante extends Usuario {
  final List<String> pacientesVinculadosIds;

  Acompanhante({
    required String id,
    required String nome,
    required String email,
    required String perfil,
    required this.pacientesVinculadosIds,
  }) : super(id: id, nome: nome, email: email, perfil: perfil);

  factory Acompanhante.fromJson(Map<String, dynamic> json, String documentId) {
    return Acompanhante(
      id: documentId,
      nome: json['nome'] ?? '',
      email: json['email'] ?? '',
      perfil: json['perfil'] ?? 'Acompanhante',

      pacientesVinculadosIds: List<String>.from(json['pacientesVinculadosIds'] ?? []),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'email': email,
      'perfil': perfil,
      'pacientesVinculadosIds': pacientesVinculadosIds,
    };
  }
}