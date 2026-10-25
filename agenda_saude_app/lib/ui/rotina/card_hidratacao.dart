import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/meta_hidratacao.dart';
import '../../core/theme/app_cores.dart';
import '../shared/card_status.dart';
import 'hidratacao_viewmodel.dart';

// Cartao "Hidratacao" do checklist de rotina (Figura 14 do TCC): copos bebidos
// hoje, barra de progresso ate a meta e os botoes "- Copo" / "+ Copo". Os
// numeros aparecem em texto grande (copos e ml) e a barra nunca e a unica
// fonte da informacao. Com a fonte do celular muito aumentada os dois botoes
// passam de lado a lado para um embaixo do outro (NF004).
class CardHidratacao extends StatelessWidget {
  const CardHidratacao({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HidratacaoViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final pronto = !viewModel.carregando && !viewModel.erroDeLeitura;
    final fonteMuitoGrande = MediaQuery.textScalerOf(context).scale(18) > 27;

    final botaoRemover = _BotaoCopo(
      rotulo: 'Copo',
      rotuloParaLeitor: 'Tirar um copo de água',
      icone: Icons.remove_rounded,
      destacado: false,
      aoTocar: pronto && viewModel.podeRemover ? viewModel.removerCopo : null,
    );
    final botaoAdicionar = _BotaoCopo(
      rotulo: 'Copo',
      rotuloParaLeitor: 'Adicionar um copo de água',
      icone: Icons.add_rounded,
      destacado: true,
      aoTocar: pronto ? viewModel.adicionarCopo : null,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Resumo(viewModel: viewModel),
            const SizedBox(height: 20),
            if (viewModel.erroDeLeitura)
              Semantics(
                liveRegion: true,
                child: const Text(
                  'Não foi possível carregar a sua hidratação de hoje. Volte '
                  'e abra esta tela de novo.',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: AppCores.perigo,
                  ),
                ),
              )
            else ...[
              if (fonteMuitoGrande) ...[
                botaoAdicionar,
                const SizedBox(height: 12),
                botaoRemover,
              ] else
                Row(
                  children: [
                    Expanded(child: botaoRemover),
                    const SizedBox(width: 12),
                    Expanded(child: botaoAdicionar),
                  ],
                ),
              if (viewModel.metaAtingida) ...[
                const SizedBox(height: 16),
                const CardStatus(
                  rotulo: 'META DE HOJE ATINGIDA',
                  icone: Icons.check_circle_rounded,
                  cor: AppCores.sucesso,
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
          ],
        ),
      ),
    );
  }
}

// Titulo, copos bebidos e barra de progresso. O leitor de tela le tudo numa
// frase so ("Hidratação: 5 de 8 copos, 1250 de 2000 mililitros") em vez de
// pedacos soltos.
class _Resumo extends StatelessWidget {
  final HidratacaoViewModel viewModel;

  const _Resumo({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mostrarProgresso = !viewModel.carregando && !viewModel.erroDeLeitura;
    final copos = '${viewModel.copos} de ${viewModel.metaCopos} copos';
    final mililitros =
        '${viewModel.totalMl} ml de ${MetaHidratacao.mlDiaria} ml';

    return Semantics(
      container: true,
      label: mostrarProgresso
          ? 'Hidratação: $copos, ${viewModel.totalMl} de '
              '${MetaHidratacao.mlDiaria} mililitros.'
          : 'Hidratação',
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
                    Icons.water_drop_rounded,
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
                        'Hidratação',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (mostrarProgresso)
                        Text(
                          copos,
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
            if (mostrarProgresso) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: viewModel.progresso,
                  minHeight: 16,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  color: viewModel.metaAtingida
                      ? AppCores.sucesso
                      : colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                mililitros,
                style: TextStyle(
                  fontSize: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// "- Copo" (contorno) e "+ Copo" (preenchido), 64dp de altura. O rotulo falado
// diz o que o botao faz, ja que "Copo" sozinho nao diferencia os dois.
class _BotaoCopo extends StatelessWidget {
  final String rotulo;
  final String rotuloParaLeitor;
  final IconData icone;
  final bool destacado;
  final VoidCallback? aoTocar;

  const _BotaoCopo({
    required this.rotulo,
    required this.rotuloParaLeitor,
    required this.icone,
    required this.destacado,
    required this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    const tamanho = Size.fromHeight(64);
    const texto = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);

    final Widget botao = destacado
        ? FilledButton.icon(
            onPressed: aoTocar,
            style: FilledButton.styleFrom(
              minimumSize: tamanho,
              textStyle: texto,
              iconSize: 28,
            ),
            icon: Icon(icone),
            label: Text(rotulo),
          )
        : OutlinedButton.icon(
            onPressed: aoTocar,
            style: OutlinedButton.styleFrom(
              minimumSize: tamanho,
              textStyle: texto,
              iconSize: 28,
            ),
            icon: Icon(icone),
            label: Text(rotulo),
          );

    return Semantics(
      button: true,
      enabled: aoTocar != null,
      label: rotuloParaLeitor,
      onTap: aoTocar,
      excludeSemantics: true,
      child: botao,
    );
  }
}
