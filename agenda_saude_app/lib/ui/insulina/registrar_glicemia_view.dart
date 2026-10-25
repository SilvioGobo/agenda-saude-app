import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/momentos_glicemia.dart';
import '../../core/theme/app_cores.dart';
import '../../data/repositories/dados_repository.dart';
import '../../domain/models/paciente.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/botao_selecionavel.dart';
import '../shared/titulo_tela.dart';
import 'registrar_glicemia_viewmodel.dart';

// Tela de anotacao de um momento do checklist "Glicemia e Insulina" (RF008).
// Pensada para idosos (NF004): perguntas numeradas em caixa alta, uma por
// vez na ordem em que a pessoa faz as coisas; campos grandes com borda bem
// visivel, que ficam claramente vazios ate a pessoa digitar (o exemplo fica
// fora do campo); respostas em botoes grandes; erros em caixa alta com icone.
// Fecha devolvendo true quando o registro foi salvo.
class RegistrarGlicemiaView extends StatefulWidget {
  const RegistrarGlicemiaView({super.key});

  static Route<bool> rota({
    required Paciente paciente,
    required MomentoGlicemia momento,
    DadosMedicosRepository? dadosRepository,
    DateTime Function()? agora,
  }) {
    return MaterialPageRoute<bool>(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => RegistrarGlicemiaViewModel(
          paciente: paciente,
          momento: momento,
          dadosRepository: dadosRepository,
          agora: agora,
        ),
        child: const RegistrarGlicemiaView(),
      ),
    );
  }

  @override
  State<RegistrarGlicemiaView> createState() => _RegistrarGlicemiaViewState();
}

class _RegistrarGlicemiaViewState extends State<RegistrarGlicemiaView> {
  final _glicemiaController = TextEditingController();
  final _doseController = TextEditingController();

  @override
  void dispose() {
    _glicemiaController.dispose();
    _doseController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    final salvou = await context.read<RegistrarGlicemiaViewModel>().salvar(
          glicemia: _glicemiaController.text,
          dose: _doseController.text,
        );
    if (!mounted || !salvou) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RegistrarGlicemiaViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    // As perguntas visiveis sao numeradas na ordem em que aparecem.
    var numero = 0;
    String pergunta(String texto) => '${++numero}. $texto';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: BotaoBarraSuperior.largura,
        leading: BotaoBarraSuperior.voltar(
          aoTocar: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            TituloTela(
              viewModel.momento.rotulo,
              subtitulo: viewModel.pedeGlicemia
                  ? 'Responda e toque em SALVAR.'
                  : 'Digite a dose de insulina lenta e toque em SALVAR.',
            ),
            const SizedBox(height: 32),
            if (viewModel.pedeGlicemia) ...[
              _Pergunta(pergunta('QUAL FOI A SUA GLICEMIA?')),
              const _Explicacao(
                'O número que apareceu no aparelho de medir glicemia.',
              ),
              const SizedBox(height: 12),
              _CampoNumerico(
                controller: _glicemiaController,
                rotuloParaLeitor: 'Glicemia em miligramas por decilitro',
                unidade: 'mg/dL',
                exemplo: 'EXEMPLO: 110',
                erro: viewModel.erroGlicemia,
                permiteDecimal: false,
              ),
              const SizedBox(height: 32),
            ],
            if (viewModel.perguntaSeAplicouInsulina) ...[
              _Pergunta(pergunta('VOCÊ APLICOU INSULINA AGORA?')),
              const SizedBox(height: 4),
              _ParDeOpcoes(
                opcoes: const ['SIM', 'NÃO'],
                selecionada: switch (viewModel.aplicouInsulina) {
                  true => 'SIM',
                  false => 'NÃO',
                  null => null,
                },
                aoEscolher: (opcao) =>
                    viewModel.responderAplicouInsulina(opcao == 'SIM'),
              ),
              if (viewModel.erroInsulina != null) ...[
                const SizedBox(height: 8),
                _TextoErro(viewModel.erroInsulina!),
              ],
              const SizedBox(height: 32),
            ],
            if (viewModel.mostrarCamposInsulina) ...[
              if (viewModel.escolheTipoInsulina) ...[
                _Pergunta(pergunta('QUAL INSULINA?')),
                const SizedBox(height: 4),
                _ParDeOpcoes(
                  opcoes: [
                    for (final tipo in TipoInsulina.todos) tipo.toUpperCase(),
                  ],
                  selecionada: viewModel.tipoInsulina.toUpperCase(),
                  aoEscolher: (opcao) => viewModel.selecionarTipoInsulina(
                    TipoInsulina.todos
                        .firstWhere((tipo) => tipo.toUpperCase() == opcao),
                  ),
                ),
                const SizedBox(height: 32),
              ],
              _Pergunta(pergunta('QUANTAS UNIDADES?')),
              const SizedBox(height: 12),
              _CampoNumerico(
                controller: _doseController,
                rotuloParaLeitor: 'Unidades de insulina',
                unidade: 'UNIDADES',
                exemplo: 'EXEMPLO: 10',
                erro: viewModel.erroDose,
                permiteDecimal: true,
              ),
              const SizedBox(height: 32),
            ],
            if (viewModel.mensagemErro != null) ...[
              _TextoErro(viewModel.mensagemErro!),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed: viewModel.salvando ? null : _salvar,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(72),
                textStyle: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
                iconSize: 32,
              ),
              icon: viewModel.salvando
                  ? SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('SALVAR'),
            ),
          ],
        ),
      ),
    );
  }
}

// Pergunta numerada em caixa alta (20, negrito), marcada como cabecalho para
// o leitor de tela.
class _Pergunta extends StatelessWidget {
  final String texto;

  const _Pergunta(this.texto);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

// Frase curta que explica a pergunta logo abaixo dela.
class _Explicacao extends StatelessWidget {
  final String texto;

  const _Explicacao(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: TextStyle(
        fontSize: 18,
        height: 1.35,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// Campo numerico grande. Vazio, mostra so "Toque aqui" em letra fina; o
// numero digitado aparece grande e em negrito, entao nao da para confundir
// campo vazio com campo preenchido. Borda de 2dp sempre visivel (3dp e cor
// principal quando selecionado), unidade a direita e o exemplo embaixo.
class _CampoNumerico extends StatelessWidget {
  final TextEditingController controller;
  final String rotuloParaLeitor;
  final String unidade;
  final String exemplo;
  final String? erro;
  final bool permiteDecimal;

  const _CampoNumerico({
    required this.controller,
    required this.rotuloParaLeitor,
    required this.unidade,
    required this.exemplo,
    required this.erro,
    required this.permiteDecimal,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    OutlineInputBorder borda(Color cor, double largura) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cor, width: largura),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: rotuloParaLeitor,
          textField: true,
          child: TextField(
            controller: controller,
            keyboardType:
                TextInputType.numberWithOptions(decimal: permiteDecimal),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                permiteDecimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
              ),
              LengthLimitingTextInputFormatter(5),
            ],
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: colorScheme.surface,
              hintText: 'Toque aqui',
              hintStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.normal,
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
              // Como icone (e nao suffixText) a unidade aparece sempre,
              // mesmo com o campo vazio e sem foco.
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 20, left: 8),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    unidade,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 48, minHeight: 48),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              enabledBorder: borda(colorScheme.outline, 2),
              focusedBorder: borda(colorScheme.primary, 3),
              errorBorder: borda(AppCores.perigo, 3),
              focusedErrorBorder: borda(AppCores.perigo, 3),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (erro != null)
          _TextoErro(erro!)
        else
          ExcludeSemantics(
            child: Text(
              exemplo,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

// Dois botoes grandes lado a lado (64dp), com check no escolhido.
class _ParDeOpcoes extends StatelessWidget {
  final List<String> opcoes;
  final String? selecionada;
  final ValueChanged<String> aoEscolher;

  const _ParDeOpcoes({
    required this.opcoes,
    required this.selecionada,
    required this.aoEscolher,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final opcao in opcoes) ...[
          if (opcao != opcoes.first) const SizedBox(width: 12),
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
              child: BotaoSelecionavel(
                rotulo: opcao,
                selecionado: selecionada == opcao,
                aoTocar: () => aoEscolher(opcao),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// Erro em caixa alta, com icone, anunciado pelo leitor de tela.
class _TextoErro extends StatelessWidget {
  final String texto;

  const _TextoErro(this.texto);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: texto,
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_rounded, color: AppCores.perigo, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                texto.toUpperCase(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppCores.perigo,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
