import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../../domain/alimentos/alimento.dart';
import '../../domain/metas/metas_personalizadas.dart';
import '../../domain/refeicoes/refeicoes_padrao.dart';
import '../shared/barra_acoes.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/titulo_tela.dart';
import 'buscar_alimento_view.dart';
import 'formato_nutrientes.dart';
import 'personalizar_refeicoes_viewmodel.dart';
import 'refeicoes_viewmodel.dart';
import 'resumo_nutricional.dart';

// "Minhas refeicoes": onde o paciente escolhe o nome de cada refeicao e os
// alimentos (com a quantidade em gramas) que costuma comer nela. Na rotina ele
// so marca "feito" - nao precisa descrever o que comeu a cada dia (RF03.4). Os
// nutrientes de cada refeicao e do dia aparecem aqui, na hora, frente as metas.
// Salvar e Cancelar ficam fixos na base.
class PersonalizarRefeicoesView extends StatelessWidget {
  // Para comparar o plano com o que o paciente deve comer por dia.
  final MetasPersonalizadas? metas;

  const PersonalizarRefeicoesView({super.key, this.metas});

  // Abre a tela editando o plano que a rotina esta mostrando.
  static Widget comProviders(RefeicoesViewModel rotina) {
    return ChangeNotifierProvider(
      create: (_) => PersonalizarRefeicoesViewModel(
        atual: rotina.refeicoes,
        padrao: RefeicoesPadrao.para(
          possuiDiabetes: rotina.paciente.possuiDiabetes,
        ),
        aoSalvar: rotina.salvarPlano,
        catalogo: rotina.catalogo,
      ),
      child: PersonalizarRefeicoesView(metas: rotina.metas),
    );
  }

  Future<void> _salvar(BuildContext context) async {
    final salvou = await context
        .read<PersonalizarRefeicoesViewModel>()
        .salvar();
    if (!context.mounted || !salvou) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PersonalizarRefeicoesViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final temAlimentos = viewModel.refeicoes.any(
      (refeicao) => refeicao.itens.isNotEmpty,
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: BotaoBarraSuperior.largura,
        leading: BotaoBarraSuperior.voltar(
          aoTocar: () => Navigator.of(context).pop(),
        ),
      ),
      bottomNavigationBar: BarraAcoes(
        children: [
          if (viewModel.mensagemErro != null)
            Semantics(
              liveRegion: true,
              child: Text(
                viewModel.mensagemErro!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppCores.perigo,
                ),
              ),
            ),
          FilledButton.icon(
            onPressed: viewModel.salvando ? null : () => _salvar(context),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Salvar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            const TituloTela(
              'Minhas refeições',
              subtitulo:
                  'Escolha o nome de cada refeição e os alimentos que você '
                  'come nela. Na rotina, você só marca quando fizer.',
            ),
            const SizedBox(height: 24),
            if (!viewModel.podeEscolherAlimentos) ...[
              Text(
                'A lista de alimentos não está disponível agora. Você ainda '
                'pode mudar os nomes das refeições.',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.35,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (temAlimentos) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ResumoNutricional(
                    titulo: 'Seu dia com estas refeições',
                    nutrientes: viewModel.nutrientesDoDia,
                    metas: metas,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            for (final refeicao in viewModel.refeicoes) ...[
              _EditorRefeicao(
                // A versao muda ao voltar ao padrao, recriando os campos.
                key: ValueKey('${viewModel.versao}-${refeicao.id}'),
                refeicao: refeicao,
              ),
              const SizedBox(height: 16),
            ],
            OutlinedButton.icon(
              onPressed: viewModel.podeAdicionar ? viewModel.adicionar : null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar refeição'),
            ),
            if (!viewModel.podeAdicionar) ...[
              const SizedBox(height: 8),
              Text(
                'Você já tem o máximo de '
                '${RefeicoesViewModel.maximoRefeicoes} refeições.',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: viewModel.restaurarPadrao,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Voltar ao padrão'),
            ),
          ],
        ),
      ),
    );
  }
}

// Uma refeicao: nome, alimentos com quantidade, "Adicionar alimento" e o total
// dela. Os campos guardam o proprio texto (`initialValue`); o ViewModel recebe
// cada mudanca.
class _EditorRefeicao extends StatelessWidget {
  final RefeicaoEmEdicao refeicao;

  const _EditorRefeicao({super.key, required this.refeicao});

  Future<void> _escolherAlimento(
    BuildContext context,
    PersonalizarRefeicoesViewModel viewModel,
  ) async {
    final catalogo = viewModel.catalogo;
    if (catalogo == null) return;
    final alimento = await Navigator.of(context).push<Alimento>(
      MaterialPageRoute(
        builder: (_) => BuscarAlimentoView.comProviders(catalogo),
      ),
    );
    if (alimento != null && context.mounted) {
      viewModel.adicionarAlimento(refeicao, alimento);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<PersonalizarRefeicoesViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final total = viewModel.nutrientesDa(refeicao);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              initialValue: refeicao.nome,
              maxLength: PersonalizarRefeicoesViewModel.tamanhoMaximoNome,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 18),
              decoration: const InputDecoration(
                labelText: 'Nome da refeição',
                counterText: '',
              ),
              onChanged: (valor) => viewModel.definirNome(refeicao, valor),
            ),
            const SizedBox(height: 16),
            for (final item in refeicao.itens) ...[
              // A chave evita que, ao tirar um alimento do meio, o campo de
              // quantidade do vizinho herde o texto do que saiu.
              _EditorAlimento(
                key: ValueKey('alimento-${item.chave}'),
                refeicao: refeicao,
                item: item,
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed:
                  viewModel.podeEscolherAlimentos &&
                      viewModel.podeAdicionarAlimento(refeicao)
                  ? () => _escolherAlimento(context, viewModel)
                  : null,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Adicionar alimento'),
            ),
            if (refeicao.itens.isNotEmpty) ...[
              const SizedBox(height: 12),
              Semantics(
                container: true,
                child: Text(
                  'Total da refeição: ${descreverNutrientes(total)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => viewModel.remover(refeicao.id),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  foregroundColor: colorScheme.error,
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remover refeição'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Um alimento da refeicao: nome, quantidade em gramas e o que ele fornece.
class _EditorAlimento extends StatelessWidget {
  final RefeicaoEmEdicao refeicao;
  final ItemEmEdicao item;

  const _EditorAlimento({
    super.key,
    required this.refeicao,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<PersonalizarRefeicoesViewModel>();
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            item.nome,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: formatarQuantidade(item.quantidadeG),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: 'Quantidade (g)',
                  ),
                  onChanged: (texto) =>
                      viewModel.definirQuantidade(item, texto),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => viewModel.removerAlimento(refeicao, item),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 56),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  foregroundColor: colorScheme.error,
                ),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Tirar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            descreverNutrientes(viewModel.nutrientesDoItem(item)),
            style: TextStyle(
              fontSize: 16,
              height: 1.35,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
