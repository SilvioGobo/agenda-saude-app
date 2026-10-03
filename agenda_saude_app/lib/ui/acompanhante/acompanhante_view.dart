import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/notification_service.dart';
import '../../data/repositories/acompanhante_repository.dart';
import '../../data/repositories/dados_repository.dart';
import '../../domain/models/acompanhante.dart';
import '../../domain/models/paciente.dart';
import '../alertas/alertas_view.dart';
import '../alertas/alertas_viewmodel.dart';
import '../alertas/aviso_alertas_nao_lidos.dart';
import '../alertas/botao_notificacoes.dart';
import '../alertas/card_permissao_notificacoes.dart';
import '../alertas/detalhes_alerta.dart';
import '../auth/botao_sair.dart';
import 'acompanhante_viewmodel.dart';
import 'card_paciente.dart';
import 'vincular_paciente_view.dart';

// Painel do acompanhante (RF05, Figura 15 do TCC): lista em cards dos
// pacientes vinculados, atalho para vincular um novo paciente (RF05.4) e os
// alertas desses pacientes recebidos em tempo real (RF06).
class AcompanhanteView extends StatefulWidget {
  const AcompanhanteView({super.key});

  // Os parametros opcionais permitem aos testes montar o painel com
  // repositories e notificacoes falsos.
  static Widget comProviders(
    Acompanhante acompanhante, {
    AcompanhanteRepository? acompanhanteRepository,
    DadosMedicosRepository? dadosRepository,
    NotificationService? notificationService,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AcompanhanteViewModel(
            acompanhante: acompanhante,
            acompanhanteRepository: acompanhanteRepository,
          )..carregarPacientes(),
        ),
        // A central de alertas segue a lista de pacientes vinculados: a cada
        // mudanca (carga, vinculo, desvinculo) abre ou encerra a escuta.
        ChangeNotifierProxyProvider<AcompanhanteViewModel, AlertasViewModel>(
          create: (_) => AlertasViewModel(
            dadosRepository: dadosRepository,
            notificationService: notificationService,
          )..iniciar(),
          update: (_, acompanhanteViewModel, alertasViewModel) =>
              alertasViewModel!
                ..acompanharPacientes(acompanhanteViewModel.pacientesVinculados),
        ),
      ],
      child: const AcompanhanteView(),
    );
  }

  @override
  State<AcompanhanteView> createState() => _AcompanhanteViewState();
}

class _AcompanhanteViewState extends State<AcompanhanteView> {
  StreamSubscription<String>? _toquesEmNotificacao;

  @override
  void initState() {
    super.initState();
    _toquesEmNotificacao = context
        .read<AlertasViewModel>()
        .notificacaoTocada
        .listen(_abrirAlertaDaNotificacao);
  }

  @override
  void dispose() {
    _toquesEmNotificacao?.cancel();
    super.dispose();
  }

  void _abrirNotificacoes() {
    Navigator.of(context).push(
      AlertasView.rota(context.read<AlertasViewModel>()),
    );
  }

  // Tocar na notificacao traz o app para a frente: volta ao painel (fechando
  // o que estiver aberto por cima), abre a lista e os detalhes do alerta.
  void _abrirAlertaDaNotificacao(String alertaId) {
    if (!mounted) return;
    final alertasViewModel = context.read<AlertasViewModel>();
    final rotaDoPainel = ModalRoute.of(context);
    Navigator.of(context).popUntil((rota) => rota == rotaDoPainel);
    _abrirNotificacoes();

    final alerta = alertasViewModel.alertaPorId(alertaId);
    if (alerta != null) {
      abrirDetalhesDoAlerta(context, alertasViewModel, alerta);
    }
  }

  Future<void> _vincularPaciente() async {
    final viewModel = context.read<AcompanhanteViewModel>();
    final vinculou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VincularPacienteView.comProviders(viewModel.acompanhante),
      ),
    );

    if (!mounted || vinculou != true) return;
    await viewModel.carregarPacientes();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Paciente vinculado com sucesso.')),
    );
  }

  Future<void> _confirmarDesvinculo(Paciente paciente) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desvincular paciente?'),
        content: Text(
          'Você deixará de acompanhar os dados de ${paciente.nome}. '
          'Para voltar a acompanhar, será preciso digitar o código novamente.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );

    if (!mounted || confirmou != true) return;
    final sucesso =
        await context.read<AcompanhanteViewModel>().desvincular(paciente);
    if (!mounted || !sucesso) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${paciente.nome} foi desvinculado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AcompanhanteViewModel>();
    final alertasViewModel = context.watch<AlertasViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final pacientes = viewModel.pacientesVinculados;
    final naoLidos = alertasViewModel.naoLidos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoramento'),
        automaticallyImplyLeading: false,
        actions: [
          BotaoNotificacoes(onPressed: _abrirNotificacoes),
          const BotaoSair(),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: viewModel.carregarPacientes,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Olá, ${viewModel.primeiroNome}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                pacientes.isEmpty
                    ? 'Você ainda não acompanha nenhum paciente.'
                    : 'Você acompanha ${pacientes.length} '
                        '${pacientes.length == 1 ? 'paciente' : 'pacientes'}.',
                style: TextStyle(
                  fontSize: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              if (naoLidos.isNotEmpty) ...[
                AvisoAlertasNaoLidos(
                  alerta: naoLidos.first,
                  nomePaciente:
                      alertasViewModel.nomeDoPaciente(naoLidos.first.pacienteId),
                  totalNaoLidos: naoLidos.length,
                  onVerNotificacoes: _abrirNotificacoes,
                ),
                const SizedBox(height: 16),
              ],
              if (alertasViewModel.notificacoesDesativadas &&
                  pacientes.isNotEmpty) ...[
                CardPermissaoNotificacoes(
                  onAtivar: alertasViewModel.ativarNotificacoes,
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
              if (viewModel.carregando && pacientes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (pacientes.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 48,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Peça ao paciente o código de vínculo que aparece '
                          'no painel dele e toque em "Vincular paciente".',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final paciente in pacientes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CardPaciente(
                      paciente: paciente,
                      alertasNaoLidos:
                          alertasViewModel.naoLidosDoPaciente(paciente.id),
                      onDesvincular: viewModel.carregando
                          ? null
                          : () => _confirmarDesvinculo(paciente),
                    ),
                  ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: viewModel.carregando ? null : _vincularPaciente,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Vincular paciente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
