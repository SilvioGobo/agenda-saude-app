import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../shared/card_status.dart';
import 'formato_sono.dart';
import 'registrar_sono_view.dart';
import 'sono_viewmodel.dart';

// Cartao "Sono" do checklist de rotina (RF 03.2): como foi a noite de hoje -
// horas dormidas e qualidade - e o botao para registrar ou corrigir. Registrar
// tem duas perguntas, entao abre a tela propria RegistrarSonoView (a Rotina e
// um resumo do dia, com um cartao compacto por atividade). Sem registro, o
// cartao lembra de registrar ao acordar e diz a meta; com registro, diz se a
// meta foi atingida em texto e icone, nunca so na cor (NF004).
class CardSono extends StatelessWidget {
  const CardSono({super.key});

  Future<void> _abrirRegistro(
    BuildContext context,
    SonoViewModel viewModel,
  ) async {
    final salvou = await Navigator.of(context).push(
      RegistrarSonoView.rota(viewModel.novoRegistro()),
    );
    if (!context.mounted || salvou != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sono registrado.', style: TextStyle(fontSize: 18)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SonoViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final pronto = !viewModel.carregando && !viewModel.erroDeLeitura;
    final registrou = viewModel.registrou;

    const botao = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
    final aoTocar = pronto ? () => _abrirRegistro(context, viewModel) : null;

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
                  'Não foi possível carregar o seu sono de hoje. Volte e abra '
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
              Text(
                registrou
                    ? 'Meta: ${formatarMetaDeSono(viewModel.metaMinHoras, viewModel.metaMaxHoras)} por noite.'
                    : 'Registre ao acordar quantas horas dormiu e como foi o '
                        'sono. A meta é de '
                        '${formatarMetaDeSono(viewModel.metaMinHoras, viewModel.metaMaxHoras)} '
                        'por noite.',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.35,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (registrou) ...[
                const SizedBox(height: 16),
                if (viewModel.metaAtingida)
                  const CardStatus(
                    rotulo: 'META DE SONO ATINGIDA',
                    icone: Icons.check_circle_rounded,
                    cor: AppCores.sucesso,
                  )
                else
                  const CardStatus(
                    rotulo: 'ABAIXO DA META DE SONO',
                    icone: Icons.info_rounded,
                    cor: AppCores.aviso,
                  ),
              ],
            ],
            const SizedBox(height: 16),
            if (registrou)
              OutlinedButton.icon(
                onPressed: aoTocar,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  textStyle: botao,
                  iconSize: 28,
                ),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Corrigir o sono de hoje'),
              )
            else
              FilledButton.icon(
                onPressed: aoTocar,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  textStyle: botao,
                  iconSize: 28,
                ),
                icon: const Icon(Icons.bedtime_rounded),
                label: const Text('Registrar sono'),
              ),
          ],
        ),
      ),
    );
  }
}

// Icone, titulo e o que foi registrado hoje ("7 h 30 min" e "Qualidade: Bom
// (4 de 5)"). O leitor de tela le tudo numa frase so.
class _Resumo extends StatelessWidget {
  final SonoViewModel viewModel;
  final bool mostrarResumo;

  const _Resumo({required this.viewModel, required this.mostrarResumo});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final registro = viewModel.registroDeHoje;

    final String falado;
    if (!mostrarResumo) {
      falado = 'Sono';
    } else if (registro == null) {
      falado = 'Sono: ainda não registrado hoje.';
    } else {
      falado = 'Sono: dormiu ${falarHorasDeSono(registro.horasTotais)}. '
          'Qualidade: ${descreverQualidadeDoSono(registro.qualidade)}.';
    }

    return Semantics(
      container: true,
      label: falado,
      child: ExcludeSemantics(
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bedtime_rounded,
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
                    'Sono',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (mostrarResumo)
                    Text(
                      registro == null
                          ? 'Ainda não registrado'
                          : formatarHorasDeSono(registro.horasTotais),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (mostrarResumo && registro != null)
                    Text(
                      'Qualidade: ${descreverQualidadeDoSono(registro.qualidade)}',
                      style: TextStyle(
                        fontSize: 18,
                        color: colorScheme.onSurfaceVariant,
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
