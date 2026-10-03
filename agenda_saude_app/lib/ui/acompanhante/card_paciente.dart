import 'package:flutter/material.dart';

import '../../domain/models/paciente.dart';

// Cartao de um paciente vinculado no painel do acompanhante (Figura 15 do
// TCC). Mostra a identificacao, as comorbidades da triagem e quantos alertas
// do paciente ainda nao foram lidos (RF06); BPM, status consolidado e ultimo
// evento da rotina entram nas proximas etapas do modulo.
class CardPaciente extends StatelessWidget {
  final Paciente paciente;
  final int alertasNaoLidos;
  final VoidCallback? onDesvincular;

  const CardPaciente({
    super.key,
    required this.paciente,
    this.alertasNaoLidos = 0,
    this.onDesvincular,
  });

  String get _inicial {
    final nome = paciente.nome.trim();
    return nome.isEmpty ? '?' : nome[0].toUpperCase();
  }

  List<String> get _etiquetas {
    if (!paciente.triagemConcluida) return ['Triagem pendente'];
    final etiquetas = <String>[];
    if (paciente.possuiDiabetes) etiquetas.add('Diabetes');
    if (paciente.possuiCardiopatia) etiquetas.add('Cardiopatia');
    if (etiquetas.isEmpty) etiquetas.add('Sem comorbidades');
    return etiquetas;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                _inicial,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paciente.nome.trim().isEmpty ? 'Paciente' : paciente.nome,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _etiquetas
                        .map(
                          (etiqueta) => Chip(
                            label: Text(etiqueta),
                            labelStyle: const TextStyle(fontSize: 14),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                        .toList(),
                  ),
                  if (alertasNaoLidos > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.warning_rounded,
                          size: 20,
                          color: Colors.red.shade700,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            alertasNaoLidos == 1
                                ? '1 alerta não lido'
                                : '$alertasNaoLidos alertas não lidos',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (onDesvincular != null)
              PopupMenuButton<String>(
                tooltip: 'Mais opções',
                iconSize: 28,
                onSelected: (_) => onDesvincular!(),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'desvincular',
                    child: Row(
                      children: [
                        Icon(Icons.link_off_rounded),
                        SizedBox(width: 12),
                        Text('Desvincular', style: TextStyle(fontSize: 16)),
                      ],
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
