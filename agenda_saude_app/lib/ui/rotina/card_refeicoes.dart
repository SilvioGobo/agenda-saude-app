import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../../domain/models/refeicao_planejada.dart';
import '../shared/card_status.dart';
import 'formato_nutrientes.dart';
import 'personalizar_refeicoes_view.dart';
import 'refeicoes_viewmodel.dart';
import 'resumo_nutricional.dart';

// Cartao "Refeicoes" do checklist de rotina (RF03.4): uma linha grande por
// refeicao do plano, que o paciente toca para marcar como feita. Ele nao
// precisa descrever o que comeu - os alimentos que aparecem sao os que ele mesmo
// cadastrou em "Personalizar refeicoes", e deles saem as calorias e os
// nutrientes do dia. Cada linha diz "Feito" ou "Ainda nao feito" em texto,
// alem do icone (nunca so a cor ou o icone - NF004).
class CardRefeicoes extends StatelessWidget {
  const CardRefeicoes({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RefeicoesViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final pronto = !viewModel.carregando && !viewModel.erroDeLeitura;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Resumo(viewModel: viewModel, mostrarProgresso: pronto),
            const SizedBox(height: 16),
            if (viewModel.erroDeLeitura)
              Semantics(
                liveRegion: true,
                child: const Text(
                  'Não foi possível carregar suas refeições de hoje. Volte e '
                  'abra esta tela de novo.',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: AppCores.perigo,
                  ),
                ),
              )
            else if (viewModel.refeicoes.isEmpty)
              Text(
                'Você ainda não tem refeições. Toque em "Personalizar '
                'refeições" para adicionar.',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.35,
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              for (final refeicao in viewModel.refeicoes) ...[
                _LinhaRefeicao(
                  refeicao: refeicao,
                  feita: viewModel.estaFeita(refeicao),
                  kcal: refeicao.itens.isEmpty
                      ? null
                      : viewModel.nutrientesDa(refeicao).kcal,
                  aoTocar: pronto ? () => viewModel.alternar(refeicao) : null,
                ),
                const SizedBox(height: 8),
              ],
              if (viewModel.todasFeitas) ...[
                const SizedBox(height: 8),
                const CardStatus(
                  rotulo: 'REFEIÇÕES DE HOJE FEITAS',
                  icone: Icons.check_circle_rounded,
                  cor: AppCores.sucesso,
                ),
              ],
              if (pronto && viewModel.temAlimentos) ...[
                const SizedBox(height: 16),
                ResumoNutricional(
                  titulo: 'O que você já comeu hoje',
                  nutrientes: viewModel.nutrientesConsumidos,
                  metas: viewModel.metas,
                ),
              ] else if (pronto) ...[
                const SizedBox(height: 8),
                Text(
                  'Cadastre os alimentos de cada refeição em "Personalizar '
                  'refeições" para ver as calorias e os nutrientes do dia.',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.35,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
            if (viewModel.mensagemErro != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  viewModel.mensagemErro!,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PersonalizarRefeicoesView.comProviders(viewModel),
                ),
              ),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Personalizar refeições'),
            ),
          ],
        ),
      ),
    );
  }
}

// Titulo e "2 de 4 feitas" com a barra de progresso. O leitor de tela le tudo
// numa frase so.
class _Resumo extends StatelessWidget {
  final RefeicoesViewModel viewModel;
  final bool mostrarProgresso;

  const _Resumo({required this.viewModel, required this.mostrarProgresso});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mostrar = mostrarProgresso && viewModel.total > 0;
    final texto = '${viewModel.feitas} de ${viewModel.total} feitas';

    return Semantics(
      container: true,
      label: mostrar ? 'Refeições: $texto.' : 'Refeições',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.restaurant_rounded,
                    size: 32,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Refeições',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (mostrar)
                        Text(
                          texto,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (mostrar) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: viewModel.progresso,
                  minHeight: 16,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  color: viewModel.todasFeitas
                      ? AppCores.sucesso
                      : colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Uma refeicao: a linha inteira e o botao (72dp ou mais). Marcada fica com
// fundo e borda verdes, icone de check e o texto "Feito".
class _LinhaRefeicao extends StatelessWidget {
  // Alimentos mostrados em cada refeicao; o resto vira "e mais N alimentos".
  static const int maximoItensVisiveis = 4;

  final RefeicaoPlanejada refeicao;
  final bool feita;
  // Calorias da refeicao, quando ela tem alimentos cadastrados.
  final double? kcal;
  final VoidCallback? aoTocar;

  const _LinhaRefeicao({
    required this.refeicao,
    required this.feita,
    required this.kcal,
    required this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cor = feita ? AppCores.sucesso : colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      enabled: aoTocar != null,
      label:
          '${refeicao.nome}, ${feita ? 'feita' : 'ainda não feita'}. '
          '${feita ? 'Toque para desmarcar.' : 'Toque para marcar como feita.'}',
      excludeSemantics: true,
      onTap: aoTocar,
      child: Material(
        color: feita
            ? AppCores.sucessoContainer
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: feita ? AppCores.sucesso : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: aoTocar,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    feita
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 36,
                    color: cor,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          refeicao.nome,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: feita
                                ? AppCores.onSucessoContainer
                                : colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          feita ? 'Feito' : 'Ainda não feito',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: cor,
                          ),
                        ),
                        if (kcal != null)
                          Text(
                            formatarKcal(kcal!),
                            style: TextStyle(
                              fontSize: 16,
                              color: feita
                                  ? AppCores.onSucessoContainer
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        for (final item in refeicao.itens.take(
                          maximoItensVisiveis,
                        ))
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${item.nome} - ${formatarQuantidade(item.quantidadeG)} g',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.3,
                                color: feita
                                    ? AppCores.onSucessoContainer
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        if (refeicao.itens.length > maximoItensVisiveis)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'e mais ${refeicao.itens.length - maximoItensVisiveis} '
                              '${refeicao.itens.length - maximoItensVisiveis == 1 ? 'alimento' : 'alimentos'}',
                              style: TextStyle(
                                fontSize: 16,
                                color: feita
                                    ? AppCores.onSucessoContainer
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
