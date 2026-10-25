import 'package:flutter/foundation.dart';

import '../../domain/alimentos/alimento.dart';
import '../../domain/alimentos/catalogo_alimentos.dart';
import '../../domain/alimentos/nutrientes.dart';
import '../../domain/models/item_refeicao.dart';
import '../../domain/models/refeicao_planejada.dart';
import 'refeicoes_viewmodel.dart';

// Alimento de uma refeicao enquanto o paciente edita. A quantidade muda a cada
// tecla, entao fica mutavel aqui e so vira ItemRefeicao ao salvar. A `chave`
// identifica o item na tela (o mesmo alimento pode aparecer duas vezes).
class ItemEmEdicao {
  final int chave;
  final int alimentoId;
  final String nome;
  double quantidadeG;

  ItemEmEdicao({
    required this.chave,
    required this.alimentoId,
    required this.nome,
    required this.quantidadeG,
  });
}

// Refeicao enquanto o paciente edita: o nome e os alimentos mudam a cada
// letra, e so viram RefeicaoPlanejada ao salvar.
class RefeicaoEmEdicao {
  final String id;
  String nome;
  final List<ItemEmEdicao> itens;

  RefeicaoEmEdicao({
    required this.id,
    required this.nome,
    List<ItemEmEdicao>? itens,
  }) : itens = itens ?? [];
}

// Estado da tela "Minhas refeicoes": o paciente escolhe quantas refeicoes tem,
// o nome de cada uma e os alimentos (com a quantidade em gramas) que costuma
// comer nela. Os nutrientes de cada refeicao e do dia aparecem na hora, a
// partir do catalogo. Nada e gravado ate "Salvar".
class PersonalizarRefeicoesViewModel extends ChangeNotifier {
  static const int tamanhoMaximoNome = 30;
  static const int maximoAlimentosPorRefeicao = 15;
  static const double quantidadePadraoG = 100;
  static const double quantidadeMinimaG = 1;
  static const double quantidadeMaximaG = 2000;

  final List<RefeicaoPlanejada> _padrao;
  final Future<bool> Function(List<RefeicaoPlanejada>) _aoSalvar;
  final String Function() _gerarId;
  final CatalogoAlimentos? catalogo;
  int _proximaChave = 0;

  PersonalizarRefeicoesViewModel({
    required List<RefeicaoPlanejada> atual,
    required List<RefeicaoPlanejada> padrao,
    required Future<bool> Function(List<RefeicaoPlanejada>) aoSalvar,
    this.catalogo,
    String Function()? gerarId,
  }) : _padrao = padrao,
       _aoSalvar = aoSalvar,
       _gerarId = gerarId ?? _idPelaHora {
    refeicoes = _copiar(atual);
  }

  static String _idPelaHora() => 'r${DateTime.now().microsecondsSinceEpoch}';

  List<RefeicaoEmEdicao> _copiar(List<RefeicaoPlanejada> origem) {
    return origem
        .map(
          (refeicao) => RefeicaoEmEdicao(
            id: refeicao.id,
            nome: refeicao.nome,
            itens: refeicao.itens
                .map(
                  (item) => ItemEmEdicao(
                    chave: _proximaChave++,
                    alimentoId: item.alimentoId,
                    nome: item.nome,
                    quantidadeG: item.quantidadeG,
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  late List<RefeicaoEmEdicao> refeicoes;

  // Muda ao voltar ao padrao: a tela usa o numero para recriar os campos de
  // texto, que senao manteriam o que estava digitado.
  int versao = 0;

  bool salvando = false;
  String? mensagemErro;

  // Sem catalogo (ainda carregando ou falhou) nao da para escolher alimentos.
  bool get podeEscolherAlimentos => catalogo != null;

  bool get podeAdicionar =>
      refeicoes.length < RefeicoesViewModel.maximoRefeicoes;

  bool podeAdicionarAlimento(RefeicaoEmEdicao refeicao) =>
      refeicao.itens.length < maximoAlimentosPorRefeicao;

  void adicionar() {
    if (!podeAdicionar) return;
    refeicoes.add(RefeicaoEmEdicao(id: _gerarId(), nome: ''));
    mensagemErro = null;
    notifyListeners();
  }

  void remover(String id) {
    refeicoes.removeWhere((refeicao) => refeicao.id == id);
    mensagemErro = null;
    notifyListeners();
  }

  void restaurarPadrao() {
    refeicoes = _copiar(_padrao);
    versao++;
    mensagemErro = null;
    notifyListeners();
  }

  void definirNome(RefeicaoEmEdicao refeicao, String valor) {
    refeicao.nome = valor;
    if (mensagemErro != null) {
      mensagemErro = null;
      notifyListeners();
    }
  }

  void adicionarAlimento(RefeicaoEmEdicao refeicao, Alimento alimento) {
    if (!podeAdicionarAlimento(refeicao)) return;
    refeicao.itens.add(
      ItemEmEdicao(
        chave: _proximaChave++,
        alimentoId: alimento.id,
        nome: alimento.nome,
        quantidadeG: quantidadePadraoG,
      ),
    );
    mensagemErro = null;
    notifyListeners();
  }

  void removerAlimento(RefeicaoEmEdicao refeicao, ItemEmEdicao item) {
    refeicao.itens.remove(item);
    mensagemErro = null;
    notifyListeners();
  }

  // Aceita virgula ou ponto. Texto invalido vira 0, que a validacao recusa ao
  // salvar - enquanto isso os totais mostram 0 para esse alimento.
  void definirQuantidade(ItemEmEdicao item, String texto) {
    item.quantidadeG = double.tryParse(texto.trim().replaceAll(',', '.')) ?? 0;
    mensagemErro = null;
    notifyListeners();
  }

  Nutrientes nutrientesDoItem(ItemEmEdicao item) {
    return catalogo?.porId(item.alimentoId)?.paraGramas(item.quantidadeG) ??
        Nutrientes.zero;
  }

  Nutrientes nutrientesDa(RefeicaoEmEdicao refeicao) {
    return Nutrientes.somar(refeicao.itens.map(nutrientesDoItem));
  }

  // O dia inteiro: a soma de todas as refeicoes do plano em edicao.
  Nutrientes get nutrientesDoDia =>
      Nutrientes.somar(refeicoes.map(nutrientesDa));

  Future<bool> salvar() async {
    if (refeicoes.isEmpty) {
      mensagemErro = 'Deixe pelo menos uma refeição.';
      notifyListeners();
      return false;
    }
    if (refeicoes.any((refeicao) => refeicao.nome.trim().isEmpty)) {
      mensagemErro = 'Dê um nome para todas as refeições.';
      notifyListeners();
      return false;
    }
    final quantidadeInvalida = refeicoes.any(
      (refeicao) => refeicao.itens.any(
        (item) =>
            item.quantidadeG < quantidadeMinimaG ||
            item.quantidadeG > quantidadeMaximaG,
      ),
    );
    if (quantidadeInvalida) {
      mensagemErro =
          'Informe a quantidade de cada alimento em gramas, de 1 a 2000.';
      notifyListeners();
      return false;
    }

    salvando = true;
    mensagemErro = null;
    notifyListeners();

    final salvou = await _aoSalvar(
      refeicoes
          .map(
            (refeicao) => RefeicaoPlanejada(
              id: refeicao.id,
              nome: refeicao.nome.trim(),
              itens: refeicao.itens
                  .map(
                    (item) => ItemRefeicao(
                      alimentoId: item.alimentoId,
                      nome: item.nome,
                      quantidadeG: item.quantidadeG,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );

    salvando = false;
    if (!salvou) {
      mensagemErro = 'Não foi possível salvar. Tente de novo.';
    }
    notifyListeners();
    return salvou;
  }
}
