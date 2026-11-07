import 'package:flutter/material.dart';

// Botao "SALVAR" que fecha um formulario da rotina: preenchido, 72dp de altura,
// com um check - ou um indicador de progresso enquanto grava, quando fica
// desligado para nao gravar duas vezes. E o mesmo visual do botao da tela de
// glicemia e insulina.
class BotaoSalvar extends StatelessWidget {
  final bool salvando;
  final VoidCallback aoTocar;
  final String rotulo;

  const BotaoSalvar({
    super.key,
    required this.salvando,
    required this.aoTocar,
    this.rotulo = 'SALVAR',
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: salvando ? null : aoTocar,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(72),
        textStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
        iconSize: 32,
      ),
      icon: salvando
          ? SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            )
          : const Icon(Icons.check_rounded),
      label: Text(rotulo),
    );
  }
}
