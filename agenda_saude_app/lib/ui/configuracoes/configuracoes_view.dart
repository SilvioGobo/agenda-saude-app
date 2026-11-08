import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../../domain/acessibilidade/configuracao_narrador.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/botao_selecionavel.dart';
import '../shared/erro_formulario.dart';
import '../shared/titulo_tela.dart';
import 'configuracoes_viewmodel.dart';

// Tela "Acessibilidade", aberta pelo menu do paciente (RF 07 e RF 08): liga e
// desliga o narrador de voz, escolhe a velocidade da fala (devagar, normal ou
// rapido, em botoes grandes) e tem o botao "Testar voz". A escolha vale para o
// aplicativo todo e fica guardada no aparelho.
class ConfiguracoesView extends StatelessWidget {
  const ConfiguracoesView({super.key});

  static Widget comViewModel(ConfiguracoesViewModel viewModel) {
    return ChangeNotifierProvider.value(
      value: viewModel,
      child: const ConfiguracoesView(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ConfiguracoesViewModel>();

    return Scaffold(
      appBar: AppBar(
        leadingWidth: BotaoBarraSuperior.largura,
        leading: BotaoBarraSuperior.voltar(
          aoTocar: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            const TituloTela(
              'Acessibilidade',
              subtitulo: 'Ajustes para ouvir o aplicativo em voz alta.',
            ),
            const SizedBox(height: 24),
            if (!viewModel.suportado)
              _CartaoAviso(
                icone: Icons.voice_over_off_rounded,
                titulo: 'Narrador indisponível',
                texto: 'Este aparelho não tem voz do sistema. O narrador '
                    'funciona em celulares Android.',
                cor: Theme.of(context).colorScheme.onSurfaceVariant,
              )
            else ...[
              _CartaoNarrador(viewModel: viewModel),
              if (viewModel.faltaVozEmPortugues) ...[
                const SizedBox(height: 16),
                const _CartaoAviso(
                  icone: Icons.language_rounded,
                  titulo: 'Voz em português não encontrada',
                  texto: 'Seu celular não tem a voz em português instalada. '
                      'O narrador vai falar com a voz que o celular tiver. '
                      'Para instalar, abra as configurações do Android, em '
                      '"Saída de texto para voz".',
                  cor: AppCores.aviso,
                ),
              ],
              const SizedBox(height: 16),
              _CartaoVelocidade(viewModel: viewModel),
              if (viewModel.mensagemErro != null) ...[
                const SizedBox(height: 16),
                ErroFormulario(viewModel.mensagemErro!),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// Diz se o narrador esta ligado e tem o botao para ligar ou desligar. O estado
// fica em texto e icone - nunca so na cor (NF004).
class _CartaoNarrador extends StatelessWidget {
  final ConfiguracoesViewModel viewModel;

  const _CartaoNarrador({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ligado = viewModel.narradorLigado;
    final cor = ligado ? AppCores.sucesso : colorScheme.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  ligado
                      ? Icons.record_voice_over_rounded
                      : Icons.voice_over_off_rounded,
                  color: cor,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ligado ? 'Narrador ligado' : 'Narrador desligado',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: cor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'O narrador lê os textos do aplicativo em voz alta, para quem '
              'tem dificuldade de enxergar. Ele fica ligado até você '
              'desligar.',
              style: TextStyle(
                fontSize: 18,
                height: 1.35,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (ligado)
              OutlinedButton.icon(
                onPressed: () => viewModel.alternarNarrador(false),
                icon: const Icon(Icons.voice_over_off_rounded),
                label: const Text('Desligar narrador'),
              )
            else
              FilledButton.icon(
                onPressed: () => viewModel.alternarNarrador(true),
                icon: const Icon(Icons.record_voice_over_rounded),
                label: const Text('Ligar narrador'),
              ),
          ],
        ),
      ),
    );
  }
}

// As tres velocidades em botoes grandes, um embaixo do outro, e o "Testar voz".
// Escolher uma velocidade ja fala um exemplo nela.
class _CartaoVelocidade extends StatelessWidget {
  final ConfiguracoesViewModel viewModel;

  const _CartaoVelocidade({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Velocidade da voz',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toque em uma velocidade para ouvir como fica.',
              style: TextStyle(
                fontSize: 18,
                height: 1.35,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final velocidade in VelocidadeNarracao.values) ...[
              Semantics(
                selected: viewModel.velocidade == velocidade,
                inMutuallyExclusiveGroup: true,
                child: BotaoSelecionavel(
                  rotulo: velocidade.rotulo,
                  selecionado: viewModel.velocidade == velocidade,
                  aoTocar: () => viewModel.escolherVelocidade(velocidade),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 4),
            FilledButton.icon(
              onPressed: viewModel.testarVoz,
              icon: const Icon(Icons.volume_up_rounded),
              label: const Text('Testar voz'),
            ),
          ],
        ),
      ),
    );
  }
}

// Aviso com a explicacao de um problema. Laranja quando pede uma acao; a cor
// vem de quem usa.
class _CartaoAviso extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String texto;
  final Color cor;

  const _CartaoAviso({
    required this.icone,
    required this.titulo,
    required this.texto,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icone, color: cor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: cor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              texto,
              style: TextStyle(
                fontSize: 18,
                height: 1.35,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
