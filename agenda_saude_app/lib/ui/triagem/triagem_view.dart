import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../shared/progresso_etapa.dart';
import 'perguntas_triagem.dart';
import 'triagem_diabetes_view.dart';
import 'triagem_viewmodel.dart';

// Etapa 1 de 4 do assistente de triagem: dados fisicos/demograficos.
class TriagemView extends StatelessWidget {
  const TriagemView({super.key});

  void _proximo(BuildContext context) {
    final viewModel = context.read<TriagemViewModel>();
    if (!viewModel.validarEAvancarSobreVoce()) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: viewModel,
          child: const TriagemDiabetesView(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TriagemViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sobre Você'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ProgressoEtapa(etapaAtual: 1, totalEtapas: 4),
              const SizedBox(height: 20),
              const Text(
                'Vamos começar com alguns dados básicos. Eles ajudam a '
                'personalizar suas metas de saúde no app.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 28),
              const PerguntasSobreVoce(),
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
