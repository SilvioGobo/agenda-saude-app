import 'package:flutter/material.dart';

// Linha horizontal de referencia no grafico (a meta de agua, os limites da
// faixa de glicemia...), com o texto que explica ela na legenda.
class LinhaDeReferencia {
  final double valor;
  final String rotulo;

  const LinhaDeReferencia({required this.valor, required this.rotulo});
}

// O que uma cor de barra significa ("Meta atingida", "Na faixa"...).
class LegendaDeCor {
  final Color cor;
  final String rotulo;

  const LegendaDeCor({required this.cor, required this.rotulo});
}

// Grafico de barras com uma barra por dia do mes (RF05: "graficos e metricas
// consolidadas"). Sem biblioteca: sao barras de Container, que crescem e
// encolhem com a tela e dispensam um pacote novo. A cor da barra vem de quem
// usa ([corDaBarra]) e nunca e a unica informacao - a legenda explica as
// cores, a [descricao] resume o grafico em uma frase para o leitor de tela e
// os numeros tambem aparecem em texto no cartao. Dias sem dado (null) ficam
// sem barra.
class GraficoDiario extends StatelessWidget {
  static const double altura = 150;

  // Um valor por dia do mes, do dia 1 em diante.
  final List<double?> valores;
  // Valor que ocupa a altura toda do grafico.
  final double maximo;
  final List<LinhaDeReferencia> linhas;
  final List<LegendaDeCor> legendas;
  final Color Function(double valor) corDaBarra;
  final String descricao;

  const GraficoDiario({
    super.key,
    required this.valores,
    required this.maximo,
    required this.corDaBarra,
    required this.descricao,
    this.linhas = const [],
    this.legendas = const [],
  });

  double _fracao(double valor) => (valor / maximo).clamp(0.0, 1.0).toDouble();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      image: true,
      label: descricao,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: altura,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(height: 2, color: colorScheme.outline),
                  ),
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final valor in valores)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1),
                              child: valor == null
                                  ? const SizedBox.shrink()
                                  : Align(
                                      alignment: Alignment.bottomCenter,
                                      child: FractionallySizedBox(
                                        // Pelo menos um tico, para um valor
                                        // pequeno nao sumir.
                                        heightFactor:
                                            _fracao(valor).clamp(0.03, 1.0),
                                        widthFactor: 1,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: corDaBarra(valor),
                                            borderRadius:
                                                const BorderRadius.vertical(
                                              top: Radius.circular(3),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // As linhas de referencia por cima das barras.
                  for (final linha in linhas)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: altura * _fracao(linha.valor) - 1,
                      child: Container(
                        height: 2,
                        color: colorScheme.onSurface,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _EixoDosDias(dias: valores.length),
            if (linhas.isNotEmpty || legendas.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  for (final legenda in legendas)
                    _ItemDeLegenda(
                      marca: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: legenda.cor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      rotulo: legenda.rotulo,
                    ),
                  for (final linha in linhas)
                    _ItemDeLegenda(
                      marca: Container(
                        width: 24,
                        height: 3,
                        color: colorScheme.onSurface,
                      ),
                      rotulo: linha.rotulo,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Uma entrada da legenda: a marca (quadrado de cor ou traco) e o texto.
class _ItemDeLegenda extends StatelessWidget {
  final Widget marca;
  final String rotulo;

  const _ItemDeLegenda({required this.marca, required this.rotulo});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        marca,
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            rotulo,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

// Os numeros dos dias sob as barras: o dia 1 e de 5 em 5, centrados na barra
// de cada um.
class _EixoDosDias extends StatelessWidget {
  final int dias;

  const _EixoDosDias({required this.dias});

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.onSurfaceVariant;
    final estilo = TextStyle(fontSize: 16, color: cor);
    final rotulados = [
      for (var dia = 1; dia <= dias; dia++)
        if (dia == 1 || dia % 5 == 0) dia,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final coluna = constraints.maxWidth / dias;
        return Stack(
          // O ultimo numero passa um pouco da borda do grafico; sem cortar.
          clipBehavior: Clip.none,
          children: [
            // Reserva a altura de uma linha de texto (que cresce com a fonte).
            Opacity(opacity: 0, child: Text('00', style: estilo)),
            for (final dia in rotulados)
              Positioned(
                left: coluna * (dia - 0.5) - 16,
                width: 32,
                top: 0,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('$dia', style: estilo),
                ),
              ),
          ],
        );
      },
    );
  }
}
