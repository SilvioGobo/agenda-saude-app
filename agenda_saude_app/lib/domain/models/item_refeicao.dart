import '../alimentos/catalogo_alimentos.dart';
import '../alimentos/nutrientes.dart';

// Um alimento numa refeicao do plano, com a quantidade em gramas. Guarda o
// nome para a refeicao continuar legivel mesmo que o catalogo mude; os
// nutrientes sempre saem do catalogo, pelo `alimentoId`.
class ItemRefeicao {
  final int alimentoId;
  final String nome;
  final double quantidadeG;

  const ItemRefeicao({
    required this.alimentoId,
    required this.nome,
    required this.quantidadeG,
  });

  factory ItemRefeicao.fromJson(Map<String, dynamic> json) {
    return ItemRefeicao(
      alimentoId: (json['alimentoId'] as num?)?.toInt() ?? 0,
      nome: json['nome'] ?? '',
      quantidadeG: (json['quantidadeG'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'alimentoId': alimentoId, 'nome': nome, 'quantidadeG': quantidadeG};
  }

  // Zero quando o alimento nao esta mais no catalogo.
  Nutrientes nutrientes(CatalogoAlimentos catalogo) {
    return catalogo.porId(alimentoId)?.paraGramas(quantidadeG) ??
        Nutrientes.zero;
  }
}
