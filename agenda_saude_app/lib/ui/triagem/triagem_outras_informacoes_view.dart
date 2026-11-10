import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../../domain/models/paciente.dart';
import '../metas/metas_view.dart';
import '../paciente/paciente_view.dart';
import '../shared/progresso_etapa.dart';
import '../shared/rotulo_pergunta.dart';
import 'triagem_viewmodel.dart';

// Etapa 4 de 4 (final) do assistente de triagem: informacoes opcionais.
class TriagemOutrasInformacoesView extends StatefulWidget {
  // Monta o painel do paciente no fim da triagem. Os testes trocam por uma
  // tela simples: o painel de verdade liga no Firebase e nos sensores.
  final Widget Function(Paciente paciente) construirPainel;

  const TriagemOutrasInformacoesView({
    super.key,
    this.construirPainel = PacienteView.comProviders,
  });

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

    final paciente = viewModel.pacienteAtualizado;
    if (paciente == null) return;

    // Guardados agora, e nao lidos desta tela na hora de ir ao painel: o
    // pushAndRemoveUntil abaixo tira esta tela da arvore, e o "Aceitar e
    // continuar" das metas so roda depois. Com o context dela o
    // Navigator.of falhava ("Null check operator used on a null value") e o
    // paciente nao saia das metas.
    final navegador = Navigator.of(context);
    final construirPainel = widget.construirPainel;

    // Com metas calculadas, o paciente confere (e ajusta, se quiser) antes de
    // ir ao painel. Sem elas, vai direto.
    navegador.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => paciente.metas == null
            ? construirPainel(paciente)
            : MetasView.comProviders(
                paciente,
                aoContinuar: (pacienteComMetas) => _irParaOPainel(
                  navegador,
                  construirPainel(pacienteComMetas),
                ),
              ),
      ),
      (route) => false,
    );
  }

  // Limpa a pilha: o "voltar" do painel nao retorna as metas nem a triagem.
  static void _irParaOPainel(NavigatorState navegador, Widget painel) {
    navegador.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => painel),
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
                    style: const TextStyle(color: AppCores.perigo, fontSize: 16),
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
