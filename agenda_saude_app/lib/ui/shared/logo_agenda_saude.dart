import 'package:flutter/material.dart';

// Cabecalho com a marca do app, usado nas telas de entrada (login e
// cadastro), inspirado no mockup do TCC (Figura 11 - Tela de Login).
class LogoAgendaSaude extends StatelessWidget {
  const LogoAgendaSaude({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(Icons.favorite_rounded, size: 56, color: colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          'Agenda Saúde',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
