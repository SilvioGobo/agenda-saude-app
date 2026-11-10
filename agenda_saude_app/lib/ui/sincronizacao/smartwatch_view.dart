import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/botao_barra_superior.dart';
import '../shared/titulo_tela.dart';
import 'card_leitura_app_fechado.dart';
import 'card_smartwatch.dart';
import 'card_teste_segundo_plano.dart';
import 'sincronizacao_bpm_viewmodel.dart';

// Tela "Meu smartwatch", aberta pelo menu do paciente: situacao da conexao
// com o relogio, horario da ultima sincronizacao, sincronizacao manual e a
// leitura com o app fechado (B7). Reaproveita o SincronizacaoBpmViewModel do
// painel (que continua lendo enquanto esta tela esta aberta), em vez de criar
// outro. Rodando com `--dart-define=TESTE_B2=true` mostra tambem o cartao do
// teste de leitura com o app fechado (B2).
class SmartwatchView extends StatelessWidget {
  const SmartwatchView({super.key});

  static Widget comViewModel(SincronizacaoBpmViewModel viewModel) {
    return ChangeNotifierProvider.value(
      value: viewModel,
      child: const SmartwatchView(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: BotaoBarraSuperior.largura,
        leading: BotaoBarraSuperior.voltar(
          aoTocar: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            const TituloTela(
              'Meu smartwatch',
              subtitulo: 'O app lê os batimentos do seu smartwatch pelo '
                  'Saúde Connect.',
            ),
            const SizedBox(height: 24),
            const CardSmartwatch(),
            // Some sozinho (com o espaco de cima) enquanto o smartwatch nao
            // esta conectado.
            const CardLeituraAppFechado(),
            if (CardTesteSegundoPlano.habilitado) ...[
              const SizedBox(height: 24),
              CardTesteSegundoPlano.comProviders(),
            ],
          ],
        ),
      ),
    );
  }
}
