import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/metas/metas_personalizadas.dart';
import '../../domain/models/paciente.dart';
import '../shared/barra_acoes.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/botao_grande.dart';
import '../shared/titulo_tela.dart';
import 'ajustar_metas_view.dart';
import 'formato_metas.dart';
import 'metas_viewmodel.dart';
import 'recalcular_metas_view.dart';

// "Minhas metas": o que o app calculou a partir da triagem - rotina do dia,
// alimentacao e limites - com atalhos para ajustar a rotina e para atualizar
// o peso. Logo depois da triagem ela abre em modo `aoContinuar` (sem
// "Voltar"), para o paciente conferir as metas antes de ir ao painel.
class MetasView extends StatelessWidget {
  // Preenchido so na primeira vez, logo depois da triagem.
  final ValueChanged<Paciente>? aoContinuar;

  const MetasView({super.key, this.aoContinuar});

  static Widget comProviders(
    Paciente paciente, {
    ValueChanged<Paciente>? aoAtualizar,
    ValueChanged<Paciente>? aoContinuar,
  }) {
    return ChangeNotifierProvider(
      create: (_) =>
          MetasViewModel(paciente: paciente, aoAtualizar: aoAtualizar),
      child: MetasView(aoContinuar: aoContinuar),
    );
  }

  void _abrir(BuildContext context, Widget tela) {
    final viewModel = context.read<MetasViewModel>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ChangeNotifierProvider.value(value: viewModel, child: tela),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MetasViewModel>();
    final metas = viewModel.metas;
    final primeiraVez = aoContinuar != null;

    return Scaffold(
      // As acoes ficam fixas na base: o paciente nao precisa rolar os cartoes
      // ate o fim para achar "Aceitar e continuar" ou "Atualizar meu peso".
      bottomNavigationBar: BarraAcoes(
        children: [
          BotaoGrande(
            rotulo: primeiraVez
                ? (metas == null ? 'Continuar' : 'Aceitar e continuar')
                : 'Atualizar meu peso',
            icone: primeiraVez
                ? Icons.check_rounded
                : Icons.monitor_weight_rounded,
            aoTocar: primeiraVez
                ? () => aoContinuar!(viewModel.paciente)
                : () => _abrir(context, const RecalcularMetasView()),
          ),
          if (metas != null)
            OutlinedButton.icon(
              onPressed: () => _abrir(context, const AjustarMetasView()),
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Ajustar metas'),
            ),
        ],
      ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: BotaoBarraSuperior.largura,
        leading: primeiraVez
            ? null
            : BotaoBarraSuperior.voltar(
                aoTocar: () => Navigator.of(context).pop(),
              ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            TituloTela(
              primeiraVez ? 'Suas metas' : 'Minhas metas',
              subtitulo: metas == null
                  ? 'Ainda não foi possível calcular suas metas.'
                  : 'Calculamos com base nos seus dados de saúde.',
            ),
            const SizedBox(height: 24),
            if (metas != null) ...[
              _AvisoSugestao(
                limiteLiquidoMl: viewModel.paciente.limiteLiquidoMl,
              ),
              const SizedBox(height: 16),
              _CardRotina(metas: metas),
              const SizedBox(height: 16),
              _CardAlimentacao(metas: metas),
              const SizedBox(height: 16),
              _CardLimites(metas: metas),
              const SizedBox(height: 16),
              _CardImc(metas: metas),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }
}

// As metas sao sugestoes: dizer isso na tela evita que sejam lidas como
// prescricao. Cor neutra - vermelho e so para alerta de saude.
class _AvisoSugestao extends StatelessWidget {
  final int? limiteLiquidoMl;

  const _AvisoSugestao({required this.limiteLiquidoMl});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final limite = limiteLiquidoMl;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_rounded,
            size: 28,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'São sugestões. Elas não substituem a orientação do seu médico '
              'ou nutricionista.'
              '${limite == null ? '' : ' Sua água respeita o limite de '
                        '${formatarDecimal(limite / 1000)} litros por dia que seu '
                        'médico definiu.'}',
              style: TextStyle(
                fontSize: 18,
                height: 1.35,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardRotina extends StatelessWidget {
  final MetasPersonalizadas metas;

  const _CardRotina({required this.metas});

  @override
  Widget build(BuildContext context) {
    return _CardSecao(
      titulo: 'Rotina do dia',
      linhas: [
        _LinhaMeta(
          icone: Icons.water_drop_rounded,
          rotulo: 'Água',
          valor:
              '${metas.hidratacaoCopos} copos '
              '(${formatarMilhar(metas.hidratacaoMl)} ml)',
        ),
        _LinhaMeta(
          icone: Icons.directions_walk_rounded,
          rotulo: 'Passos',
          valor: '${formatarMilhar(metas.passos)} por dia',
        ),
        _LinhaMeta(
          icone: Icons.fitness_center_rounded,
          rotulo: 'Exercício',
          valor: '${metas.exercicioMinutosSemana} minutos por semana',
        ),
        _LinhaMeta(
          icone: Icons.bedtime_rounded,
          rotulo: 'Sono',
          valor:
              '${metas.sonoMinHoras} a ${metas.sonoMaxHoras} horas por noite',
        ),
      ],
    );
  }
}

class _CardAlimentacao extends StatelessWidget {
  final MetasPersonalizadas metas;

  const _CardAlimentacao({required this.metas});

  @override
  Widget build(BuildContext context) {
    return _CardSecao(
      titulo: 'Alimentação',
      linhas: [
        _LinhaMeta(
          icone: Icons.local_fire_department_rounded,
          rotulo: 'Calorias',
          valor: '${formatarMilhar(metas.calorias)} kcal por dia',
        ),
        _LinhaMeta(
          icone: Icons.grain_rounded,
          rotulo: 'Carboidratos',
          valor: '${metas.carboidratosG} g',
        ),
        _LinhaMeta(
          icone: Icons.egg_alt_rounded,
          rotulo: 'Proteínas',
          valor: '${metas.proteinasG} g',
        ),
        _LinhaMeta(
          icone: Icons.opacity_rounded,
          rotulo: 'Gorduras',
          valor: '${metas.gordurasG} g',
        ),
        _LinhaMeta(
          icone: Icons.eco_rounded,
          rotulo: 'Fibras',
          valor: 'pelo menos ${metas.fibrasG} g',
        ),
      ],
    );
  }
}

class _CardLimites extends StatelessWidget {
  final MetasPersonalizadas metas;

  const _CardLimites({required this.metas});

  @override
  Widget build(BuildContext context) {
    return _CardSecao(
      titulo: 'Limites por dia',
      linhas: [
        _LinhaMeta(
          icone: Icons.grain_rounded,
          rotulo: 'Sódio',
          valor: 'até ${formatarMilhar(metas.sodioMaxMg)} mg',
        ),
        _LinhaMeta(
          icone: Icons.cookie_rounded,
          rotulo: 'Açúcar livre',
          valor: 'até ${metas.acucarLivreMaxG} g',
        ),
        _LinhaMeta(
          icone: Icons.opacity_rounded,
          rotulo: 'Gordura saturada',
          valor: 'até ${metas.gorduraSaturadaMaxG} g',
        ),
      ],
    );
  }
}

class _CardImc extends StatelessWidget {
  final MetasPersonalizadas metas;

  const _CardImc({required this.metas});

  @override
  Widget build(BuildContext context) {
    return _CardSecao(
      titulo: 'Seu peso',
      linhas: [
        _LinhaMeta(
          icone: Icons.monitor_weight_rounded,
          rotulo: 'IMC ${formatarDecimal(metas.imc)}',
          valor: rotuloClassificacaoImc(metas.classificacaoImc),
        ),
      ],
    );
  }
}

class _CardSecao extends StatelessWidget {
  final String titulo;
  final List<Widget> linhas;

  const _CardSecao({required this.titulo, required this.linhas});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                titulo,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < linhas.length; i++) ...[
              if (i > 0) const Divider(height: 24),
              linhas[i],
            ],
          ],
        ),
      ),
    );
  }
}

// Icone, nome da meta e valor. O leitor de tela le "Água: 8 copos..." numa
// frase so, em vez de pedacos soltos.
class _LinhaMeta extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final String valor;

  const _LinhaMeta({
    required this.icone,
    required this.rotulo,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      label: '$rotulo: $valor',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Icon(icone, size: 32, color: colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rotulo,
                    style: TextStyle(
                      fontSize: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    valor,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
