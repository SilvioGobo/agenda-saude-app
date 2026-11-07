import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/meta_exercicio.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/botao_salvar.dart';
import '../shared/botao_selecionavel.dart';
import '../shared/contador_grande.dart';
import '../shared/erro_formulario.dart';
import '../shared/pergunta_formulario.dart';
import '../shared/titulo_tela.dart';
import 'formato_exercicio.dart';
import 'registrar_exercicio_viewmodel.dart';

// Tela de registro de um exercicio (RF 03.3), aberta pelo cartao "Exercicio"
// da rotina. Tres perguntas, na ordem em que a pessoa responde: qual
// exercicio fez (botoes grandes, sem digitar), por quantos minutos (botoes
// Menos/Mais) e como foi a intensidade, explicada pelo "teste da conversa".
// Pensada para idosos (NF004): perguntas em caixa alta, botoes grandes e erro
// com icone. Fecha devolvendo true quando o exercicio foi salvo.
class RegistrarExercicioView extends StatelessWidget {
  const RegistrarExercicioView({super.key});

  // O formulario chega pronto de `ExercicioViewModel.novoRegistro()`, ja com o
  // Firestore e o relogio do cartao. A tela fica dona dele e o descarta ao
  // fechar.
  static Route<bool> rota(RegistrarExercicioViewModel viewModel) {
    return MaterialPageRoute<bool>(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => viewModel,
        child: const RegistrarExercicioView(),
      ),
    );
  }

  Future<void> _salvar(BuildContext context) async {
    final salvou = await context.read<RegistrarExercicioViewModel>().salvar();
    if (!context.mounted || !salvou) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RegistrarExercicioViewModel>();

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
            const TituloTela(
              'Registrar exercício',
              subtitulo: 'Conte o que você fez e toque em SALVAR.',
            ),
            const SizedBox(height: 32),
            const PerguntaFormulario('1. QUE EXERCÍCIO VOCÊ FEZ?'),
            const SizedBox(height: 8),
            for (final tipo in MetaExercicio.tipos) ...[
              _Opcao(
                rotulo: tipo,
                selecionada: viewModel.tipo == tipo,
                aoEscolher: () => viewModel.escolherTipo(tipo),
              ),
              const SizedBox(height: 8),
            ],
            if (viewModel.erroTipo != null) ...[
              const SizedBox(height: 4),
              ErroFormulario(viewModel.erroTipo!),
            ],
            const SizedBox(height: 24),
            const PerguntaFormulario('2. POR QUANTO TEMPO?'),
            const SizedBox(height: 8),
            ContadorGrande(
              valor: formatarMinutos(viewModel.minutos),
              valorParaLeitor:
                  'Duração do exercício: ${falarMinutos(viewModel.minutos)}',
              descricaoMenos:
                  'Diminuir ${MetaExercicio.passoMinutos} minutos de exercício',
              descricaoMais:
                  'Aumentar ${MetaExercicio.passoMinutos} minutos de exercício',
              aoDiminuir:
                  viewModel.podeDiminuir ? viewModel.diminuirMinutos : null,
              aoAumentar:
                  viewModel.podeAumentar ? viewModel.aumentarMinutos : null,
            ),
            const SizedBox(height: 32),
            const PerguntaFormulario('3. COMO FOI A INTENSIDADE?'),
            const SizedBox(height: 8),
            for (final intensidade in MetaExercicio.intensidades) ...[
              _Opcao(
                rotulo: intensidade,
                explicacao: descricaoDaIntensidade(intensidade),
                selecionada: viewModel.intensidade == intensidade,
                aoEscolher: () => viewModel.escolherIntensidade(intensidade),
              ),
              const SizedBox(height: 8),
            ],
            if (viewModel.erroIntensidade != null) ...[
              const SizedBox(height: 4),
              ErroFormulario(viewModel.erroIntensidade!),
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

// Uma escolha: botao largo (64dp) com check no escolhido e, se houver, uma
// frase explicando-a logo abaixo.
class _Opcao extends StatelessWidget {
  final String rotulo;
  final String? explicacao;
  final bool selecionada;
  final VoidCallback aoEscolher;

  const _Opcao({
    required this.rotulo,
    this.explicacao,
    required this.selecionada,
    required this.aoEscolher,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Theme(
          data: Theme.of(context).copyWith(
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                side: BorderSide(color: colorScheme.primary, width: 2),
              ),
            ),
          ),
          child: BotaoSelecionavel(
            rotulo: rotulo,
            selecionado: selecionada,
            aoTocar: aoEscolher,
          ),
        ),
        if (explicacao != null && explicacao!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              explicacao!,
              style: TextStyle(
                fontSize: 16,
                height: 1.35,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
