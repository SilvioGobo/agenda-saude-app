import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/momentos_glicemia.dart';
import '../../core/theme/app_cores.dart';
import '../../data/repositories/dados_repository.dart';
import '../../domain/models/paciente.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/botao_selecionavel.dart';
import '../shared/rotulo_pergunta.dart';
import '../shared/seletor_sim_nao.dart';
import '../shared/titulo_tela.dart';
import 'registrar_glicemia_viewmodel.dart';

// Tela de registro de um momento do checklist "Glicemia e Insulina" (RF008).
// Campos numericos grandes, com teclado numerico, e o "Aplicou insulina?" em
// botoes Sim/Nao - o mesmo padrao da triagem. Fecha devolvendo true quando o
// registro foi salvo.
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
              viewModel.momento.nome,
              subtitulo: viewModel.pedeGlicemia
                  ? 'Anote o valor que apareceu no seu aparelho de glicemia.'
                  : 'Anote a dose de insulina lenta que você aplicou.',
            ),
            const SizedBox(height: 24),
            if (viewModel.pedeGlicemia) ...[
              const RotuloPergunta('Glicemia (mg/dL)'),
              _CampoNumerico(
                controller: _glicemiaController,
                rotulo: 'Glicemia em mg/dL',
                dica: 'Ex.: 110',
                sufixo: 'mg/dL',
                erro: viewModel.erroGlicemia,
                permiteDecimal: false,
              ),
              const SizedBox(height: 24),
            ],
            if (viewModel.perguntaSeAplicouInsulina) ...[
              const RotuloPergunta('Aplicou insulina agora?'),
              SeletorSimNao(
                valor: viewModel.aplicouInsulina,
                aoResponder: viewModel.responderAplicouInsulina,
              ),
              if (viewModel.erroInsulina != null)
                _TextoErro(viewModel.erroInsulina!),
              const SizedBox(height: 24),
            ],
            if (viewModel.mostrarCamposInsulina) ...[
              if (viewModel.escolheTipoInsulina) ...[
                const RotuloPergunta('Qual insulina?'),
                Row(
                  children: [
                    for (final tipo in TipoInsulina.todos) ...[
                      if (tipo != TipoInsulina.todos.first)
                        const SizedBox(width: 12),
                      Expanded(
                        child: BotaoSelecionavel(
                          rotulo: tipo,
                          selecionado: viewModel.tipoInsulina == tipo,
                          aoTocar: () => viewModel.selecionarTipoInsulina(tipo),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
              ],
              const RotuloPergunta('Quantas unidades?'),
              _CampoNumerico(
                controller: _doseController,
                rotulo: 'Unidades de insulina',
                dica: 'Ex.: 10',
                sufixo: 'unidades',
                erro: viewModel.erroDose,
                permiteDecimal: true,
              ),
              const SizedBox(height: 24),
            ],
            if (viewModel.mensagemErro != null) ...[
              _TextoErro(viewModel.mensagemErro!),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: viewModel.salvando ? null : _salvar,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
                textStyle:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                iconSize: 28,
              ),
              icon: viewModel.salvando
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

// Campo numerico grande (fonte 28) para o valor medido ou a dose.
class _CampoNumerico extends StatelessWidget {
  final TextEditingController controller;
  final String rotulo;
  final String dica;
  final String sufixo;
  final String? erro;
  final bool permiteDecimal;

  const _CampoNumerico({
    required this.controller,
    required this.rotulo,
    required this.dica,
    required this.sufixo,
    required this.erro,
    required this.permiteDecimal,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: rotulo,
      textField: true,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: permiteDecimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            permiteDecimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
          ),
          LengthLimitingTextInputFormatter(5),
        ],
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: dica,
          suffixText: sufixo,
          suffixStyle: const TextStyle(fontSize: 18),
          errorText: erro,
          errorStyle: const TextStyle(fontSize: 16),
          errorMaxLines: 3,
        ),
      ),
    );
  }
}

class _TextoErro extends StatelessWidget {
  final String texto;

  const _TextoErro(this.texto);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          texto,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppCores.perigo,
          ),
        ),
      ),
    );
  }
}
