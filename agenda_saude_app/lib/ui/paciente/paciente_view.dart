import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../../domain/models/paciente.dart';
import '../auth/login_view.dart';
import '../auth/login_viewmodel.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/botao_grande.dart';
import '../shared/caixa_alerta.dart';
import '../shared/card_status.dart';
import '../shared/dialogo_confirmacao.dart';
import '../shared/tela_provisoria.dart';
import '../shared/titulo_tela.dart';
import '../sincronizacao/card_smartwatch.dart';
import '../sincronizacao/sincronizacao_bpm_viewmodel.dart';
import '../sincronizacao/smartwatch_view.dart';
import 'card_batimentos.dart';
import 'codigo_vinculo_view.dart';
import 'menu_paciente.dart';
import 'paciente_viewmodel.dart';

// Painel principal do paciente (RF05, Figura 13 do TCC): saudacao, destaque
// de BPM em tempo real com o status da zona de seguranca e atalhos grandes
// para a rotina diaria e para o acompanhante. O que o paciente usa pouco
// (codigo de vinculo, conexao do smartwatch, sair) fica no menu lateral.
class PacienteView extends StatelessWidget {
  const PacienteView({super.key});

  // Monta o painel com os dois ViewModels de que ele depende: o do painel em
  // si e o da sincronizacao com o smartwatch (que ja comeca a ler ao abrir).
  static Widget comProviders(Paciente paciente) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PacienteViewModel(paciente: paciente),
        ),
        ChangeNotifierProvider(
          create: (_) => SincronizacaoBpmViewModel(paciente: paciente)..iniciar(),
        ),
      ],
      child: const PacienteView(),
    );
  }

  void _abrir(BuildContext context, Widget tela) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => tela));
  }

  void _abrirMinhaRotina(BuildContext context) {
    _abrir(
      context,
      const TelaProvisoria(
        titulo: 'Minha Rotina',
        mensagem: 'O checklist de rotina diária (água, sono, exercícios e '
            'medicação) ainda está em desenvolvimento.',
      ),
    );
  }

  void _falarComAcompanhante(BuildContext context) {
    _abrir(
      context,
      const TelaProvisoria(
        titulo: 'Falar com Acompanhante',
        mensagem: 'O contato direto com o acompanhante ainda está em '
            'desenvolvimento.',
      ),
    );
  }

  Future<void> _confirmarSaida(BuildContext context) async {
    final confirmou = await mostrarDialogoConfirmacao(
      context,
      titulo: 'Sair da conta?',
      mensagem: 'Para voltar a usar o aplicativo, você vai precisar entrar '
          'de novo com seu e-mail e senha.',
      rotuloConfirmar: 'Sair',
      iconeConfirmar: Icons.logout_rounded,
    );
    if (!context.mounted || !confirmou) return;

    try {
      await context.read<PacienteViewModel>().sair();
    } catch (e) {
      debugPrint('Falha ao sair da conta: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível sair. Tente de novo.')),
      );
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => LoginViewModel(),
          child: const LoginView(),
        ),
      ),
      (_) => false,
    );
  }

  // O que aparece no lugar de destaque: o problema do smartwatch (que deixa
  // o BPM desatualizado), a espera pela primeira medicao ou o BPM com o
  // status da zona de seguranca logo abaixo.
  List<Widget> _destaque(BuildContext context) {
    final viewModel = context.watch<PacienteViewModel>();
    final sincronizacao = context.watch<SincronizacaoBpmViewModel>();
    final smartwatch = InfoSmartwatch.de(context, sincronizacao);
    final batimento = viewModel.ultimoBatimento;
    final colorScheme = Theme.of(context).colorScheme;

    if (smartwatch.temProblema) {
      return [
        CardSemBatimentos(
          icone: smartwatch.icone,
          titulo: smartwatch.titulo,
          descricao: smartwatch.descricao,
          cor: smartwatch.cor,
          acao: smartwatch.acao,
          destacarBorda: true,
        ),
      ];
    }

    if (batimento == null) {
      final procurando =
          sincronizacao.estado == EstadoSincronizacao.verificando;
      return [
        CardSemBatimentos(
          icone: procurando ? Icons.watch_rounded : Icons.hourglass_top_rounded,
          titulo: procurando
              ? 'Procurando seu smartwatch...'
              : 'Aguardando medição',
          descricao: 'Use o smartwatch no pulso. Seus batimentos aparecem '
              'aqui assim que ele medir.',
          cor: colorScheme.primary,
        ),
      ];
    }

    final status = viewModel.statusCardiaco;
    final emAlerta =
        status == StatusCardiaco.alto || status == StatusCardiaco.baixo;

    return [
      CardBatimentos(
        bpm: batimento.bpm,
        medidoEm: batimento.timestamp,
        emAlerta: emAlerta,
      ),
      const SizedBox(height: 16),
      if (status == StatusCardiaco.alto)
        CaixaAlerta(
          titulo: 'BATIMENTOS ALTOS',
          mensagem: 'Seus batimentos estão acima de ${viewModel.bpmMaximo} '
              'por minuto. Fique em repouso. Se não melhorar ou se sentir '
              'mal, fale com seu acompanhante.',
        )
      else if (status == StatusCardiaco.baixo)
        CaixaAlerta(
          titulo: 'BATIMENTOS BAIXOS',
          mensagem: 'Seus batimentos estão abaixo de ${viewModel.bpmMinimo} '
              'por minuto. Fique em repouso. Se não melhorar ou se sentir '
              'mal, fale com seu acompanhante.',
        )
      else
        const CardStatus(
          rotulo: 'ESTÁVEL',
          icone: Icons.check_circle_rounded,
          cor: AppCores.sucesso,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PacienteViewModel>();
    final sincronizacao = context.read<SincronizacaoBpmViewModel>();

    return Scaffold(
      // So abre pelo botao "Menu": o gesto de arrastar da borda se confunde
      // com o "voltar" do Android e abriria o menu sem querer.
      drawerEnableOpenDragGesture: false,
      drawer: MenuPaciente(
        aoAbrirCodigo: () => _abrir(
          context,
          CodigoVinculoView(codigo: viewModel.paciente.codigoVinculo),
        ),
        aoAbrirSmartwatch: () =>
            _abrir(context, SmartwatchView.comViewModel(sincronizacao)),
        aoSair: () => _confirmarSaida(context),
      ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: BotaoBarraSuperior.largura,
        leading: Builder(
          builder: (scaffoldContext) => BotaoBarraSuperior.menu(
            aoTocar: () => Scaffold.of(scaffoldContext).openDrawer(),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            TituloTela('Olá, ${viewModel.primeiroNome}'),
            const SizedBox(height: 24),
            ..._destaque(context),
            const SizedBox(height: 32),
            BotaoGrande(
              rotulo: 'Minha Rotina',
              icone: Icons.checklist_rounded,
              aoTocar: () => _abrirMinhaRotina(context),
            ),
            const SizedBox(height: 16),
            BotaoGrande(
              rotulo: 'Falar com Acompanhante',
              icone: Icons.call_rounded,
              principal: false,
              aoTocar: () => _falarComAcompanhante(context),
            ),
          ],
        ),
      ),
    );
  }
}
