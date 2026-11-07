import 'package:flutter/material.dart';

// Valor grande com os botoes "Menos" e "Mais" (64dp): a entrada de um numero
// sem teclado, para quem tem dificuldade de digitar - horas de sono, minutos de
// exercicio. O valor aparece em texto grande dentro de uma caixa; os botoes
// ficam lado a lado e, com a fonte do celular muito aumentada, um embaixo do
// outro (NF004). Passar `null` em [aoDiminuir] ou [aoAumentar] desliga o botao
// no limite.
class ContadorGrande extends StatelessWidget {
  // O valor ja formatado: "7 h 30 min".
  final String valor;
  // O que o leitor de tela diz no lugar do valor: "7 horas e 30 minutos".
  final String valorParaLeitor;
  final String descricaoMenos;
  final String descricaoMais;
  final VoidCallback? aoDiminuir;
  final VoidCallback? aoAumentar;

  const ContadorGrande({
    super.key,
    required this.valor,
    required this.valorParaLeitor,
    required this.descricaoMenos,
    required this.descricaoMais,
    required this.aoDiminuir,
    required this.aoAumentar,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fonteMuitoGrande = MediaQuery.textScalerOf(context).scale(18) > 27;

    final botaoMenos = _BotaoDoContador(
      rotulo: 'Menos',
      descricao: descricaoMenos,
      icone: Icons.remove_rounded,
      destacado: false,
      aoTocar: aoDiminuir,
    );
    final botaoMais = _BotaoDoContador(
      rotulo: 'Mais',
      descricao: descricaoMais,
      icone: Icons.add_rounded,
      destacado: true,
      aoTocar: aoAumentar,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: valorParaLeitor,
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorScheme.outline, width: 2),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  valor,
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (fonteMuitoGrande) ...[
          botaoMais,
          const SizedBox(height: 12),
          botaoMenos,
        ] else
          Row(
            children: [
              Expanded(child: botaoMenos),
              const SizedBox(width: 12),
              Expanded(child: botaoMais),
            ],
          ),
      ],
    );
  }
}

// "- Menos" (contorno) e "+ Mais" (preenchido). O rotulo falado diz o que o
// botao faz, ja que "Menos" sozinho nao diz menos de que.
class _BotaoDoContador extends StatelessWidget {
  final String rotulo;
  final String descricao;
  final IconData icone;
  final bool destacado;
  final VoidCallback? aoTocar;

  const _BotaoDoContador({
    required this.rotulo,
    required this.descricao,
    required this.icone,
    required this.destacado,
    required this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    const tamanho = Size.fromHeight(64);
    const texto = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);

    final Widget botao = destacado
        ? FilledButton.icon(
            onPressed: aoTocar,
            style: FilledButton.styleFrom(
              minimumSize: tamanho,
              textStyle: texto,
              iconSize: 28,
            ),
            icon: Icon(icone),
            label: Text(rotulo),
          )
        : OutlinedButton.icon(
            onPressed: aoTocar,
            style: OutlinedButton.styleFrom(
              minimumSize: tamanho,
              textStyle: texto,
              iconSize: 28,
            ),
            icon: Icon(icone),
            label: Text(rotulo),
          );

    return Semantics(
      button: true,
      enabled: aoTocar != null,
      label: descricao,
      onTap: aoTocar,
      excludeSemantics: true,
      child: botao,
    );
  }
}
