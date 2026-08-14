import 'package:flutter/material.dart';

// Remove o efeito de "brilho" (glow) que o Flutter mostra por padrao ao
// rolar alem do limite da tela - nao combina com o resto do visual do app.
class SemBrilhoAoRolar extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
