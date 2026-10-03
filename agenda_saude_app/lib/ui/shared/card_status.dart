import 'package:flutter/material.dart';

// Selo de status colorido (ex.: "ESTÁVEL"/"ATENÇÃO"), usado no painel do
// paciente (Figura 13) e futuramente no painel do acompanhante (Figura 15),
// que segue o mesmo padrão visual. Passe uma cor semantica de AppCores
// (ex.: AppCores.sucesso): o fundo e um tom claro dela mesma, e os tons de
// AppCores mantem o texto com contraste acima de 4,5:1 sobre esse fundo.
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
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icone, color: cor, size: 32),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              rotulo,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: cor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
