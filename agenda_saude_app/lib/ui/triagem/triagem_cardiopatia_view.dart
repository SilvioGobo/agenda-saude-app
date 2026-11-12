import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../shared/progresso_etapa.dart';
import 'perguntas_triagem.dart';
import 'triagem_outras_informacoes_view.dart';
import 'triagem_viewmodel.dart';

// Etapa 3 de 4 do assistente de triagem: cardiopatia.
class TriagemCardiopatiaView extends StatelessWidget {
  const TriagemCardiopatiaView({super.key});

  void _proximo(BuildContext context) {
    final viewModel = context.read<TriagemViewModel>();
    if (!viewModel.validarEAvancarCardiopatia()) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: viewModel,
          child: const TriagemOutrasInformacoesView(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TriagemViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Cardiopatia')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ProgressoEtapa(etapaAtual: 3, totalEtapas: 4),
              const SizedBox(height: 20),
              const Text(
                'Isso nos ajuda a priorizar os alertas do seu coração.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 28),
              const PerguntasCardiopatia(),
              const SizedBox(height: 28),
              if (viewModel.mensagemErro != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    viewModel.mensagemErro!,
                    style: const TextStyle(color: AppCores.perigo, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ElevatedButton(
                onPressed: () => _proximo(context),
                child: const Text('Próximo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
