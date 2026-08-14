import 'package:flutter/material.dart';

// Agrupa perguntas que so aparecem como desdobramento de uma resposta Sim,
// com uma barra lateral para deixar visualmente claro que elas pertencem
// aquela pergunta (nao sao perguntas novas e independentes).
class PerguntasAninhadas extends StatelessWidget {
  final List<Widget> children;

  const PerguntasAninhadas({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: cor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
