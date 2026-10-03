import 'package:flutter/material.dart';

import '../../domain/models/alerta.dart';
import 'card_alerta.dart';

// Faixa no topo do painel do acompanhante enquanto houver alertas nao lidos:
// destaca o mais recente no mesmo padrao do selo "ATENÇÃO" do paciente e
// leva para a tela de Notificacoes.
class AvisoAlertasNaoLidos extends StatelessWidget {
  final Alerta alerta;
  final String nomePaciente;
  final int totalNaoLidos;
  final VoidCallback onVerNotificacoes;

  const AvisoAlertasNaoLidos({
    super.key,
    required this.alerta,
    required this.nomePaciente,
    required this.totalNaoLidos,
    required this.onVerNotificacoes,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final estilo = estiloDoAlerta(alerta);
    final outros = totalNaoLidos - 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: estilo.cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: estilo.cor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(estilo.icone, color: estilo.cor, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  alerta.ehEmergencia
                      ? 'Emergência com $nomePaciente'
                      : '$nomePaciente precisa de atenção',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: estilo.cor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(alerta.mensagem, style: const TextStyle(fontSize: 17)),
          const SizedBox(height: 4),
          Text(
            outros > 0
                ? '${descreverHorario(alerta.dataHora)} · mais $outros '
                    '${outros == 1 ? 'não lida' : 'não lidas'}'
                : descreverHorario(alerta.dataHora),
            style: TextStyle(
              fontSize: 15,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onVerNotificacoes,
            style: ElevatedButton.styleFrom(
              backgroundColor: estilo.cor,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.notifications_active_rounded),
            label: const Text('Ver notificações'),
          ),
        ],
      ),
    );
  }
}
