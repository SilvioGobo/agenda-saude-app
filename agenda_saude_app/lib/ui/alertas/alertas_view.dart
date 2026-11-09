import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../configuracoes/configuracoes_viewmodel.dart';
import '../shared/botao_ouvir_tela.dart';
import 'alertas_viewmodel.dart';
import 'card_alerta.dart';
import 'detalhes_alerta.dart';
import 'narracao_dos_alertas.dart';

// Tela de Notificacoes do acompanhante (RF06): historico dos alertas dos
// pacientes vinculados, do mais recente para o mais antigo, atualizado em
// tempo real. Tocar num alerta marca como lido e abre os detalhes (RF06.4).
class AlertasView extends StatelessWidget {
  const AlertasView({super.key});

  // A tela abre por cima do painel e reaproveita a central de alertas dele,
  // que continua escutando os pacientes em tempo real. Se o painel tem o
  // narrador de voz, [narrador] o leva junto - a tela nao herda os providers
  // do painel - e a tela ganha o botao "Ouvir esta tela".
  static Route<void> rota(
    AlertasViewModel viewModel, {
    ConfiguracoesViewModel? narrador,
  }) {
    return MaterialPageRoute(
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: viewModel),
          if (narrador != null) ChangeNotifierProvider.value(value: narrador),
        ],
        child: const AlertasView(),
      ),
    );
  }

  // O texto do botao "Ouvir esta tela" (RF 08.2), lido no instante do toque.
  String _textoParaOuvir(BuildContext context) {
    final viewModel = context.read<AlertasViewModel>();
    if (viewModel.alertas.isEmpty && viewModel.carregando) {
      return notificacoesCarregandoNarradas;
    }
    return narrarNotificacoes(
      alertas: viewModel.alertas,
      nomeDoPaciente: viewModel.nomeDoPaciente,
      agora: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AlertasViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final alertas = viewModel.alertas;
    final naoLidos = viewModel.totalNaoLidos;

    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            BotaoOuvirTela(texto: () => _textoParaOuvir(context)),
            Text(
              naoLidos == 0
                  ? 'Nenhuma notificação nova.'
                  : 'Você tem $naoLidos '
                      '${naoLidos == 1 ? 'notificação não lida' : 'notificações não lidas'}.',
              style: TextStyle(
                fontSize: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (naoLidos > 0) ...[
              OutlinedButton.icon(
                onPressed: viewModel.marcarTodosComoLidos,
                icon: const Icon(Icons.done_all_rounded),
                label: const Text('Marcar todas como lidas'),
              ),
              const SizedBox(height: 16),
            ],
            if (viewModel.mensagemErro != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  viewModel.mensagemErro!,
                  style: const TextStyle(color: AppCores.perigo, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            if (alertas.isEmpty && viewModel.carregando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (alertas.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 48,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Nenhum alerta por enquanto. Quando algum paciente '
                        'precisar de atenção, você será avisado aqui e no '
                        'celular.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final alerta in alertas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CardAlerta(
                    alerta: alerta,
                    nomePaciente: viewModel.nomeDoPaciente(alerta.pacienteId),
                    onTap: () =>
                        abrirDetalhesDoAlerta(context, viewModel, alerta),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
