import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/botao_grande.dart';
import '../shared/dialogo_confirmacao.dart';
import '../shared/titulo_tela.dart';
import 'card_situacao_localizacao.dart';
import 'compartilhamento_localizacao_viewmodel.dart';

// Tela "Minha localização", aberta pelo menu do paciente: liga e desliga o
// compartilhamento da localizacao com o acompanhante e mostra o que falta
// (permissao, GPS) quando algo impede o envio. Reaproveita o ViewModel do
// painel, que continua enviando enquanto esta tela esta aberta.
class MinhaLocalizacaoView extends StatelessWidget {
  const MinhaLocalizacaoView({super.key});

  static Widget comViewModel(CompartilhamentoLocalizacaoViewModel viewModel) {
    return ChangeNotifierProvider.value(
      value: viewModel,
      child: const MinhaLocalizacaoView(),
    );
  }

  Future<void> _confirmarParada(BuildContext context) async {
    final confirmou = await mostrarDialogoConfirmacao(
      context,
      titulo: 'Parar de compartilhar?',
      mensagem: 'Seu acompanhante não vai mais ver onde você está. Você pode '
          'ligar de novo quando quiser.',
      rotuloConfirmar: 'Parar de compartilhar',
      iconeConfirmar: Icons.location_off_rounded,
    );
    if (!context.mounted || !confirmou) return;
    final desligou =
        await context.read<CompartilhamentoLocalizacaoViewModel>().desativar();
    if (!context.mounted || desligou) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível parar de compartilhar. Confira a internet e '
          'tente de novo.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  static String _horaCurta(DateTime data) {
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');
    return '$hora:$minuto';
  }

  // Como cada estado do compartilhamento aparece: problemas usam a cor de
  // aviso (laranja) e trazem a acao que resolve; o vermelho fica reservado
  // para alertas de saude.
  Widget _situacao(
    BuildContext context,
    CompartilhamentoLocalizacaoViewModel viewModel,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (viewModel.estado) {
      case EstadoCompartilhamento.verificando:
        return CardSituacaoLocalizacao(
          icone: Icons.location_searching_rounded,
          titulo: 'Verificando...',
          descricao: 'Aguarde um instante.',
          cor: colorScheme.onSurfaceVariant,
        );
      case EstadoCompartilhamento.naoSuportado:
        return CardSituacaoLocalizacao(
          icone: Icons.location_disabled_rounded,
          titulo: 'Indisponível neste aparelho',
          descricao: 'O compartilhamento da localização funciona em celulares '
              'Android e iPhone.',
          cor: colorScheme.onSurfaceVariant,
        );
      case EstadoCompartilhamento.desligado:
        return CardSituacaoLocalizacao(
          icone: Icons.location_off_rounded,
          titulo: 'Localização não compartilhada',
          descricao: 'Ao ligar, seu acompanhante consegue ver no mapa onde '
              'você está. Isso ajuda caso você precise de socorro fora de '
              'casa.',
          cor: colorScheme.onSurfaceVariant,
        );
      case EstadoCompartilhamento.semPermissao:
        return CardSituacaoLocalizacao(
          icone: Icons.location_disabled_rounded,
          titulo: 'Permita o acesso à localização',
          descricao: viewModel.mensagemErro ??
              'O aplicativo precisa da sua permissão para saber onde você '
                  'está.',
          cor: AppCores.aviso,
          destacarBorda: true,
          acao: viewModel.permissaoBloqueada
              ? FilledButton.icon(
                  onPressed: viewModel.abrirConfiguracoesDoApp,
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Abrir configurações'),
                )
              : FilledButton.icon(
                  onPressed: viewModel.ocupado ? null : viewModel.ativar,
                  icon: const Icon(Icons.my_location_rounded),
                  label: const Text('Permitir localização'),
                ),
        );
      case EstadoCompartilhamento.gpsDesligado:
        return CardSituacaoLocalizacao(
          icone: Icons.location_off_rounded,
          titulo: 'Localização do celular desligada',
          descricao: 'Ligue a localização (GPS) do celular para seu '
              'acompanhante ver onde você está.',
          cor: AppCores.aviso,
          destacarBorda: true,
          acao: FilledButton.icon(
            onPressed: viewModel.abrirConfiguracoesDeLocalizacao,
            icon: const Icon(Icons.settings_rounded),
            label: const Text('Ligar localização'),
          ),
        );
      case EstadoCompartilhamento.ativo:
        if (viewModel.mensagemErro != null) {
          return CardSituacaoLocalizacao(
            icone: Icons.wrong_location_rounded,
            titulo: 'Problema com a localização',
            descricao: viewModel.mensagemErro!,
            cor: AppCores.aviso,
            destacarBorda: true,
            acao: OutlinedButton.icon(
              onPressed:
                  viewModel.atualizando ? null : viewModel.atualizarAgora,
              icon: viewModel.atualizando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          );
        }
        final ultima = viewModel.ultimaAtualizacao;
        return CardSituacaoLocalizacao(
          icone: Icons.location_on_rounded,
          titulo: 'Compartilhando sua localização',
          descricao: ultima == null
              ? 'Procurando sua localização...'
              : 'Seu acompanhante vê onde você está. Última atualização às '
                  '${_horaCurta(ultima)}.',
          cor: AppCores.sucesso,
        );
      case EstadoCompartilhamento.erro:
        return CardSituacaoLocalizacao(
          icone: Icons.error_outline_rounded,
          titulo: 'Problema com a localização',
          descricao: viewModel.mensagemErro ?? 'Tente novamente.',
          cor: AppCores.aviso,
          destacarBorda: true,
          acao: FilledButton.icon(
            onPressed: viewModel.ocupado ? null : viewModel.iniciar,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CompartilhamentoLocalizacaoViewModel>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
              'Minha localização',
              subtitulo: 'Seu acompanhante pode ver onde você está enquanto '
                  'este aplicativo estiver aberto no seu celular.',
            ),
            const SizedBox(height: 24),
            // O leitor de tela anuncia quando a situacao muda (ex.: depois
            // de responder ao pedido de permissao).
            Semantics(liveRegion: true, child: _situacao(context, viewModel)),
            if (viewModel.estado == EstadoCompartilhamento.desligado) ...[
              const SizedBox(height: 24),
              BotaoGrande(
                rotulo: 'Compartilhar minha localização',
                icone: Icons.share_location_rounded,
                aoTocar: viewModel.ocupado ? null : viewModel.ativar,
              ),
            ],
            if (viewModel.compartilhamentoLigado) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: viewModel.ocupado
                    ? null
                    : () => _confirmarParada(context),
                icon: const Icon(Icons.location_off_rounded),
                label: const Text('Parar de compartilhar'),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_rounded, size: 28, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Só quem acompanha você pelo aplicativo vê sua '
                    'localização. O aplicativo guarda apenas o último lugar, '
                    'não o caminho que você fez.',
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.35,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
