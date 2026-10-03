import 'package:flutter/material.dart';

// Aviso do painel do acompanhante quando as notificacoes do app estao
// bloqueadas no aparelho: sem elas os alertas so aparecem com o app aberto.
class CardPermissaoNotificacoes extends StatelessWidget {
  final VoidCallback onAtivar;

  const CardPermissaoNotificacoes({super.key, required this.onAtivar});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cor = Colors.orange.shade800;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_off_rounded, color: cor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Notificações desativadas',
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
              'Ative para receber um aviso no celular assim que algum '
              'paciente precisar de atenção.',
              style: TextStyle(
                fontSize: 17,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAtivar,
              icon: const Icon(Icons.notifications_active_rounded),
              label: const Text('Ativar notificações'),
            ),
          ],
        ),
      ),
    );
  }
}
