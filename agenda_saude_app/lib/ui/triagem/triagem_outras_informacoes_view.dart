import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/progresso_etapa.dart';
import '../shared/rotulo_pergunta.dart';
import '../shared/tela_provisoria.dart';
import 'triagem_viewmodel.dart';

// Etapa 4 de 4 (final) do assistente de triagem: informacoes opcionais.
class TriagemOutrasInformacoesView extends StatefulWidget {
  const TriagemOutrasInformacoesView({super.key});

  @override
  State<TriagemOutrasInformacoesView> createState() =>
      _TriagemOutrasInformacoesViewState();
}

class _TriagemOutrasInformacoesViewState
    extends State<TriagemOutrasInformacoesView> {
  final _alergiasController = TextEditingController();
  final _medicamentosController = TextEditingController();

  @override
  void dispose() {
    _alergiasController.dispose();
    _medicamentosController.dispose();
    super.dispose();
  }

  Future<void> _concluir(BuildContext context) async {
    final viewModel = context.read<TriagemViewModel>();
    final sucesso = await viewModel.concluirTriagem();

    if (!context.mounted || !sucesso) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const TelaProvisoria(
          titulo: 'Início',
          mensagem: 'Triagem concluída! Este será o painel do Paciente.',
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TriagemViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Outras Informações')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ProgressoEtapa(etapaAtual: 4, totalEtapas: 4),
              const SizedBox(height: 20),
              const Text(
                'Últimos detalhes — tudo aqui é opcional, mas ajuda o seu '
                'acompanhante em caso de emergência.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 28),
              const RotuloPergunta('Alergias e restrições alimentares'),
              TextField(
                controller: _alergiasController,
                maxLines: 2,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Ex: alergia a dipirona',
                ),
                onChanged: viewModel.definirAlergias,
              ),
              const SizedBox(height: 20),
              const RotuloPergunta('Medicamentos em uso contínuo'),
              TextField(
                controller: _medicamentosController,
                maxLines: 2,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Ex: Losartana 50mg',
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
              ElevatedButton(
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
                    : const Text('Concluir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
