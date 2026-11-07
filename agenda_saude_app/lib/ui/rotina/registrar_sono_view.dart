import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/botao_barra_superior.dart';
import '../shared/botao_salvar.dart';
import '../shared/botao_selecionavel.dart';
import '../shared/contador_grande.dart';
import '../shared/erro_formulario.dart';
import '../shared/pergunta_formulario.dart';
import '../shared/titulo_tela.dart';
import 'formato_sono.dart';
import 'registrar_sono_viewmodel.dart';

// Tela de registro da noite de sono (RF 03.2), aberta pelo cartao "Sono" da
// rotina. Duas perguntas, na ordem em que a pessoa responde: quantas horas
// dormiu (botoes Menos/Mais, sem teclado) e como foi o sono, de 1 a 5, em
// botoes com a palavra e o rosto de cada nota. Pensada para idosos (NF004):
// perguntas em caixa alta, botoes grandes e erro com icone. Fecha devolvendo
// true quando a noite foi salva.
class RegistrarSonoView extends StatelessWidget {
  const RegistrarSonoView({super.key});

  // O formulario chega pronto de `SonoViewModel.novoRegistro()`, ja com o
  // Firestore e o relogio do cartao (e com a noite de hoje, para corrigi-la). A
  // tela fica dona dele e o descarta ao fechar.
  static Route<bool> rota(RegistrarSonoViewModel viewModel) {
    return MaterialPageRoute<bool>(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => viewModel,
        child: const RegistrarSonoView(),
      ),
    );
  }

  Future<void> _salvar(BuildContext context) async {
    final salvou = await context.read<RegistrarSonoViewModel>().salvar();
    if (!context.mounted || !salvou) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RegistrarSonoViewModel>();
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
              viewModel.editando ? 'Corrigir o sono' : 'Registrar sono',
              subtitulo: 'Conte como foi a sua noite e toque em SALVAR.',
            ),
            const SizedBox(height: 32),
            const PerguntaFormulario('1. QUANTAS HORAS VOCÊ DORMIU?'),
            Text(
              'A meta é dormir de '
              '${formatarMetaDeSono(viewModel.metaMinHoras, viewModel.metaMaxHoras)} '
              'por noite.',
              style: TextStyle(
                fontSize: 18,
                height: 1.35,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ContadorGrande(
              valor: formatarHorasDeSono(viewModel.horas),
              valorParaLeitor:
                  'Horas de sono: ${falarHorasDeSono(viewModel.horas)}',
              descricaoMenos: 'Diminuir meia hora de sono',
              descricaoMais: 'Aumentar meia hora de sono',
              aoDiminuir: viewModel.podeDiminuir ? viewModel.diminuirHoras : null,
              aoAumentar: viewModel.podeAumentar ? viewModel.aumentarHoras : null,
            ),
            const SizedBox(height: 32),
            const PerguntaFormulario('2. COMO FOI O SEU SONO?'),
            const SizedBox(height: 8),
            for (var nota = 1; nota <= 5; nota++) ...[
              _OpcaoDeNota(
                nota: nota,
                selecionada: viewModel.qualidade == nota,
                aoEscolher: () => viewModel.escolherQualidade(nota),
              ),
              const SizedBox(height: 8),
            ],
            if (viewModel.erroQualidade != null) ...[
              const SizedBox(height: 4),
              ErroFormulario(viewModel.erroQualidade!),
            ],
            const SizedBox(height: 24),
            if (viewModel.mensagemErro != null) ...[
              ErroFormulario(viewModel.mensagemErro!),
              const SizedBox(height: 16),
            ],
            BotaoSalvar(
              salvando: viewModel.salvando,
              aoTocar: () => _salvar(context),
            ),
          ],
        ),
      ),
    );
  }
}

// Uma nota da escala de 1 a 5: botao largo (64dp) com o rosto, a nota e a
// palavra ("4 - Bom"); o escolhido troca o rosto por um check.
class _OpcaoDeNota extends StatelessWidget {
  static const _rostos = <int, IconData>{
    1: Icons.sentiment_very_dissatisfied_rounded,
    2: Icons.sentiment_dissatisfied_rounded,
    3: Icons.sentiment_neutral_rounded,
    4: Icons.sentiment_satisfied_rounded,
    5: Icons.sentiment_very_satisfied_rounded,
  };

  final int nota;
  final bool selecionada;
  final VoidCallback aoEscolher;

  const _OpcaoDeNota({
    required this.nota,
    required this.selecionada,
    required this.aoEscolher,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(64),
            textStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            side: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
        ),
      ),
      child: BotaoSelecionavel(
        rotulo: '$nota - ${rotuloDaQualidadeDoSono(nota)}',
        icone: _rostos[nota],
        selecionado: selecionada,
        aoTocar: aoEscolher,
      ),
    );
  }
}
