import 'package:flutter/material.dart';

import '../../core/theme/app_cores.dart';
import '../../domain/alimentos/nutrientes.dart';
import '../../domain/metas/metas_personalizadas.dart';
import '../metas/formato_metas.dart';

// Calorias e macronutrientes de um conjunto de refeicoes (o plano do dia ou o
// que o paciente ja comeu hoje) frente as metas dele. Cada linha diz o valor
// em texto ("920 de 1.800 kcal") e tem uma barra de apoio; o sodio e um
// limite maximo, entao passar dele aparece escrito, nao so na cor.
// Sem metas (conta antiga) so mostra os valores.
class ResumoNutricional extends StatelessWidget {
  final String titulo;
  final Nutrientes nutrientes;
  final MetasPersonalizadas? metas;

  const ResumoNutricional({
    super.key,
    required this.titulo,
    required this.nutrientes,
    required this.metas,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metas = this.metas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            titulo,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _LinhaNutriente(
          rotulo: 'Calorias',
          valor: nutrientes.kcal,
          meta: metas?.calorias.toDouble(),
          unidade: 'kcal',
        ),
        _LinhaNutriente(
          rotulo: 'Carboidratos',
          valor: nutrientes.carboidratoG,
          meta: metas?.carboidratosG.toDouble(),
          unidade: 'g',
        ),
        _LinhaNutriente(
          rotulo: 'Proteínas',
          valor: nutrientes.proteinaG,
          meta: metas?.proteinasG.toDouble(),
          unidade: 'g',
        ),
        _LinhaNutriente(
          rotulo: 'Gorduras',
          valor: nutrientes.gorduraG,
          meta: metas?.gordurasG.toDouble(),
          unidade: 'g',
        ),
        _LinhaNutriente(
          rotulo: 'Sódio',
          valor: nutrientes.sodioMg,
          meta: metas?.sodioMaxMg.toDouble(),
          unidade: 'mg',
          limiteMaximo: true,
        ),
      ],
    );
  }
}

class _LinhaNutriente extends StatelessWidget {
  final String rotulo;
  final double valor;
  final double? meta;
  final String unidade;
  final bool limiteMaximo;

  const _LinhaNutriente({
    required this.rotulo,
    required this.valor,
    required this.meta,
    required this.unidade,
    this.limiteMaximo = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final meta = this.meta;
    final passouDoLimite = limiteMaximo && meta != null && valor > meta;

    final atual = formatarMilhar(valor.round());
    final texto = meta == null
        ? '$atual $unidade'
        : limiteMaximo
        ? '$atual de ${formatarMilhar(meta.round())} $unidade (limite)'
        : '$atual de ${formatarMilhar(meta.round())} $unidade';
    final alerta = passouDoLimite ? ' Acima do limite.' : '';

    return Semantics(
      container: true,
      label: '$rotulo: $texto.$alerta',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Lado a lado quando cabe; com a fonte muito grande o valor desce
              // para a linha de baixo em vez de estourar a tela.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 2,
                children: [
                  Text(
                    rotulo,
                    style: TextStyle(
                      fontSize: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    texto,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: passouDoLimite
                          ? AppCores.aviso
                          : colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              if (passouDoLimite)
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Acima do limite',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppCores.aviso,
                    ),
                  ),
                ),
              if (meta != null && meta > 0) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (valor / meta).clamp(0.0, 1.0).toDouble(),
                    minHeight: 10,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    color: passouDoLimite
                        ? AppCores.aviso
                        : colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
