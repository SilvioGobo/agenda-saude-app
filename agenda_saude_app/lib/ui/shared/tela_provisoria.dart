import 'package:flutter/material.dart';

import 'botao_barra_superior.dart';
import 'titulo_tela.dart';

// Tela temporaria usada como destino de navegacao enquanto as telas reais
// (ex.: Minha Rotina) ainda nao foram construidas no cronograma.
class TelaProvisoria extends StatelessWidget {
  final String titulo;
  final String mensagem;

  const TelaProvisoria({
    super.key,
    required this.titulo,
    required this.mensagem,
  });

  @override
  Widget build(BuildContext context) {
    final podeVoltar = Navigator.of(context).canPop();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: podeVoltar ? BotaoBarraSuperior.largura : null,
        leading: podeVoltar
            ? BotaoBarraSuperior.voltar(
                aoTocar: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            TituloTela(titulo, subtitulo: mensagem),
          ],
        ),
      ),
    );
  }
}
