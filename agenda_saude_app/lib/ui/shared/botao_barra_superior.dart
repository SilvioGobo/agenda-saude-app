import 'package:flutter/material.dart';

// Botao do canto esquerdo da barra superior com icone + texto ("Menu",
// "Voltar"). Idosos nem sempre reconhecem icones soltos - os tres risquinhos
// ou a seta -, entao o rotulo escrito fica sempre visivel (NF004).
//
// Usar como `leading` do AppBar junto com `leadingWidth: largura`. Com a
// fonte do celular muito aumentada o conteudo encolhe para caber, em vez de
// estourar a barra.
class BotaoBarraSuperior extends StatelessWidget {
  static const double largura = 136;

  final IconData icone;
  final String rotulo;
  final VoidCallback aoTocar;

  const BotaoBarraSuperior({
    super.key,
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
  });

  const BotaoBarraSuperior.menu({super.key, required this.aoTocar})
      : icone = Icons.menu_rounded,
        rotulo = 'Menu';

  const BotaoBarraSuperior.voltar({super.key, required this.aoTocar})
      : icone = Icons.arrow_back_rounded,
        rotulo = 'Voltar';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: aoTocar,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            iconSize: 28,
          ),
          icon: Icon(icone),
          label: Text(rotulo),
        ),
      ),
    );
  }
}
