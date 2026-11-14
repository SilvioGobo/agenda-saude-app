import 'dart:math';

import 'package:flutter/material.dart';

import 'botao_barra_superior.dart';
import 'botao_salvar.dart';

// Barra superior das telas que salvam um formulario (registrar o sono, meus
// remedios, meus dados...): "Cancelar" a esquerda, no lugar do "Voltar" - os
// dois saem sem gravar -, e "Salvar" a direita, como nos apps de agenda e de
// contatos do celular. Fixa no alto, a pessoa nao precisa rolar ate o fim
// para achar o botao que conclui a tarefa (NF004), e o conteudo fica com a
// altura que os botoes de baixo ocupavam. O erro de salvar aparece logo
// abaixo dela (`CorpoFormulario`).
class BarraSuperiorFormulario extends StatelessWidget
    implements PreferredSizeWidget {
  // "Cancelar" e um pouco mais largo que "Voltar".
  static const double larguraCancelar = 152;

  final bool salvando;
  final VoidCallback aoSalvar;
  final VoidCallback aoCancelar;

  const BarraSuperiorFormulario({
    super.key,
    required this.salvando,
    required this.aoSalvar,
    required this.aoCancelar,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // Com a fonte do celular muito aumentada, o "Salvar" encolhe para nao
    // passar por cima do "Cancelar".
    final larguraSalvar =
        max(0.0, MediaQuery.sizeOf(context).width - larguraCancelar - 8);

    return AppBar(
      automaticallyImplyLeading: false,
      leadingWidth: larguraCancelar,
      leading: BotaoBarraSuperior.cancelar(aoTocar: aoCancelar),
      actions: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: larguraSalvar),
          child: BotaoSalvar(salvando: salvando, aoTocar: aoSalvar),
        ),
      ],
    );
  }
}
