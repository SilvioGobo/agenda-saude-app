import 'package:flutter/material.dart';

// Rotulo em negrito usado acima de cada pergunta/campo. `pequeno` reduz
// fonte e usa um cinza mais claro, para perguntas aninhadas (dentro de
// PerguntasAninhadas), que devem ficar menos em destaque que a principal.
class RotuloPergunta extends StatelessWidget {
  final String texto;
  final bool pequeno;

  const RotuloPergunta(this.texto, {super.key, this.pequeno = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: pequeno ? 14 : 16,
          fontWeight: FontWeight.bold,
          color: pequeno
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : null,
        ),
      ),
    );
  }
}
