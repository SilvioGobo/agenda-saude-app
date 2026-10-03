import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import 'sincronizacao_bpm_viewmodel.dart';

// Como cada estado da sincronizacao aparece na tela: texto, icone, cor e a
// acao necessaria (conectar, instalar, tentar de novo). Usado pelo
// CardSmartwatch (tela "Meu smartwatch") e pelo painel do paciente, que
// mostra o problema no lugar dos batimentos quando `temProblema`.
//
// Problemas de conexao usam a cor de aviso (laranja); o vermelho fica
// reservado para alertas de saude.
class InfoSmartwatch {
  final String titulo;
  final String descricao;
  final IconData icone;
  final Color cor;
  final Widget? acao;

  // O smartwatch nao esta entregando leituras: o BPM na tela estaria
  // desatualizado, entao o painel mostra esta mensagem no lugar dele.
  final bool temProblema;

  const InfoSmartwatch({
    required this.titulo,
    required this.descricao,
    required this.icone,
    required this.cor,
    this.acao,
    this.temProblema = false,
  });

  factory InfoSmartwatch.de(
    BuildContext context,
    SincronizacaoBpmViewModel viewModel,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (viewModel.estado) {
      case EstadoSincronizacao.verificando:
        return InfoSmartwatch(
          titulo: 'Verificando smartwatch...',
          descricao: 'Aguarde um instante.',
          icone: Icons.watch_rounded,
          cor: colorScheme.onSurfaceVariant,
        );
      case EstadoSincronizacao.naoSuportado:
        return InfoSmartwatch(
          titulo: 'Smartwatch indisponível',
          descricao:
              'A leitura de batimentos só funciona em celulares Android com o '
              'Health Connect.',
          icone: Icons.watch_off_rounded,
          cor: colorScheme.onSurfaceVariant,
          temProblema: true,
        );
      case EstadoSincronizacao.healthConnectAusente:
        return InfoSmartwatch(
          titulo: 'Health Connect necessário',
          descricao: 'Instale ou atualize o Health Connect para o app receber '
              'os batimentos do seu relógio.',
          icone: Icons.download_rounded,
          cor: AppCores.aviso,
          temProblema: true,
          acao: FilledButton.icon(
            onPressed: viewModel.instalarHealthConnect,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Instalar Health Connect'),
          ),
        );
      case EstadoSincronizacao.semPermissao:
        return InfoSmartwatch(
          titulo: 'Conecte seu smartwatch',
          descricao: viewModel.mensagemErro ??
              'Permita que o app leia seus batimentos cardíacos.',
          icone: Icons.watch_off_rounded,
          cor: AppCores.aviso,
          temProblema: true,
          acao: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: viewModel.conectar,
                icon: const Icon(Icons.link_rounded),
                label: const Text('Conectar smartwatch'),
              ),
              // So depois de uma tentativa negada: o Android deixa de mostrar
              // o pop-up e o usuario precisa liberar nas configuracoes.
              if (viewModel.mensagemErro != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: viewModel.abrirConfiguracoesHealthConnect,
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Abrir configurações do Health Connect'),
                ),
              ],
            ],
          ),
        );
      case EstadoSincronizacao.ativa:
        if (viewModel.mensagemErro != null) {
          return InfoSmartwatch(
            titulo: 'Falha ao sincronizar',
            descricao: 'Não foi possível ler os batimentos agora. Confira se '
                'o smartwatch está no pulso e perto do celular.',
            icone: Icons.sync_problem_rounded,
            cor: AppCores.aviso,
            temProblema: true,
            acao: _botaoSincronizar(viewModel, 'Tentar novamente'),
          );
        }
        final ultima = viewModel.ultimaSincronizacao;
        return InfoSmartwatch(
          titulo: 'Smartwatch conectado',
          descricao: ultima == null
              ? 'Sincronizando...'
              : 'Última sincronização às ${_horaCurta(ultima)}.',
          icone: Icons.watch_rounded,
          cor: colorScheme.primary,
          acao: _botaoSincronizar(viewModel, 'Sincronizar agora'),
        );
      case EstadoSincronizacao.erro:
        return InfoSmartwatch(
          titulo: 'Problema com o smartwatch',
          descricao: viewModel.mensagemErro ?? 'Tente novamente.',
          icone: Icons.error_outline_rounded,
          cor: AppCores.aviso,
          temProblema: true,
          acao: FilledButton.icon(
            onPressed: viewModel.iniciar,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        );
    }
  }

  static Widget _botaoSincronizar(
    SincronizacaoBpmViewModel viewModel,
    String rotulo,
  ) {
    return OutlinedButton.icon(
      onPressed: viewModel.sincronizando ? null : viewModel.sincronizarAgora,
      icon: viewModel.sincronizando
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync_rounded),
      label: Text(rotulo),
    );
  }

  static String _horaCurta(DateTime data) {
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');
    return '$hora:$minuto';
  }
}

// Card que mostra a situacao da conexao com o smartwatch e oferece a acao
// necessaria. Fica na tela "Meu smartwatch" (menu do paciente).
class CardSmartwatch extends StatelessWidget {
  const CardSmartwatch({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SincronizacaoBpmViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final info = InfoSmartwatch.de(context, viewModel);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(info.icone, color: info.cor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    info.titulo,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: info.cor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              info.descricao,
              style: TextStyle(
                fontSize: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (info.acao != null) ...[
              const SizedBox(height: 16),
              info.acao!,
            ],
          ],
        ),
      ),
    );
  }
}
