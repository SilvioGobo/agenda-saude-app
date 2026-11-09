import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/zona_seguranca_cardiaca.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/botao_salvar.dart';
import '../shared/contador_grande.dart';
import '../shared/erro_formulario.dart';
import '../shared/pergunta_formulario.dart';
import '../shared/titulo_tela.dart';
import 'limites_alerta_viewmodel.dart';

// Tela de ajuste dos limites de alerta de um paciente (RF 06.1), aberta pelo
// botao "Limites de alerta" do card no painel do acompanhante. Duas perguntas,
// o minimo e o maximo de BPM, com os botoes Menos/Mais (sem teclado), a zona
// padrao da triagem para comparar e voltar a ela, e o SALVAR. Fecha
// devolvendo true quando os limites foram salvos.
class LimitesAlertaView extends StatelessWidget {
  const LimitesAlertaView({super.key});

  // O formulario chega pronto do painel, ja com o paciente e os limites que o
  // card mostra agora. A tela fica dona dele e o descarta ao fechar; quem
  // abriu le `limitesSalvos` depois do `true`.
  static Route<bool> rota(LimitesAlertaViewModel viewModel) {
    return MaterialPageRoute<bool>(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => viewModel,
        child: const LimitesAlertaView(),
      ),
    );
  }

  Future<void> _salvar(BuildContext context) async {
    final salvou = await context.read<LimitesAlertaViewModel>().salvar();
    if (!context.mounted || !salvou) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LimitesAlertaViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final nome = viewModel.primeiroNome;
    final textoDeApoio = TextStyle(
      fontSize: 18,
      height: 1.35,
      color: colorScheme.onSurfaceVariant,
    );
    final minutos = ZonaSegurancaCardiaca.tempoProlongadoParaAlerta.inMinutes;

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
              'Limites de alerta',
              subtitulo: 'Escolha a partir de quantos batimentos por minuto '
                  'o alerta de $nome dispara. Ele avisa você e $nome.',
            ),
            const SizedBox(height: 32),
            const PerguntaFormulario('1. BATIMENTOS MÍNIMOS'),
            Text('Abaixo deste valor, o alerta dispara.', style: textoDeApoio),
            const SizedBox(height: 12),
            ContadorGrande(
              valor: '${viewModel.bpmMinimo} BPM',
              valorParaLeitor: 'Mínimo: ${viewModel.bpmMinimo} batimentos '
                  'por minuto',
              descricaoMenos: 'Diminuir o mínimo em '
                  '${LimitesAlertaViewModel.passo} batimentos',
              descricaoMais: 'Aumentar o mínimo em '
                  '${LimitesAlertaViewModel.passo} batimentos',
              aoDiminuir:
                  viewModel.podeDiminuirMinimo ? viewModel.diminuirMinimo : null,
              aoAumentar:
                  viewModel.podeAumentarMinimo ? viewModel.aumentarMinimo : null,
            ),
            const SizedBox(height: 32),
            const PerguntaFormulario('2. BATIMENTOS MÁXIMOS'),
            Text('Acima deste valor, o alerta dispara.', style: textoDeApoio),
            const SizedBox(height: 12),
            ContadorGrande(
              valor: '${viewModel.bpmMaximo} BPM',
              valorParaLeitor: 'Máximo: ${viewModel.bpmMaximo} batimentos '
                  'por minuto',
              descricaoMenos: 'Diminuir o máximo em '
                  '${LimitesAlertaViewModel.passo} batimentos',
              descricaoMais: 'Aumentar o máximo em '
                  '${LimitesAlertaViewModel.passo} batimentos',
              aoDiminuir:
                  viewModel.podeDiminuirMaximo ? viewModel.diminuirMaximo : null,
              aoAumentar:
                  viewModel.podeAumentarMaximo ? viewModel.aumentarMaximo : null,
            ),
            const SizedBox(height: 32),
            _ZonaPadrao(viewModel: viewModel),
            const SizedBox(height: 24),
            Text(
              'Fora desses limites, $nome e você recebem um aviso de atenção '
              'na hora e um alerta de emergência se continuar assim por '
              '$minutos minutos. Combine os valores com o médico de $nome.',
              style: textoDeApoio,
            ),
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

// A zona que o app usa sem limites definidos (60 a 100, ou 60 a 90 para
// cardiopatas) e o botao para voltar a ela.
class _ZonaPadrao extends StatelessWidget {
  final LimitesAlertaViewModel viewModel;

  const _ZonaPadrao({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardiopata = viewModel.paciente.possuiCardiopatia;
    final zona = '${viewModel.padraoMinimo} A ${viewModel.padraoMaximo} BPM';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ZONA PADRÃO: $zona',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            cardiopata
                ? 'Para quem tem cardiopatia, como ${viewModel.primeiroNome}.'
                : 'A zona de batimentos em repouso usada pelo app.',
            style: TextStyle(
              fontSize: 16,
              height: 1.35,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: viewModel.ehPadrao || viewModel.salvando
                ? null
                : viewModel.voltarAoPadrao,
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text(
              viewModel.ehPadrao ? 'Usando a zona padrão' : 'Voltar ao padrão',
            ),
          ),
        ],
      ),
    );
  }
}
