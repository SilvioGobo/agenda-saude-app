import 'package:flutter/material.dart';

// Indicador "Etapa X de N" usado nas telas do assistente de triagem,
// inspirado na barra de progresso do mockup do TCC (Figura 12 - Triagem).
class ProgressoEtapa extends StatelessWidget {
  final int etapaAtual;
  final int totalEtapas;

  const ProgressoEtapa({
    super.key,
    required this.etapaAtual,
    required this.totalEtapas,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: etapaAtual / totalEtapas,
            minHeight: 8,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Etapa $etapaAtual de $totalEtapas',
          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
