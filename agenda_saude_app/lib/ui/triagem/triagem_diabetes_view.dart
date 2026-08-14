import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/botao_selecionavel.dart';
import '../shared/perguntas_aninhadas.dart';
import '../shared/progresso_etapa.dart';
import '../shared/rotulo_pergunta.dart';
import '../shared/seletor_sim_nao.dart';
import 'triagem_cardiopatia_view.dart';
import 'triagem_viewmodel.dart';

// Etapa 2 de 4 do assistente de triagem: diabetes.
class TriagemDiabetesView extends StatefulWidget {
  const TriagemDiabetesView({super.key});

  @override
  State<TriagemDiabetesView> createState() => _TriagemDiabetesViewState();
}

class _TriagemDiabetesViewState extends State<TriagemDiabetesView> {
  final _tipoInsulinaController = TextEditingController();

  @override
  void dispose() {
    _tipoInsulinaController.dispose();
    super.dispose();
  }

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
              const RotuloPergunta('Você possui diabetes?'),
              SeletorSimNao(
                valor: viewModel.possuiDiabetes,
                aoResponder: viewModel.responderDiabetes,
              ),
              if (viewModel.possuiDiabetes == true) ...[
                const SizedBox(height: 16),
                PerguntasAninhadas(
                  children: [
                    const RotuloPergunta('Qual tipo?', pequeno: true),
                    Row(
                      children: [
                        Expanded(
                          child: BotaoSelecionavel(
                            rotulo: 'Tipo 1',
                            pequeno: true,
                            selecionado: viewModel.tipoDiabetes == 'Tipo 1',
                            aoTocar: () =>
                                viewModel.selecionarTipoDiabetes('Tipo 1'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BotaoSelecionavel(
                            rotulo: 'Tipo 2',
                            pequeno: true,
                            selecionado: viewModel.tipoDiabetes == 'Tipo 2',
                            aoTocar: () =>
                                viewModel.selecionarTipoDiabetes('Tipo 2'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const RotuloPergunta('Usa insulina?', pequeno: true),
                    SeletorSimNao(
                      valor: viewModel.usaInsulina,
                      aoResponder: viewModel.responderUsaInsulina,
                      pequeno: true,
                    ),
                    if (viewModel.usaInsulina == true) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _tipoInsulinaController,
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Tipo de insulina (opcional)',
                        ),
                        onChanged: viewModel.definirTipoInsulina,
                      ),
                    ],
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
