import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import 'sincronizacao_bpm_viewmodel.dart';

// Cartao "COM O APP FECHADO" da tela "Meu smartwatch" (B7, RF04.2). Onde o
// Health Connect deixa, o app continua lendo os batimentos a cada 15 minutos
// com o app fechado, e o acompanhante continua sendo avisado. A permissao do
// Health Connect e o liga/desliga. So aparece com o smartwatch conectado: sem
// ele nao ha o que ler.
class CardLeituraAppFechado extends StatelessWidget {
  const CardLeituraAppFechado({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SincronizacaoBpmViewModel>();
    final disponivel = viewModel.leituraAppFechadoDisponivel;
    if (viewModel.estado != EstadoSincronizacao.ativa || disponivel == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final ligada = viewModel.leituraAppFechadoLigada;
    final mensagem = viewModel.mensagemLeituraAppFechado;

    final ({String estado, String explicacao, Color cor, IconData icone})
        situacao = !disponivel
            ? (
                estado: 'NÃO FUNCIONA NESTE CELULAR',
                explicacao: 'O Saúde Connect deste celular só deixa ler os '
                    'batimentos com o app aberto. Se aparecer uma atualização '
                    'do Saúde Connect na Play Store, instale e volte aqui.',
                cor: colorScheme.onSurfaceVariant,
                icone: Icons.phonelink_off_rounded,
              )
            : ligada
                ? (
                    estado: 'LIGADA',
                    explicacao: 'O app lê seus batimentos a cada 15 minutos, '
                        'mesmo fechado, e avisa seu acompanhante se eles '
                        'saírem da zona de segurança. Com o app aberto, a '
                        'leitura é a cada 30 segundos.',
                    cor: AppCores.sucesso,
                    icone: Icons.check_circle_rounded,
                  )
                : (
                    estado: 'DESLIGADA',
                    explicacao: 'Com o app fechado, seus batimentos não chegam '
                        'ao seu acompanhante. Permita a leitura para o app ler '
                        'a cada 15 minutos, mesmo fechado.',
                    cor: AppCores.aviso,
                    icone: Icons.error_outline_rounded,
                  );

    return Card(
      // Espaco para o cartao de cima, que so existe junto com este.
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'COM O APP FECHADO',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(situacao.icone, color: situacao.cor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    situacao.estado,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: situacao.cor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              situacao.explicacao,
              style: TextStyle(
                fontSize: 18,
                height: 1.35,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (disponivel && !ligada) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: viewModel.permitirLeituraComAppFechado,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('PERMITIR LEITURA COM O APP FECHADO'),
              ),
            ],
            if (mensagem != null) ...[
              const SizedBox(height: 12),
              Text(
                mensagem,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppCores.aviso,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
