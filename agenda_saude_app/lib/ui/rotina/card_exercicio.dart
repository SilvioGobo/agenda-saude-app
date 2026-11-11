import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../../domain/models/registro_exercicio.dart';
import '../shared/dialogo_confirmacao.dart';
import 'exercicio_viewmodel.dart';
import 'formato_exercicio.dart';
import 'registrar_exercicio_view.dart';

// Cartao "Exercicio" do checklist de rotina (RF 03.3): o que o paciente fez
// hoje, o progresso da meta de minutos da semana e o botao para registrar mais
// um. Registrar tem tres perguntas, entao abre a tela propria
// RegistrarExercicioView (a Rotina e um resumo do dia, com um cartao compacto
// por atividade). Cada exercicio de hoje tem um "Apagar" para corrigir um
// registro feito por engano; o progresso diz se a meta foi atingida em texto e
// icone, nunca so na cor (NF004).
class CardExercicio extends StatelessWidget {
  const CardExercicio({super.key});

  Future<void> _abrirRegistro(
    BuildContext context,
    ExercicioViewModel viewModel,
  ) async {
    final salvou = await Navigator.of(context).push(
      RegistrarExercicioView.rota(viewModel.novoRegistro()),
    );
    if (!context.mounted || salvou != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exercício registrado.', style: TextStyle(fontSize: 18)),
      ),
    );
  }

  Future<void> _apagar(
    BuildContext context,
    ExercicioViewModel viewModel,
    RegistroExercicio registro,
  ) async {
    final confirmou = await mostrarDialogoConfirmacao(
      context,
      titulo: 'Apagar este exercício?',
      mensagem: '${registro.tipoExercicio}, '
          '${formatarMinutos(registro.duracaoMinutos)}. Ele deixa de contar '
          'na meta da semana.',
      rotuloConfirmar: 'Apagar',
      iconeConfirmar: Icons.delete_rounded,
      rotuloCancelar: 'Manter',
    );
    if (!confirmou) return;
    await viewModel.apagar(registro);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ExercicioViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final pronto = !viewModel.carregando && !viewModel.erroDeLeitura;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Resumo(viewModel: viewModel, mostrarResumo: pronto),
            const SizedBox(height: 16),
            if (viewModel.erroDeLeitura)
              Semantics(
                liveRegion: true,
                child: const Text(
                  'Não foi possível carregar o seu exercício. Volte e abra '
                  'esta tela de novo.',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: AppCores.perigo,
                  ),
                ),
              )
            else if (pronto) ...[
              if (viewModel.fezExercicioHoje) ...[
                for (final registro in viewModel.registrosDeHoje) ...[
                  _LinhaDeExercicio(
                    registro: registro,
                    aoApagar: () => _apagar(context, viewModel, registro),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ],
            if (viewModel.mensagemErro != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  viewModel.mensagemErro!,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed:
                  pronto ? () => _abrirRegistro(context, viewModel) : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
                textStyle:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                iconSize: 28,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Registrar exercício'),
            ),
          ],
        ),
      ),
    );
  }
}

// Icone, titulo, o que foi feito hoje e a barra de progresso da semana. O
// leitor de tela le tudo numa frase so.
class _Resumo extends StatelessWidget {
  final ExercicioViewModel viewModel;
  final bool mostrarResumo;

  const _Resumo({required this.viewModel, required this.mostrarResumo});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semana = viewModel.minutosNaSemana;
    final meta = viewModel.metaSemanalMinutos;
    final hoje = viewModel.fezExercicioHoje
        ? 'Hoje: ${formatarMinutos(viewModel.minutosHoje)}'
        : 'Nenhum exercício hoje';

    return Semantics(
      container: true,
      label: mostrarResumo
          ? 'Exercício: ${viewModel.fezExercicioHoje ? 'hoje ${falarMinutos(viewModel.minutosHoje)}' : 'nenhum exercício hoje'}. '
              'Nesta semana, $semana de $meta minutos.'
          : 'Exercício',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_walk_rounded,
                    size: 32,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Exercício',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (mostrarResumo)
                        Text(
                          hoje,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (mostrarResumo) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: viewModel.progressoDaSemana,
                  minHeight: 16,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  color: viewModel.metaAtingida
                      ? AppCores.sucesso
                      : colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nesta semana: $semana de $meta min',
                style: TextStyle(
                  fontSize: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Um exercicio de hoje: o nome, "30 min · Moderada" e o botao "Apagar" (48dp)
// embaixo, para nao apertar o texto com a fonte do celular aumentada.
class _LinhaDeExercicio extends StatelessWidget {
  final RegistroExercicio registro;
  final VoidCallback aoApagar;

  const _LinhaDeExercicio({required this.registro, required this.aoApagar});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            label: '${registro.tipoExercicio}, '
                '${falarMinutos(registro.duracaoMinutos)}, intensidade '
                '${registro.intensidade.toLowerCase()}.',
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    registro.tipoExercicio,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${formatarMinutos(registro.duracaoMinutos)} · '
                    '${registro.intensidade}',
                    style: TextStyle(
                      fontSize: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: aoApagar,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                textStyle:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                iconSize: 24,
                foregroundColor: AppCores.perigo,
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Apagar'),
            ),
          ),
        ],
      ),
    );
  }
}
