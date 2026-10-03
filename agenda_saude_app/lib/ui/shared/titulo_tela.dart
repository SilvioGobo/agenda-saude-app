import 'package:flutter/material.dart';

// Titulo grande no topo do conteudo da tela (28, negrito). Nas telas do
// paciente ele substitui o titulo do AppBar: a barra fica so com o botao
// "Menu"/"Voltar" e o titulo ganha espaco para ser lido sem esforco - e para
// quebrar linha com a fonte do celular aumentada. Marcado como cabecalho
// para o leitor de tela.
class TituloTela extends StatelessWidget {
  final String texto;
  final String? subtitulo;

  const TituloTela(this.texto, {super.key, this.subtitulo});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        if (subtitulo != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitulo!,
            style: TextStyle(
              fontSize: 18,
              height: 1.35,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
