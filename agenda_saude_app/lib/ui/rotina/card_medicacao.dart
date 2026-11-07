import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../../domain/medicacao/dose_planejada.dart';
import '../relatorios/formato_relatorios.dart';
import '../shared/card_status.dart';
import 'medicacao_viewmodel.dart';
import 'meus_remedios_view.dart';

// Cartao "Medicacoes" do checklist de rotina (RF003, Figura 14 do TCC): uma
// linha por dose - um remedio num horario -, com uma caixa de selecao grande
// que o paciente toca para marcar como tomada. Cada linha diz "Tomado as 08:10"
// ou "Ainda nao tomado" em texto, alem do icone (nunca so a cor - NF004). O
// botao "Meus remedios" abre a tela onde ele cadastra o nome, a dose e os
// horarios de cada remedio.
class CardMedicacao extends StatelessWidget {
  const CardMedicacao({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MedicacaoViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final pronto = !viewModel.carregando && !viewModel.erroDeLeitura;
    final doses = viewModel.doses;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Resumo(
              viewModel: viewModel,
              mostrarProgresso: pronto && doses.isNotEmpty,
            ),
            const SizedBox(height: 16),
            if (viewModel.erroDeLeitura)
              Semantics(
                liveRegion: true,
                child: const Text(
                  'Não foi possível carregar os seus remédios de hoje. Volte '
                  'e abra esta tela de novo.',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: AppCores.perigo,
                  ),
                ),
              )
            else if (doses.isEmpty)
              Text(
                'Você ainda não cadastrou seus remédios. Toque em "Meus '
                'remédios" para adicionar o nome, a dose e os horários.',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.35,
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              for (final dose in doses) ...[
                _LinhaDeDose(
                  dose: dose,
                  tomadaEm: viewModel.registroDa(dose)?.dataHora,
                  aoTocar: pronto ? () => viewModel.alternar(dose) : null,
                ),
                const SizedBox(height: 8),
              ],
              if (viewModel.todasTomadas) ...[
                const SizedBox(height: 8),
                const CardStatus(
                  rotulo: 'REMÉDIOS DE HOJE TOMADOS',
                  icone: Icons.check_circle_rounded,
                  cor: AppCores.sucesso,
                ),
              ],
            ],
            if (viewModel.mensagemErro != null) ...[
              const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MeusRemediosView.comProviders(viewModel),
                ),
              ),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Meus remédios'),
            ),
          ],
        ),
      ),
    );
  }
}

// Titulo e "2 de 3 tomados" com a barra de progresso. O leitor de tela le tudo
// numa frase so.
class _Resumo extends StatelessWidget {
  final MedicacaoViewModel viewModel;
  final bool mostrarProgresso;

  const _Resumo({required this.viewModel, required this.mostrarProgresso});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final texto = '${viewModel.tomadas} de ${viewModel.total} tomados';

    return Semantics(
      container: true,
      label: mostrarProgresso
          ? 'Medicações: ${viewModel.tomadas} de ${viewModel.total} doses '
              'tomadas.'
          : 'Medicações',
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
                    Icons.medication_rounded,
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
                        'Medicações',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (mostrarProgresso)
                        Text(
                          texto,
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
            if (mostrarProgresso) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: viewModel.progresso,
                  minHeight: 16,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  color: viewModel.todasTomadas
                      ? AppCores.sucesso
                      : colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Uma dose: a linha inteira e o botao (72dp ou mais), com a caixa de selecao
// grande a esquerda como no mockup da Figura 14. Tomada fica com fundo e borda
// verdes, a caixa marcada e o texto "Tomado as 08:10".
class _LinhaDeDose extends StatelessWidget {
  final DosePlanejada dose;
  // Quando o paciente marcou; null = ainda nao tomada.
  final DateTime? tomadaEm;
  final VoidCallback? aoTocar;

  const _LinhaDeDose({
    required this.dose,
    required this.tomadaEm,
    required this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tomada = tomadaEm != null;
    final cor = tomada ? AppCores.sucesso : colorScheme.onSurfaceVariant;
    final corTexto =
        tomada ? AppCores.onSucessoContainer : colorScheme.onSurface;
    final status = tomada
        ? 'Tomado às ${formatarHora(tomadaEm!)}'
        : 'Ainda não tomado';

    return Semantics(
      button: true,
      enabled: aoTocar != null,
      label: '${dose.descricao}, às ${dose.horario}, '
          '${tomada ? 'tomado' : 'ainda não tomado'}. '
          '${tomada ? 'Toque para desmarcar.' : 'Toque para marcar como tomado.'}',
      excludeSemantics: true,
      onTap: aoTocar,
      child: Material(
        color: tomada
            ? AppCores.sucessoContainer
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: tomada ? AppCores.sucesso : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: aoTocar,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    tomada
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 44,
                    color: cor,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dose.descricao,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: corTexto,
                          ),
                        ),
                        Text(
                          dose.horario,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: corTexto,
                          ),
                        ),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: cor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
