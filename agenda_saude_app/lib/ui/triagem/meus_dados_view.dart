import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../../domain/alimentos/catalogo_alimentos.dart';
import '../../domain/medicacao/catalogo_remedios.dart';
import '../../domain/models/paciente.dart';
import '../shared/barra_acoes.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/titulo_tela.dart';
import 'perguntas_triagem.dart';
import 'triagem_viewmodel.dart';

// "Meus dados", aberta pelo perfil do menu lateral: todas as respostas da
// triagem numa tela so (as mesmas perguntas do assistente do primeiro
// acesso), ja preenchidas, para o paciente mudar o que precisar. Salvar grava
// so os campos da triagem e calcula as metas de novo; o resto do paciente
// (refeicoes, remedios, limites de alerta) fica como esta. Salvar e Cancelar
// ficam fixos na base, como nas telas de Personalizar rotina.
class MeusDadosView extends StatelessWidget {
  // Recebe o paciente com os dados novos, depois de gravado.
  final ValueChanged<Paciente>? aoSalvar;
  // Os catalogos das buscas; null = os do app (os testes passam outros).
  final Future<CatalogoAlimentos> Function()? carregarAlimentos;
  final Future<CatalogoRemedios> Function()? carregarRemedios;

  const MeusDadosView({
    super.key,
    this.aoSalvar,
    this.carregarAlimentos,
    this.carregarRemedios,
  });

  static Widget comProviders(
    Paciente paciente, {
    ValueChanged<Paciente>? aoSalvar,
  }) {
    return ChangeNotifierProvider(
      create: (_) => TriagemViewModel(paciente: paciente, edicao: true),
      child: MeusDadosView(aoSalvar: aoSalvar),
    );
  }

  Future<void> _salvar(BuildContext context) async {
    final viewModel = context.read<TriagemViewModel>();
    final salvou = await viewModel.salvarAlteracoes();
    final atualizado = viewModel.pacienteAtualizado;
    if (!context.mounted || !salvou || atualizado == null) return;
    aoSalvar?.call(atualizado);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Seus dados foram salvos.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TriagemViewModel>();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: BotaoBarraSuperior.largura,
        leading: BotaoBarraSuperior.voltar(
          aoTocar: () => Navigator.of(context).pop(),
        ),
      ),
      bottomNavigationBar: BarraAcoes(
        children: [
          if (viewModel.mensagemErro != null)
            Semantics(
              liveRegion: true,
              child: Text(
                viewModel.mensagemErro!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppCores.perigo,
                ),
              ),
            ),
          FilledButton.icon(
            onPressed: viewModel.carregando ? null : () => _salvar(context),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Salvar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
      // Uma coluna so (e nao uma lista preguicosa): os campos de texto de cima
      // nao se desmontam ao rolar ate as alergias.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TituloTela(
                'Meus dados',
                subtitulo:
                    'As respostas da sua triagem. Mude o que precisar e '
                    'toque em Salvar: as metas são calculadas de novo com os '
                    'dados novos.',
              ),
              const SizedBox(height: 24),
              const _Secao(titulo: 'Sobre você', child: PerguntasSobreVoce()),
              const _Secao(titulo: 'Diabetes', child: PerguntasDiabetes()),
              const _Secao(titulo: 'Coração', child: PerguntasCardiopatia()),
              _Secao(
                titulo: 'Alergias',
                child: PerguntasAlergias(
                  carregarAlimentos: carregarAlimentos,
                  carregarRemedios: carregarRemedios,
                ),
              ),
              _Secao(
                titulo: 'Remédios em uso',
                child: PerguntaMedicamentosEmUso(
                  carregarRemedios: carregarRemedios,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Um bloco da tela: o titulo (cabecalho para o leitor de tela) e as perguntas
// num cartao.
class _Secao extends StatelessWidget {
  final String titulo;
  final Widget child;

  const _Secao({required this.titulo, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  titulo.toUpperCase(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
