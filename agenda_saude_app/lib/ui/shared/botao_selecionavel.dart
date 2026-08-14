import 'package:flutter/material.dart';

// Botao grande com estado selecionado/nao selecionado, usado em escolhas do
// tipo "uma entre poucas opcoes": perfil no cadastro, respostas Sim/Nao e
// tipo de diabetes na triagem. Mostra um icone de check quando selecionado,
// igual ao mockup do TCC (Figura 12 - Tela de Triagem).
//
// `pequeno` reduz fonte/altura/icone - usado em perguntas aninhadas (que so
// aparecem como desdobramento de uma resposta Sim), para ficarem menos em
// destaque que a pergunta principal.
class BotaoSelecionavel extends StatelessWidget {
  final String rotulo;
  final bool selecionado;
  final VoidCallback aoTocar;
  final IconData? icone;
  final bool pequeno;

  const BotaoSelecionavel({
    super.key,
    required this.rotulo,
    required this.selecionado,
    required this.aoTocar,
    this.icone,
    this.pequeno = false,
  });

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    final tamanhoIcone = pequeno ? 16.0 : 20.0;

    return OutlinedButton(
      onPressed: aoTocar,
      style: OutlinedButton.styleFrom(
        backgroundColor: selecionado ? cor : null,
        foregroundColor:
            selecionado ? Theme.of(context).colorScheme.onPrimary : cor,
        minimumSize: pequeno ? const Size.fromHeight(44) : null,
        textStyle: pequeno ? const TextStyle(fontSize: 14) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (selecionado)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.check_rounded, size: tamanhoIcone),
            )
          else if (icone != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(icone, size: tamanhoIcone),
            ),
          Flexible(
            child: Text(
              rotulo,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
