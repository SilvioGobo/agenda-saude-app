import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'sincronizacao_bpm_viewmodel.dart';

// Card do painel do paciente que mostra a situacao da conexao com o
// smartwatch e oferece a acao necessaria (conectar, instalar, tentar de novo).
class CardSmartwatch extends StatelessWidget {
  const CardSmartwatch({super.key});

  String _horaCurta(DateTime data) {
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');
    return '$hora:$minuto';
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SincronizacaoBpmViewModel>();
    final colorScheme = Theme.of(context).colorScheme;

    final String titulo;
    final String descricao;
    final IconData icone;
    Color cor = colorScheme.primary;
    Widget? acao;

    switch (viewModel.estado) {
      case EstadoSincronizacao.verificando:
        titulo = 'Verificando smartwatch...';
        descricao = 'Aguarde um instante.';
        icone = Icons.watch_rounded;
        cor = colorScheme.outline;
      case EstadoSincronizacao.naoSuportado:
        titulo = 'Smartwatch indisponível';
        descricao =
            'A leitura de batimentos só funciona em celulares Android com o '
            'Health Connect.';
        icone = Icons.watch_off_rounded;
        cor = colorScheme.outline;
      case EstadoSincronizacao.healthConnectAusente:
        titulo = 'Health Connect necessário';
        descricao = 'Instale ou atualize o Health Connect para o app receber '
            'os batimentos do seu relógio.';
        icone = Icons.download_rounded;
        cor = Colors.orange.shade800;
        acao = ElevatedButton.icon(
          onPressed: viewModel.instalarHealthConnect,
          icon: const Icon(Icons.download_rounded),
          label: const Text('Instalar Health Connect'),
        );
      case EstadoSincronizacao.semPermissao:
        titulo = 'Conecte seu smartwatch';
        descricao = viewModel.mensagemErro ??
            'Permita que o app leia seus batimentos cardíacos.';
        icone = Icons.watch_rounded;
        cor = Colors.orange.shade800;
        acao = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: viewModel.conectar,
              icon: const Icon(Icons.link_rounded),
              label: const Text('Conectar smartwatch'),
            ),
            // So depois de uma tentativa negada: o Android deixa de mostrar o
            // pop-up e o usuario precisa liberar nas configuracoes.
            if (viewModel.mensagemErro != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: viewModel.abrirConfiguracoesHealthConnect,
                icon: const Icon(Icons.settings_rounded),
                label: const Text('Abrir configurações do Health Connect'),
              ),
            ],
          ],
        );
      case EstadoSincronizacao.ativa:
        titulo = 'Smartwatch conectado';
        final ultima = viewModel.ultimaSincronizacao;
        if (viewModel.mensagemErro != null) {
          descricao = viewModel.mensagemErro!;
          cor = Colors.orange.shade800;
        } else if (ultima == null) {
          descricao = 'Sincronizando...';
        } else {
          descricao = 'Última sincronização às ${_horaCurta(ultima)}.';
        }
        icone = Icons.watch_rounded;
        acao = OutlinedButton.icon(
          onPressed:
              viewModel.sincronizando ? null : viewModel.sincronizarAgora,
          icon: viewModel.sincronizando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync_rounded),
          label: const Text('Sincronizar agora'),
        );
      case EstadoSincronizacao.erro:
        titulo = 'Problema com o smartwatch';
        descricao = viewModel.mensagemErro ?? 'Tente novamente.';
        icone = Icons.error_outline_rounded;
        cor = Colors.red;
        acao = ElevatedButton.icon(
          onPressed: viewModel.iniciar,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tentar novamente'),
        );
    }

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
              descricao,
              style: TextStyle(
                fontSize: 17,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (acao != null) ...[
              const SizedBox(height: 16),
              acao,
            ],
          ],
        ),
      ),
    );
  }
}
