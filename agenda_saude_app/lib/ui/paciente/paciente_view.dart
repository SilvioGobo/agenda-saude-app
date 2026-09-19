import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/paciente.dart';
import '../shared/card_status.dart';
import '../shared/tela_provisoria.dart';
import '../sincronizacao/card_smartwatch.dart';
import '../sincronizacao/sincronizacao_bpm_viewmodel.dart';
import 'paciente_viewmodel.dart';

// Painel principal do paciente (RF05, Figura 13 do TCC): saudacao, destaque
// de BPM em tempo real e atalhos para a rotina diaria e para o acompanhante.
class PacienteView extends StatelessWidget {
  const PacienteView({super.key});

  // Monta o painel com os dois ViewModels de que ele depende: o do painel em
  // si e o da sincronizacao com o smartwatch (que ja comeca a ler ao abrir).
  static Widget comProviders(Paciente paciente) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PacienteViewModel(paciente: paciente),
        ),
        ChangeNotifierProvider(
          create: (_) => SincronizacaoBpmViewModel(paciente: paciente)..iniciar(),
        ),
      ],
      child: const PacienteView(),
    );
  }

  void _abrirMinhaRotina(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TelaProvisoria(
          titulo: 'Minha Rotina',
          mensagem:
              'O checklist de rotina diária (água, sono, exercícios e '
              'medicação) ainda está em desenvolvimento.',
        ),
      ),
    );
  }

  void _falarComAcompanhante(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TelaProvisoria(
          titulo: 'Falar com Acompanhante',
          mensagem: 'O contato direto com o acompanhante ainda está em '
              'desenvolvimento.',
        ),
      ),
    );
  }

  ({String rotulo, IconData icone, Color cor}) _infoStatus(
    BuildContext context,
    StatusCardiaco status,
  ) {
    switch (status) {
      case StatusCardiaco.estavel:
        return (
          rotulo: 'ESTÁVEL',
          icone: Icons.check_circle_rounded,
          cor: Colors.green,
        );
      case StatusCardiaco.atencao:
        return (
          rotulo: 'ATENÇÃO',
          icone: Icons.warning_rounded,
          cor: Colors.red,
        );
      case StatusCardiaco.semLeitura:
        return (
          rotulo: 'AGUARDANDO LEITURA',
          icone: Icons.hourglass_empty_rounded,
          cor: Theme.of(context).colorScheme.outline,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PacienteViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final batimento = viewModel.ultimoBatimento;
    final status = _infoStatus(context, viewModel.statusCardiaco);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Início'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Olá, ${viewModel.primeiroNome}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        size: 40,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      if (batimento != null)
                        RichText(
                          text: TextSpan(
                            style: TextStyle(color: colorScheme.onSurface),
                            children: [
                              TextSpan(
                                text: '${batimento.bpm}',
                                style: const TextStyle(
                                  fontSize: 56,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(
                                text: ' BPM',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          'Sem leitura recente',
                          style: TextStyle(
                            fontSize: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CardStatus(
                rotulo: status.rotulo,
                icone: status.icone,
                cor: status.cor,
              ),
              const SizedBox(height: 16),
              const CardSmartwatch(),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => _abrirMinhaRotina(context),
                icon: const Icon(Icons.checklist_rounded),
                label: const Text('Minha Rotina'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _falarComAcompanhante(context),
                icon: const Icon(Icons.call_rounded),
                label: const Text('Falar com Acompanhante'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
