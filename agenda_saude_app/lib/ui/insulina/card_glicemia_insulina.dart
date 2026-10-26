import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/faixas_glicemia.dart';
import '../../core/theme/app_cores.dart';
import 'formatacao_diabete.dart';
import 'glicemia_insulina_viewmodel.dart';
import 'glicemia_insulina_view.dart';

// Cartao resumido "GLICEMIA E INSULINA" da Minha Rotina (RF008), exibido so
// para quem marcou diabetes na triagem. A Rotina e um resumo do dia com um
// cartao compacto por atividade; o checklist completo fica na tela
// GlicemiaInsulinaView, aberta pelo botao grande. Aqui aparecem so quantas
// medicoes foram feitas hoje (em texto e em bolinhas) e, se a ultima glicemia
// estiver fora da faixa, uma linha de alerta - para o aviso nao ficar
// escondido dentro da outra tela.
class CardGlicemiaInsulina extends StatelessWidget {
  const CardGlicemiaInsulina({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<GlicemiaInsulinaViewModel>();
    final pronto = !viewModel.carregando && !viewModel.erroDeLeitura;
    final ultima = viewModel.ultimaGlicemia;
    final ultimaForaDaFaixa = pronto &&
        ultima != null &&
        FaixasGlicemia.classificar(ultima.nivelGlicose!) !=
            ClassificacaoGlicemia.naFaixa;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Cabecalho(viewModel: viewModel),
            if (viewModel.erroDeLeitura) ...[
              const SizedBox(height: 16),
              const TextoErroDiabete(
                'NÃO FOI POSSÍVEL CARREGAR SUA GLICEMIA DE HOJE.',
              ),
            ],
            if (ultimaForaDaFaixa) ...[
              const SizedBox(height: 16),
              _UltimaForaDaFaixa(mgDl: ultima.nivelGlicose!),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                GlicemiaInsulinaView.rota(viewModel),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                iconSize: 32,
              ),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text(
                'ANOTAR OU VER MEDIÇÕES',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Icone, titulo, "HOJE: 2 DE 4 MEDIÇÕES" e uma bolinha por medicao (cheia =
// feita). O leitor de tela le numa frase so.
class _Cabecalho extends StatelessWidget {
  final GlicemiaInsulinaViewModel viewModel;

  const _Cabecalho({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pronto = !viewModel.carregando && !viewModel.erroDeLeitura;
    final feitas = viewModel.medicoesFeitas;
    final total = viewModel.totalMedicoes;
    final completo = feitas == total;

    return Semantics(
      container: true,
      label: pronto
          ? 'Glicemia e Insulina: $feitas de $total medições feitas hoje.'
          : 'Glicemia e Insulina',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bloodtype_rounded,
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
                    'GLICEMIA E INSULINA',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (viewModel.carregando)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    )
                  else if (pronto) ...[
                    Text(
                      'HOJE: $feitas DE $total MEDIÇÕES',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: completo
                            ? AppCores.sucesso
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (var i = 0; i < total; i++)
                          Icon(
                            i < feitas
                                ? Icons.circle
                                : Icons.circle_outlined,
                            size: 22,
                            color: i < feitas
                                ? AppCores.sucesso
                                : colorScheme.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// "ÚLTIMA: 60 mg/dL" e o selo da faixa ("BAIXA", "ALTA"...), num fundo
// tingido na cor da faixa. So aparece quando a ultima glicemia do dia esta
// fora do alvo; os detalhes e a orientacao ficam na tela de glicemia.
class _UltimaForaDaFaixa extends StatelessWidget {
  final double mgDl;

  const _UltimaForaDaFaixa({required this.mgDl});

  @override
  Widget build(BuildContext context) {
    final classificacao = FaixasGlicemia.classificar(mgDl);
    final cor = corDaClassificacao(classificacao);

    return Semantics(
      container: true,
      liveRegion: true,
      label: semMarcasDeQuebra(
        'Atenção: última glicemia ${falarGlicemia(mgDl)}, '
        '${descreverClassificacao(classificacao).toLowerCase()}.',
      ),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cor, width: 2),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'ÚLTIMA: ${formatarGlicemia(mgDl)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SeloFaixaGlicemia(classificacao),
            ],
          ),
        ),
      ),
    );
  }
}
