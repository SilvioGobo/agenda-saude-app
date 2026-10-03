import 'package:flutter/material.dart';

// Botao de atalho principal das telas (ex.: "Minha Rotina" no painel do
// paciente). Maior que o botao padrao do tema - 72dp de altura, texto 20 e
// icone 30 - porque e o alvo de toque mais importante da tela para o idoso
// (NF004). O texto quebra em ate duas linhas em vez de ser cortado quando o
// usuario aumenta a fonte do celular.
//
// `principal` e preenchido com a cor primaria; o secundario usa o container
// verde-agua claro (botao "tonal" do Material 3), como no mockup do TCC.
class BotaoGrande extends StatelessWidget {
  final String rotulo;
  final IconData icone;
  final VoidCallback? aoTocar;
  final bool principal;

  const BotaoGrande({
    super.key,
    required this.rotulo,
    required this.icone,
    required this.aoTocar,
    this.principal = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final estilo = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(72),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: const StadiumBorder(),
      backgroundColor:
          principal ? colorScheme.primary : colorScheme.primaryContainer,
      foregroundColor:
          principal ? colorScheme.onPrimary : colorScheme.onPrimaryContainer,
      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      iconSize: 30,
    );

    return FilledButton.icon(
      onPressed: aoTocar,
      style: estilo,
      icon: Icon(icone),
      label: Text(rotulo, maxLines: 2, textAlign: TextAlign.center),
    );
  }
}
