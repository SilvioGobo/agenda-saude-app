import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'alertas_viewmodel.dart';

// Sino da barra superior do painel do acompanhante, com a contagem de
// alertas nao lidos que se atualiza em tempo real (RF06).
class BotaoNotificacoes extends StatelessWidget {
  final VoidCallback onPressed;

  const BotaoNotificacoes({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final naoLidos = context.watch<AlertasViewModel>().totalNaoLidos;

    return IconButton(
      tooltip: 'Notificações',
      iconSize: 30,
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: naoLidos > 0,
        backgroundColor: Colors.red.shade700,
        label: Text(
          naoLidos > 99 ? '99+' : '$naoLidos',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        child: Icon(
          naoLidos > 0
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
        ),
      ),
    );
  }
}
