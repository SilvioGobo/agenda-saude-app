import 'registro_base.dart';

// "Esta refeicao foi feita": um registro por refeicao marcada como concluida no
// dia (RF03.4). Desmarcar apaga o registro. Guarda o nome da refeicao na hora
// da marcacao para o historico continuar legivel se o plano mudar depois.
class RegistroRefeicao extends RegistroBase {
  final String refeicaoId;
  final String nome;

  RegistroRefeicao({
    required super.id,
    required super.pacienteId,
    required super.dataHora,
    required this.refeicaoId,
    required this.nome,
  });

  factory RegistroRefeicao.fromJson(
    Map<String, dynamic> json,
    String documentId,
  ) {
    return RegistroRefeicao(
      id: documentId,
      pacienteId: json['pacienteId'] ?? '',
      dataHora: json['dataHora'] != null
          ? (json['dataHora']).toDate()
          : DateTime.now(),
      refeicaoId: json['refeicaoId'] ?? '',
      nome: json['nome'] ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'tipo': 'refeicao',
      'pacienteId': pacienteId,
      'dataHora': dataHora,
      'refeicaoId': refeicaoId,
      'nome': nome,
    };
  }
}
