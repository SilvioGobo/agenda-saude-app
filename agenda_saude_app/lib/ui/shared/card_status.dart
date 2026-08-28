import 'package:flutter/material.dart';

// Selo de status colorido (ex.: "ESTÁVEL"/"ATENÇÃO"), usado no painel do
// paciente (Figura 13) e futuramente no painel do acompanhante (Figura 15),
// que segue o mesmo padrão visual.
class CardStatus extends StatelessWidget {
  final String rotulo;
  final IconData icone;
  final Color cor;

  const CardStatus({
    super.key,
    required this.rotulo,
    required this.icone,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cor, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icone, color: cor, size: 28),
          const SizedBox(width: 10),
          Text(
            rotulo,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }
}
