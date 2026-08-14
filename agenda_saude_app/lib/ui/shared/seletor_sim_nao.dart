import 'package:flutter/material.dart';

import 'botao_selecionavel.dart';

// Par de botoes Sim/Nao reutilizado nas varias perguntas da triagem.
class SeletorSimNao extends StatelessWidget {
  final bool? valor;
  final ValueChanged<bool> aoResponder;
  final bool pequeno;

  const SeletorSimNao({
    super.key,
    required this.valor,
    required this.aoResponder,
    this.pequeno = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BotaoSelecionavel(
            rotulo: 'Sim',
            selecionado: valor == true,
            aoTocar: () => aoResponder(true),
            pequeno: pequeno,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: BotaoSelecionavel(
            rotulo: 'Não',
            selecionado: valor == false,
            aoTocar: () => aoResponder(false),
            pequeno: pequeno,
          ),
        ),
      ],
    );
  }
}
