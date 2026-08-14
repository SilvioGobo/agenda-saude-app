import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/botao_selecionavel.dart';
import '../shared/seletor_sim_nao.dart';
import '../shared/tela_provisoria.dart';
import 'triagem_viewmodel.dart';

class TriagemView extends StatefulWidget {
  const TriagemView({super.key});

  @override
  State<TriagemView> createState() => _TriagemViewState();
}

class _TriagemViewState extends State<TriagemView> {
  final _tipoInsulinaController = TextEditingController();
  final _tipoCardiopatiaController = TextEditingController();
  final _alturaController = TextEditingController();
  final _pesoController = TextEditingController();
  final _alergiasController = TextEditingController();
  final _medicamentosController = TextEditingController();

  @override
  void dispose() {
    _tipoInsulinaController.dispose();
    _tipoCardiopatiaController.dispose();
    _alturaController.dispose();
    _pesoController.dispose();
    _alergiasController.dispose();
    _medicamentosController.dispose();
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

  Future<void> _concluir(BuildContext context) async {
    final viewModel = context.read<TriagemViewModel>();
    final sucesso = await viewModel.concluirTriagem();

    if (!context.mounted || !sucesso) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const TelaProvisoria(
          titulo: 'Início',
          mensagem: 'Triagem concluída! Este será o painel do Paciente.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TriagemViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sobre sua saúde'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Antes de continuar, precisamos saber um pouco sobre sua saúde.',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              const _TituloSecao('Sobre você'),
              const SizedBox(height: 12),
              const Text(
                'Data de nascimento',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: () => _selecionarDataNascimento(context, viewModel),
                  child: Text(
                    viewModel.dataNascimento != null
                        ? _formatarData(viewModel.dataNascimento!)
                        : 'Selecionar data',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sexo biológico',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
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
                      decoration: const InputDecoration(
                        labelText: 'Altura (cm)',
                        border: OutlineInputBorder(),
                      ),
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
                      decoration: const InputDecoration(
                        labelText: 'Peso (kg)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: viewModel.definirPeso,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Nível de atividade física habitual',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: BotaoSelecionavel(
                      rotulo: 'Sedentário',
                      selecionado: viewModel.nivelAtividadeFisica == 'Sedentário',
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
                      selecionado: viewModel.nivelAtividadeFisica == 'Moderado',
                      aoTocar: () =>
                          viewModel.selecionarNivelAtividadeFisica('Moderado'),
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
              const Divider(),
              const SizedBox(height: 16),
              const _TituloSecao('Diabetes'),
              const SizedBox(height: 12),
              const Text(
                'Você possui diabetes?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SeletorSimNao(
                valor: viewModel.possuiDiabetes,
                aoResponder: viewModel.responderDiabetes,
              ),
              if (viewModel.possuiDiabetes == true) ...[
                const SizedBox(height: 20),
                const Text(
                  'Qual tipo?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: BotaoSelecionavel(
                        rotulo: 'Tipo 1',
                        selecionado: viewModel.tipoDiabetes == 'Tipo 1',
                        aoTocar: () =>
                            viewModel.selecionarTipoDiabetes('Tipo 1'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BotaoSelecionavel(
                        rotulo: 'Tipo 2',
                        selecionado: viewModel.tipoDiabetes == 'Tipo 2',
                        aoTocar: () =>
                            viewModel.selecionarTipoDiabetes('Tipo 2'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Usa insulina?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SeletorSimNao(
                  valor: viewModel.usaInsulina,
                  aoResponder: viewModel.responderUsaInsulina,
                ),
                if (viewModel.usaInsulina == true) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _tipoInsulinaController,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      labelText: 'Tipo de insulina (opcional)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: viewModel.definirTipoInsulina,
                  ),
                ],
              ],
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 16),
              const _TituloSecao('Cardiopatia'),
              const SizedBox(height: 12),
              const Text(
                'Você possui alguma cardiopatia?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SeletorSimNao(
                valor: viewModel.possuiCardiopatia,
                aoResponder: viewModel.responderCardiopatia,
              ),
              if (viewModel.possuiCardiopatia == true) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _tipoCardiopatiaController,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    labelText: 'Qual? (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: viewModel.definirTipoCardiopatia,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Usa marcapasso?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SeletorSimNao(
                  valor: viewModel.usaMarcapasso,
                  aoResponder: viewModel.responderUsaMarcapasso,
                ),
              ],
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 16),
              const _TituloSecao('Outras informações (opcional)'),
              const SizedBox(height: 12),
              TextField(
                controller: _alergiasController,
                maxLines: 2,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Alergias e restrições alimentares',
                  border: OutlineInputBorder(),
                ),
                onChanged: viewModel.definirAlergias,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _medicamentosController,
                maxLines: 2,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Medicamentos em uso contínuo',
                  border: OutlineInputBorder(),
                ),
                onChanged: viewModel.definirMedicamentosEmUso,
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
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      viewModel.carregando ? null : () => _concluir(context),
                  child: viewModel.carregando
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text('Concluir', style: TextStyle(fontSize: 20)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TituloSecao extends StatelessWidget {
  final String texto;

  const _TituloSecao(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }
}
