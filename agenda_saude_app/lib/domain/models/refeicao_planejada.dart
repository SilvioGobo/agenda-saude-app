import '../alimentos/catalogo_alimentos.dart';
import '../alimentos/nutrientes.dart';
import 'item_refeicao.dart';

// Uma refeicao do plano do paciente (RF03.4): o nome ("Almoco") e os
// alimentos, com a quantidade de cada um, que ele costuma comer nela. Fica
// numa lista dentro de `usuarios/{uid}.refeicoes`, e o `id` liga a refeicao
// aos `RegistroRefeicao` do dia, entao precisa continuar o mesmo quando o
// paciente muda o nome.
class RefeicaoPlanejada {
  final String id;
  final String nome;
  final List<ItemRefeicao> itens;

  const RefeicaoPlanejada({
    required this.id,
    required this.nome,
    this.itens = const [],
  });

  factory RefeicaoPlanejada.fromJson(Map<String, dynamic> json) {
    return RefeicaoPlanejada(
      id: json['id'] ?? '',
      nome: json['nome'] ?? '',
      itens: json['itens'] is List
          ? (json['itens'] as List)
                .map(
                  (item) => ItemRefeicao.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'itens': itens.map((item) => item.toJson()).toList(),
    };
  }

  // Energia e nutrientes de todos os alimentos da refeicao.
  Nutrientes nutrientes(CatalogoAlimentos catalogo) {
    return Nutrientes.somar(itens.map((item) => item.nutrientes(catalogo)));
  }
}
