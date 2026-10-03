import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/services/notification_service.dart';
import '../../data/repositories/dados_repository.dart';
import '../../domain/models/alerta.dart';
import '../../domain/models/paciente.dart';

// Central de alertas do acompanhante (RF06): escuta em tempo real os alertas
// de cada paciente vinculado, mostra uma notificacao no aparelho assim que o
// app do paciente gera um alerta novo (ex.: o painel dele passou a mostrar
// "ATENÇÃO") e guarda a lista exibida na tela de Notificacoes.
//
// A escuta vale enquanto o app do acompanhante esta aberto ou em segundo
// plano. Com o app encerrado nao ha notificacao: isso exige push via FCM
// disparado por um servidor (Cloud Functions), previsto para outra etapa.
class AlertasViewModel extends ChangeNotifier with WidgetsBindingObserver {
  final DadosMedicosRepository _dadosRepository;
  final NotificationService _notificationService;

  // Quantos alertas mais recentes de cada paciente ficam na lista.
  static const int limitePorPaciente = 50;

  AlertasViewModel({
    DadosMedicosRepository? dadosRepository,
    NotificationService? notificationService,
  })  : _dadosRepository = dadosRepository ?? DadosMedicosRepository(),
        _notificationService = notificationService ?? NotificationServiceImpl();

  final Map<String, Paciente> _pacientes = {};
  final Map<String, StreamSubscription<Object?>> _assinaturas = {};
  final Map<String, List<Alerta>> _alertasPorPaciente = {};
  // Pacientes cuja lista ja veio confirmada pelo servidor: so depois disso um
  // alerta com id desconhecido e de fato novo. Antes, e historico que estava
  // fora do cache do aparelho e nao deve virar notificacao.
  final Set<String> _pacientesSincronizados = {};
  final Set<String> _idsConhecidos = {};

  bool _observandoCicloDeVida = false;
  bool _descartado = false;

  // null enquanto nao verificado ou em aparelho sem notificacao do sistema.
  bool? _notificacoesPermitidas;
  bool get notificacoesDesativadas => _notificacoesPermitidas == false;

  String? _mensagemErro;
  String? get mensagemErro => _mensagemErro;

  // Id do alerta de cada notificacao tocada pelo usuario.
  Stream<String> get notificacaoTocada => _notificationService.toques;

  // Todos os alertas dos pacientes vinculados, do mais novo para o mais antigo.
  List<Alerta> get alertas =>
      _alertasPorPaciente.values.expand((lista) => lista).toList()
        ..sort((a, b) => b.dataHora.compareTo(a.dataHora));

  List<Alerta> get naoLidos => alertas.where((a) => !a.lido).toList();

  int get totalNaoLidos => naoLidos.length;

  int naoLidosDoPaciente(String pacienteId) =>
      _alertasPorPaciente[pacienteId]?.where((a) => !a.lido).length ?? 0;

  // Algum paciente ainda sem a primeira leitura dos alertas.
  bool get carregando =>
      _pacientes.keys.any((id) => !_alertasPorPaciente.containsKey(id));

  String nomeDoPaciente(String pacienteId) {
    final nome = _pacientes[pacienteId]?.nome.trim() ?? '';
    return nome.isEmpty ? 'Paciente' : nome;
  }

  // Prepara as notificacoes e pede a permissao do sistema (Android 13+).
  Future<void> iniciar() async {
    if (!_notificationService.disponivel) return;
    try {
      await _notificationService.inicializar();
      _notificacoesPermitidas = await _notificationService.solicitarPermissao();
    } catch (e) {
      debugPrint('Falha ao preparar as notificações: $e');
      return;
    }
    if (_descartado) return;

    // Para notar quando o usuario volta das configuracoes do Android.
    WidgetsBinding.instance.addObserver(this);
    _observandoCicloDeVida = true;
    notifyListeners();
  }

  // Chamado sempre que a lista de pacientes vinculados muda (carregamento,
  // vinculo novo, desvinculo): abre a escuta de quem entrou e encerra a de
  // quem saiu. Nao notifica os ouvintes porque roda durante o build, quando
  // o painel ja esta sendo redesenhado com a lista nova.
  void acompanharPacientes(List<Paciente> pacientes) {
    final ids = pacientes.map((p) => p.id).toSet();
    for (final id in _assinaturas.keys.where((id) => !ids.contains(id)).toList()) {
      _assinaturas.remove(id)?.cancel();
      _alertasPorPaciente.remove(id);
      _pacientesSincronizados.remove(id);
    }

    _pacientes
      ..clear()
      ..addEntries(pacientes.map((p) => MapEntry(p.id, p)));

    for (final id in ids) {
      if (_assinaturas.containsKey(id)) continue;
      _assinaturas[id] = _dadosRepository
          .streamAlertas(id, limite: limitePorPaciente)
          .listen(
            (leitura) => _receberAlertas(id, leitura.alertas, leitura.doServidor),
            onError: (Object erro) =>
                debugPrint('Stream de alertas do paciente $id falhou: $erro'),
          );
    }
  }

  void _receberAlertas(
    String pacienteId,
    List<Alerta> alertas,
    bool doServidor,
  ) {
    if (_descartado) return;

    final jaSincronizado = _pacientesSincronizados.contains(pacienteId);
    _alertasPorPaciente[pacienteId] = alertas;
    for (final alerta in alertas) {
      final novo = _idsConhecidos.add(alerta.id);
      if (novo && jaSincronizado && !alerta.lido) _notificar(alerta);
    }
    if (doServidor) _pacientesSincronizados.add(pacienteId);

    notifyListeners();
  }

  Future<void> _notificar(Alerta alerta) async {
    final nome = nomeDoPaciente(alerta.pacienteId);
    try {
      await _notificationService.mostrar(
        id: _idDaNotificacao(alerta),
        titulo: alerta.ehEmergencia ? 'Emergência: $nome' : 'Atenção: $nome',
        texto: alerta.mensagem,
        dataHora: alerta.dataHora,
        urgente: alerta.ehEmergencia,
        payload: alerta.id,
      );
    } catch (e) {
      debugPrint('Falha ao mostrar a notificação: $e');
    }
  }

  // O plugin identifica cada notificacao por um int; derivar do id do alerta
  // permite remove-la da bandeja quando o alerta e lido no app.
  int _idDaNotificacao(Alerta alerta) => alerta.id.hashCode & 0x7fffffff;

  Alerta? alertaPorId(String alertaId) {
    for (final alerta in alertas) {
      if (alerta.id == alertaId) return alerta;
    }
    return null;
  }

  Future<void> marcarComoLido(Alerta alerta) async {
    if (alerta.lido) return;
    await _marcarComoLidos([alerta]);
  }

  Future<void> marcarTodosComoLidos() => _marcarComoLidos(naoLidos);

  // A lista se atualiza sozinha pela escuta em tempo real.
  Future<void> _marcarComoLidos(List<Alerta> alertas) async {
    if (alertas.isEmpty) return;
    try {
      await _dadosRepository
          .marcarAlertasComoLidos(alertas.map((a) => a.id).toList());
      _mensagemErro = null;
    } catch (e) {
      debugPrint('Falha ao marcar alertas como lidos: $e');
      _mensagemErro = 'Não foi possível marcar como lida. Tente novamente.';
      if (!_descartado) notifyListeners();
      return;
    }

    for (final alerta in alertas) {
      try {
        await _notificationService.cancelar(_idDaNotificacao(alerta));
      } catch (e) {
        debugPrint('Falha ao remover a notificação: $e');
      }
    }
  }

  // Botao "Ativar notificações": tenta o pedido do sistema e, se o Android ja
  // nao mostra mais o pedido (permissao negada antes), abre as configuracoes
  // de notificacao do app.
  Future<void> ativarNotificacoes() async {
    try {
      final permitiu = await _notificationService.solicitarPermissao();
      if (!permitiu) await _notificationService.abrirConfiguracoes();
      _notificacoesPermitidas = permitiu;
    } catch (e) {
      debugPrint('Falha ao ativar as notificações: $e');
    }
    if (!_descartado) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reverificarPermissao();
  }

  Future<void> _reverificarPermissao() async {
    try {
      final permitidas = await _notificationService.notificacoesPermitidas();
      if (_descartado || permitidas == _notificacoesPermitidas) return;
      _notificacoesPermitidas = permitidas;
      notifyListeners();
    } catch (e) {
      debugPrint('Falha ao verificar a permissão de notificações: $e');
    }
  }

  @override
  void dispose() {
    _descartado = true;
    for (final assinatura in _assinaturas.values) {
      assinatura.cancel();
    }
    if (_observandoCicloDeVida) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }
}
