import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../shared/progresso_etapa.dart';
import 'perguntas_triagem.dart';
import 'triagem_cardiopatia_view.dart';
import 'triagem_viewmodel.dart';

// Etapa 2 de 4 do assistente de triagem: diabetes.
class TriagemDiabetesView extends StatelessWidget {
  const TriagemDiabetesView({super.key});

  void _proximo(BuildContext context) {
    final viewModel = context.read<TriagemViewModel>();
    if (!viewModel.validarEAvancarDiabetes()) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: viewModel,
          child: const TriagemCardiopatiaView(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TriagemViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Diabetes')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ProgressoEtapa(etapaAtual: 2, totalEtapas: 4),
              const SizedBox(height: 20),
              const Text(
                'Queremos adaptar o app caso você conviva com diabetes.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 28),
              const PerguntasDiabetes(),
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
