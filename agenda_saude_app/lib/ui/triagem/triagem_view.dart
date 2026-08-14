import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/botao_selecionavel.dart';
import '../shared/progresso_etapa.dart';
import '../shared/rotulo_pergunta.dart';
import 'triagem_diabetes_view.dart';
import 'triagem_viewmodel.dart';

// Etapa 1 de 4 do assistente de triagem: dados fisicos/demograficos.
class TriagemView extends StatefulWidget {
  const TriagemView({super.key});

  @override
  State<TriagemView> createState() => _TriagemViewState();
}

class _TriagemViewState extends State<TriagemView> {
  final _alturaController = TextEditingController();
  final _pesoController = TextEditingController();

  @override
  void dispose() {
    _alturaController.dispose();
    _pesoController.dispose();
    super.dispose();
  }

  Future<void> _selecionarDataNascimento(
    BuildContext context,
    TriagemViewModel viewModel,
  ) async {
    final agora = DateTime.now();
    final dataSelecionada = await showDatePicker(
      context: context,
      initialDate:
          viewModel.dataNascimento ?? DateTime(agora.year - 65, agora.month, agora.day),
      firstDate: DateTime(agora.year - 120),
      lastDate: agora,
      helpText: 'Data de nascimento',
    );
    if (dataSelecionada != null) {
      viewModel.definirDataNascimento(dataSelecionada);
    }
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year}';
  }

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
              const RotuloPergunta('Data de nascimento'),
              OutlinedButton(
                onPressed: () => _selecionarDataNascimento(context, viewModel),
                child: Text(
                  viewModel.dataNascimento != null
                      ? _formatarData(viewModel.dataNascimento!)
                      : 'Selecionar data',
                ),
              ),
              const SizedBox(height: 20),
              const RotuloPergunta('Sexo biológico'),
              Row(
                children: [
                  Expanded(
                    child: BotaoSelecionavel(
                      rotulo: 'Masculino',
                      selecionado: viewModel.sexoBiologico == 'Masculino',
                      aoTocar: () =>
                          viewModel.selecionarSexoBiologico('Masculino'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BotaoSelecionavel(
                      rotulo: 'Feminino',
                      selecionado: viewModel.sexoBiologico == 'Feminino',
                      aoTocar: () =>
                          viewModel.selecionarSexoBiologico('Feminino'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _alturaController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 18),
                      decoration:
                          const InputDecoration(labelText: 'Altura (cm)'),
                      onChanged: viewModel.definirAltura,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _pesoController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(labelText: 'Peso (kg)'),
                      onChanged: viewModel.definirPeso,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const RotuloPergunta('Nível de atividade física habitual'),
              Row(
                children: [
                  Expanded(
                    child: BotaoSelecionavel(
                      rotulo: 'Sedentário',
                      selecionado:
                          viewModel.nivelAtividadeFisica == 'Sedentário',
                      aoTocar: () => viewModel
                          .selecionarNivelAtividadeFisica('Sedentário'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BotaoSelecionavel(
                      rotulo: 'Leve',
                      selecionado: viewModel.nivelAtividadeFisica == 'Leve',
                      aoTocar: () =>
                          viewModel.selecionarNivelAtividadeFisica('Leve'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: BotaoSelecionavel(
                      rotulo: 'Moderado',
                      selecionado:
                          viewModel.nivelAtividadeFisica == 'Moderado',
                      aoTocar: () => viewModel
                          .selecionarNivelAtividadeFisica('Moderado'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BotaoSelecionavel(
                      rotulo: 'Intenso',
                      selecionado: viewModel.nivelAtividadeFisica == 'Intenso',
                      aoTocar: () =>
                          viewModel.selecionarNivelAtividadeFisica('Intenso'),
                    ),
                  ),
                ],
              ),
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
