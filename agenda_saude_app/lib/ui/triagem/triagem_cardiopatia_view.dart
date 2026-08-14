import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/perguntas_aninhadas.dart';
import '../shared/progresso_etapa.dart';
import '../shared/rotulo_pergunta.dart';
import '../shared/seletor_sim_nao.dart';
import 'triagem_outras_informacoes_view.dart';
import 'triagem_viewmodel.dart';

// Etapa 3 de 4 do assistente de triagem: cardiopatia.
class TriagemCardiopatiaView extends StatefulWidget {
  const TriagemCardiopatiaView({super.key});

  @override
  State<TriagemCardiopatiaView> createState() =>
      _TriagemCardiopatiaViewState();
}

class _TriagemCardiopatiaViewState extends State<TriagemCardiopatiaView> {
  final _tipoCardiopatiaController = TextEditingController();

  @override
  void dispose() {
    _tipoCardiopatiaController.dispose();
    super.dispose();
  }

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
              const RotuloPergunta('Você possui alguma cardiopatia?'),
              SeletorSimNao(
                valor: viewModel.possuiCardiopatia,
                aoResponder: viewModel.responderCardiopatia,
              ),
              if (viewModel.possuiCardiopatia == true) ...[
                const SizedBox(height: 16),
                PerguntasAninhadas(
                  children: [
                    TextField(
                      controller: _tipoCardiopatiaController,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Qual? (opcional)',
                      ),
                      onChanged: viewModel.definirTipoCardiopatia,
                    ),
                    const SizedBox(height: 20),
                    const RotuloPergunta('Usa marcapasso?', pequeno: true),
                    SeletorSimNao(
                      valor: viewModel.usaMarcapasso,
                      aoResponder: viewModel.responderUsaMarcapasso,
                      pequeno: true,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 28),
              if (viewModel.mensagemErro != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    viewModel.mensagemErro!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
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
