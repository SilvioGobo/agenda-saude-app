import 'package:flutter/material.dart';

// Barra fixa na base da tela (`Scaffold.bottomNavigationBar`) com as acoes
// principais. Em telas com conteudo longo ela evita que o idoso precise rolar
// ate o fim para achar o botao que conclui a tarefa (NF004). Os botoes ficam
// um embaixo do outro, com a largura toda, separados por 12dp.
class BarraAcoes extends StatelessWidget {
  final List<Widget> children;

  const BarraAcoes({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
