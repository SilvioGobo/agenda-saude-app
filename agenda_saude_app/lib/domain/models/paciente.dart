import 'usuario.dart';

class Paciente extends Usuario {
  final bool possuiDiabetes;
  final bool possuiCardiopatia;
  final String codigoVinculo;

  Paciente({
    required String id,
    required String nome,
    required String email,
    required String perfil,
    required this.possuiDiabetes,
    required this.possuiCardiopatia,
    required this.codigoVinculo,
  }) : super(id: id, nome: nome, email: email, perfil: perfil);

  // Do Firebase para o Dart
  factory Paciente.fromJson(Map<String, dynamic> json, String documentId) {
    return Paciente(
      id: documentId,
      nome: json['nome'] ?? '',
      email: json['email'] ?? '',
      perfil: json['perfil'] ?? 'Paciente',
      possuiDiabetes: json['possuiDiabetes'] ?? false,
      possuiCardiopatia: json['possuiCardiopatia'] ?? false,
      codigoVinculo: json['codigoVinculo'] ?? '',
    );
  }

  // Do Dart para o Firebase
  @override
  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'email': email,
      'perfil': perfil,
      'possuiDiabetes': possuiDiabetes,
      'possuiCardiopatia': possuiCardiopatia,
      'codigoVinculo': codigoVinculo,
    };
  }
}