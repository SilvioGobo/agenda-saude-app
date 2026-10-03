import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'alertas_viewmodel.dart';
import 'card_alerta.dart';
import 'detalhes_alerta.dart';

// Tela de Notificacoes do acompanhante (RF06): historico dos alertas dos
// pacientes vinculados, do mais recente para o mais antigo, atualizado em
// tempo real. Tocar num alerta marca como lido e abre os detalhes (RF06.4).
class AlertasView extends StatelessWidget {
  const AlertasView({super.key});

  // A tela abre por cima do painel e reaproveita a central de alertas dele,
  // que continua escutando os pacientes em tempo real.
  static Route<void> rota(AlertasViewModel viewModel) {
    return MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: viewModel,
        child: const AlertasView(),
      ),
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
                  style: const TextStyle(color: Colors.red, fontSize: 16),
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
