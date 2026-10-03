import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../../domain/models/acompanhante.dart';
import '../../domain/models/paciente.dart';
import '../auth/botao_sair.dart';
import 'acompanhante_viewmodel.dart';
import 'card_paciente.dart';
import 'vincular_paciente_view.dart';

// Painel do acompanhante (RF05, Figura 15 do TCC): lista em cards dos
// pacientes vinculados e atalho para vincular um novo paciente (RF05.4).
class AcompanhanteView extends StatelessWidget {
  const AcompanhanteView({super.key});

  static Widget comProviders(Acompanhante acompanhante) {
    return ChangeNotifierProvider(
      create: (_) => AcompanhanteViewModel(acompanhante: acompanhante)
        ..carregarPacientes(),
      child: const AcompanhanteView(),
    );
  }

  Future<void> _vincularPaciente(BuildContext context) async {
    final viewModel = context.read<AcompanhanteViewModel>();
    final vinculou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VincularPacienteView.comProviders(viewModel.acompanhante),
      ),
    );

    if (!context.mounted || vinculou != true) return;
    await viewModel.carregarPacientes();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Paciente vinculado com sucesso.')),
    );
  }

  Future<void> _confirmarDesvinculo(
    BuildContext context,
    Paciente paciente,
  ) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desvincular paciente?'),
        content: Text(
          'Você deixará de acompanhar os dados de ${paciente.nome}. '
          'Para voltar a acompanhar, será preciso digitar o código novamente.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );

    if (!context.mounted || confirmou != true) return;
    final sucesso =
        await context.read<AcompanhanteViewModel>().desvincular(paciente);
    if (!context.mounted || !sucesso) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${paciente.nome} foi desvinculado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AcompanhanteViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final pacientes = viewModel.pacientesVinculados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoramento'),
        automaticallyImplyLeading: false,
        actions: const [BotaoSair()],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: viewModel.carregarPacientes,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Olá, ${viewModel.primeiroNome}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                pacientes.isEmpty
                    ? 'Você ainda não acompanha nenhum paciente.'
                    : 'Você acompanha ${pacientes.length} '
                        '${pacientes.length == 1 ? 'paciente' : 'pacientes'}.',
                style: TextStyle(
                  fontSize: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              if (viewModel.mensagemErro != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    viewModel.mensagemErro!,
                    style: const TextStyle(color: AppCores.perigo, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (viewModel.carregando && pacientes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (pacientes.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 48,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Peça ao paciente o código de vínculo (no app '
                          'dele, em Menu > Meu código de vínculo) e toque em '
                          '"Vincular paciente".',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final paciente in pacientes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CardPaciente(
                      paciente: paciente,
                      onDesvincular: viewModel.carregando
                          ? null
                          : () => _confirmarDesvinculo(context, paciente),
                    ),
                  ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: viewModel.carregando
                    ? null
                    : () => _vincularPaciente(context),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Vincular paciente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
