import 'package:flutter/material.dart';

// Botao grande com estado selecionado/nao selecionado, usado em escolhas do
// tipo "uma entre poucas opcoes": perfil no cadastro, respostas Sim/Nao e
// tipo de diabetes na triagem.
class BotaoSelecionavel extends StatelessWidget {
  final String rotulo;
  final bool selecionado;
  final VoidCallback aoTocar;

  const BotaoSelecionavel({
    super.key,
    required this.rotulo,
    required this.selecionado,
    required this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: aoTocar,
        style: OutlinedButton.styleFrom(
          backgroundColor: selecionado ? cor : null,
          foregroundColor:
              selecionado ? Theme.of(context).colorScheme.onPrimary : cor,
          side: BorderSide(color: cor, width: 2),
        ),
        child: Text(
          rotulo,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
