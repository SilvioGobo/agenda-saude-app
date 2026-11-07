import 'package:flutter/material.dart';

// Pergunta numerada em caixa alta (20, negrito) que abre cada bloco de um
// formulario da rotina ("1. QUANTAS HORAS VOCE DORMIU?"). Marcada como
// cabecalho para o leitor de tela. E o mesmo visual das perguntas da tela de
// glicemia e insulina.
class PerguntaFormulario extends StatelessWidget {
  final String texto;

  const PerguntaFormulario(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
