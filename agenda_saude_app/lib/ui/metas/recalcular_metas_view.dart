import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/botao_selecionavel.dart';
import '../shared/dialogo_confirmacao.dart';
import '../shared/rotulo_pergunta.dart';
import '../shared/titulo_tela.dart';
import 'metas_viewmodel.dart';

// Atualiza o peso e o nivel de atividade fisica e calcula as metas de novo.
// O peso muda com o tempo; sem um lugar para atualiza-lo, as metas ficariam
// presas ao valor da triagem.
class RecalcularMetasView extends StatefulWidget {
  const RecalcularMetasView({super.key});

  @override
  State<RecalcularMetasView> createState() => _RecalcularMetasViewState();
}

class _RecalcularMetasViewState extends State<RecalcularMetasView> {
  static const _niveis = ['Sedentário', 'Leve', 'Moderado', 'Intenso'];

  late final TextEditingController _pesoController;
  String? _nivel;

  @override
  void initState() {
    super.initState();
    final paciente = context.read<MetasViewModel>().paciente;
    final peso = paciente.pesoKg;
    _pesoController = TextEditingController(
      text: peso == null
          ? ''
          : peso
                .toStringAsFixed(peso == peso.roundToDouble() ? 0 : 1)
                .replaceAll('.', ','),
    );
    _nivel = paciente.nivelAtividadeFisica;
  }

  @override
  void dispose() {
    _pesoController.dispose();
    super.dispose();
  }

  Future<void> _recalcular() async {
    final viewModel = context.read<MetasViewModel>();
    final nivel = _nivel;
    if (nivel == null) return;

    if (viewModel.precisaConfirmarRecalculo) {
      final confirmou = await mostrarDialogoConfirmacao(
        context,
        titulo: 'Trocar seus ajustes?',
        mensagem:
            'Você mudou algumas metas manualmente. Recalcular troca '
            'tudo pelas metas calculadas com seus dados.',
        rotuloConfirmar: 'Recalcular',
        iconeConfirmar: Icons.refresh_rounded,
      );
      if (!mounted || !confirmou) return;
    }

    final recalculou = await viewModel.recalcular(
      pesoTexto: _pesoController.text,
      nivelAtividade: nivel,
    );
    if (!mounted || !recalculou) return;
    Navigator.of(context).pop();
  }

  Widget _botaoNivel(String nivel) {
    return Expanded(
      child: BotaoSelecionavel(
        rotulo: nivel,
        selecionado: _nivel == nivel,
        aoTocar: () => setState(() => _nivel = nivel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MetasViewModel>();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: BotaoBarraSuperior.largura,
        leading: BotaoBarraSuperior.voltar(
          aoTocar: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            const TituloTela(
              'Atualizar peso',
              subtitulo:
                  'Seu peso ou sua rotina mudaram? Confira os dados '
                  'abaixo para o app calcular suas metas de novo.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _pesoController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(fontSize: 18),
              decoration: const InputDecoration(labelText: 'Peso (kg)'),
            ),
            const SizedBox(height: 20),
            const RotuloPergunta('Nível de atividade física habitual'),
            Row(
              children: [
                _botaoNivel(_niveis[0]),
                const SizedBox(width: 12),
                _botaoNivel(_niveis[1]),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _botaoNivel(_niveis[2]),
                const SizedBox(width: 12),
                _botaoNivel(_niveis[3]),
              ],
            ),
            const SizedBox(height: 32),
            if (viewModel.mensagemErro != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Semantics(
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
              ),
            FilledButton.icon(
              onPressed: viewModel.carregando || _nivel == null
                  ? null
                  : _recalcular,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Recalcular metas'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
