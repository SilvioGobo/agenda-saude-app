import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/services/notification_service.dart';
import '../../core/services/push_service.dart';
import '../../data/repositories/acompanhante_repository.dart';
import '../../data/repositories/dados_repository.dart';
import '../../domain/models/alerta.dart';
import '../../domain/models/paciente.dart';
import 'formato_alertas.dart';

// Central de alertas do acompanhante (RF06): escuta em tempo real os alertas
// de cada paciente vinculado, mostra uma notificacao no aparelho assim que o
// app do paciente gera um alerta novo (ex.: o painel dele passou a mostrar
// "ATENÇÃO") e guarda a lista exibida na tela de Notificacoes.
//
// A escuta vale enquanto o app do acompanhante esta aberto ou em segundo
// plano. Com o app fechado, quem avisa e o push (B6): esta central grava o
// token do aparelho em `usuarios/{uid}.fcmTokens`, que a Cloud Function usa
// para mandar o alerta, e o tira ao sair da conta.
class AlertasViewModel extends ChangeNotifier with WidgetsBindingObserver {
  final DadosMedicosRepository _dadosRepository;
  final NotificationService _notificationService;
  final PushService _pushService;
  // Dono do aparelho, para o push. Null nos testes que nao usam o push.
  final String? _acompanhanteId;
  AcompanhanteRepository? _acompanhanteRepository;

  // Quantos alertas mais recentes de cada paciente ficam na lista.
  static const int limitePorPaciente = 50;

  // Quanto esperar a escuta trazer o alerta de uma notificacao tocada: com o
  // app aberto pelo toque, os pacientes e os alertas ainda estao chegando.
  static const Duration esperaPeloAlerta = Duration(seconds: 15);

  // Quanto esperar o Firestore e o FCM ao sair da conta sem internet.
  static const Duration esperaAoDesligarPush = Duration(seconds: 5);

  AlertasViewModel({
    DadosMedicosRepository? dadosRepository,
    NotificationService? notificationService,
    PushService? pushService,
    AcompanhanteRepository? acompanhanteRepository,
    String? acompanhanteId,
  })  : _dadosRepository = dadosRepository ?? DadosMedicosRepository(),
        _notificationService = notificationService ?? NotificationServiceImpl(),
        _pushService = pushService ?? PushServiceImpl(),
        _acompanhanteRepository = acompanhanteRepository,
        _acompanhanteId = acompanhanteId {
    _toquesNaNotificacao =
        _notificationService.toques.listen(_alertasParaAbrir.add);
  }

  // O repository real so e criado quando o push e usado: nos testes sem
  // Firebase ele nem existe.
  AcompanhanteRepository get _repositorioDeTokens =>
      _acompanhanteRepository ??= AcompanhanteRepository();

  final Map<String, Paciente> _pacientes = {};
  final Map<String, StreamSubscription<Object?>> _assinaturas = {};
  final Map<String, List<Alerta>> _alertasPorPaciente = {};
  // Pacientes cuja lista ja veio confirmada pelo servidor: so depois disso um
  // alerta com id desconhecido e de fato novo. Antes, e historico que estava
  // fora do cache do aparelho e nao deve virar notificacao.
  final Set<String> _pacientesSincronizados = {};
  final Set<String> _idsConhecidos = {};

  final _alertasParaAbrir = StreamController<String>.broadcast();
  StreamSubscription<String>? _toquesNaNotificacao;
  StreamSubscription<String>? _toquesNoPush;
  StreamSubscription<String>? _tokensRenovados;
  // Token gravado no Firestore nesta sessao.
  String? _tokenPush;
  bool _pushDesligado = false;
  // Esperas de `aguardarAlerta` ainda abertas, encerradas no dispose.
  final List<void Function(Alerta?)> _esperas = [];

  bool _observandoCicloDeVida = false;
  bool _descartado = false;

  // null enquanto nao verificado ou em aparelho sem notificacao do sistema.
  bool? _notificacoesPermitidas;
  bool get notificacoesDesativadas => _notificacoesPermitidas == false;

  String? _mensagemErro;
  String? get mensagemErro => _mensagemErro;

  // Id do alerta de cada notificacao tocada pelo usuario: com o app aberto,
  // em segundo plano ou encerrado (o toque abriu o app).
  Stream<String> get notificacaoTocada => _alertasParaAbrir.stream;

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

  // Null se o paciente ja foi desvinculado.
  Paciente? pacienteDoAlerta(Alerta alerta) => _pacientes[alerta.pacienteId];

  // Prepara as notificacoes, pede a permissao do sistema (Android 13+) e
  // registra o aparelho para o push.
  Future<void> iniciar() async {
    await Future.wait([_iniciarNotificacoes(), _iniciarPush()]);
  }

  Future<void> _iniciarNotificacoes() async {
    if (!_notificationService.disponivel) return;
    try {
      await _notificationService.inicializar();
    } catch (e) {
      debugPrint('Falha ao preparar as notificações: $e');
      return;
    }
    // O app estava fechado e abriu pelo toque numa notificacao de alerta.
    await _abrirAlertaQueAbriuOApp(_notificationService.payloadQueAbriuOApp);

    try {
      _notificacoesPermitidas = await _notificationService.solicitarPermissao();
    } catch (e) {
      debugPrint('Falha ao pedir a permissão de notificações: $e');
      return;
    }
    if (_descartado) return;

    // Para notar quando o usuario volta das configuracoes do Android.
    WidgetsBinding.instance.addObserver(this);
    _observandoCicloDeVida = true;
    notifyListeners();
  }

  // Grava o token deste aparelho para a Cloud Function mandar o push dos
  // alertas (B6) e passa a ouvir os toques nas notificacoes mostradas pelo
  // sistema. O token vale mesmo sem a permissao de notificacoes: se o
  // acompanhante liberar depois, o push ja chega.
  Future<void> _iniciarPush() async {
    if (_acompanhanteId == null || !_pushService.disponivel) return;

    try {
      _toquesNoPush = _pushService.alertaTocado.listen(_alertasParaAbrir.add);
      _tokensRenovados = _pushService.tokenRenovado.listen(
        _registrarToken,
        onError: (Object erro) =>
            debugPrint('Renovação do token do push falhou: $erro'),
      );
    } catch (e) {
      debugPrint('Falha ao ouvir o push: $e');
    }
    await _abrirAlertaQueAbriuOApp(_pushService.alertaQueAbriuOApp);

    try {
      final token = await _pushService.obterToken();
      if (token != null) await _registrarToken(token);
    } catch (e) {
      debugPrint('Falha ao registrar o aparelho para o push: $e');
    }
  }

  Future<void> _abrirAlertaQueAbriuOApp(
    Future<String?> Function() consultar,
  ) async {
    try {
      final alertaId = await consultar();
      if (alertaId != null && !_descartado) _alertasParaAbrir.add(alertaId);
    } catch (e) {
      debugPrint('Falha ao ler a notificação que abriu o app: $e');
    }
  }

  // Grava o token (no login e a cada renovacao). Se o FCM trocou o token, o
  // antigo sai da lista, porque nao recebe mais nada.
  Future<void> _registrarToken(String token) async {
    final acompanhanteId = _acompanhanteId;
    if (acompanhanteId == null || _descartado || _pushDesligado) return;
    final anterior = _tokenPush;
    try {
      await _repositorioDeTokens.adicionarTokenPush(acompanhanteId, token);
      _tokenPush = token;
      if (anterior != null && anterior != token) {
        await _repositorioDeTokens.removerTokenPush(acompanhanteId, anterior);
      }
    } catch (e) {
      debugPrint('Falha ao gravar o token do push: $e');
    }
  }

  // Chamado antes de sair da conta: tira o token deste aparelho da lista e o
  // invalida no FCM, para os alertas dos pacientes nao chegarem mais aqui.
  // Sem internet o Firestore nao confirma a gravacao; depois de
  // [esperaAoDesligarPush] o app sai assim mesmo, e o aparelho continua sem
  // mostrar os alertas, porque confere quem esta logado antes
  // (`mostrarAlertaDoPush`).
  Future<void> desligarPush() async {
    final acompanhanteId = _acompanhanteId;
    if (acompanhanteId == null || !_pushService.disponivel) return;
    _pushDesligado = true;
    await _tokensRenovados?.cancel();
    _tokensRenovados = null;

    try {
      final token = _tokenPush ??
          await _pushService.obterToken().timeout(esperaAoDesligarPush);
      if (token != null) {
        await _repositorioDeTokens
            .removerTokenPush(acompanhanteId, token)
            .timeout(esperaAoDesligarPush);
      }
    } catch (e) {
      debugPrint('Falha ao tirar o token do push: $e');
    }
    try {
      await _pushService.apagarToken().timeout(esperaAoDesligarPush);
    } catch (e) {
      debugPrint('Falha ao apagar o token do push: $e');
    }
    _tokenPush = null;
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
      // O mesmo titulo do push (functions/notificacao.js), para a
      // notificacao nao mudar quando um substitui o outro.
      await _notificationService.mostrar(
        id: idDaNotificacaoDoAlerta(alerta.id),
        titulo: tituloDoAlerta(alerta, nome),
        texto: alerta.mensagem,
        dataHora: alerta.dataHora,
        urgente: alerta.ehEmergencia,
        payload: alerta.id,
      );
    } catch (e) {
      debugPrint('Falha ao mostrar a notificação: $e');
    }
  }

  Alerta? alertaPorId(String alertaId) {
    for (final alerta in alertas) {
      if (alerta.id == alertaId) return alerta;
    }
    return null;
  }

  // O alerta de uma notificacao tocada, assim que a escuta o trouxer (na
  // hora, se ja estiver na lista). Null se nao chegar em [limite], por
  // exemplo porque o paciente foi desvinculado.
  Future<Alerta?> aguardarAlerta(
    String alertaId, {
    Duration limite = esperaPeloAlerta,
  }) {
    final encontrado = alertaPorId(alertaId);
    if (encontrado != null || _descartado) return Future.value(encontrado);

    final espera = Completer<Alerta?>();
    late final VoidCallback conferir;
    late final Timer prazo;
    void terminar(Alerta? alerta) {
      if (espera.isCompleted) return;
      prazo.cancel();
      removeListener(conferir);
      _esperas.remove(terminar);
      espera.complete(alerta);
    }

    conferir = () {
      final alerta = alertaPorId(alertaId);
      if (alerta != null) terminar(alerta);
    };
    prazo = Timer(limite, () => terminar(null));
    addListener(conferir);
    _esperas.add(terminar);
    return espera.future;
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
        await _notificationService.cancelar(idDaNotificacaoDoAlerta(alerta.id));
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
    for (final terminar in List.of(_esperas)) {
      terminar(null);
    }
    for (final assinatura in _assinaturas.values) {
      assinatura.cancel();
    }
    _toquesNaNotificacao?.cancel();
    _toquesNoPush?.cancel();
    _tokensRenovados?.cancel();
    _alertasParaAbrir.close();
    if (_observandoCicloDeVida) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }
}
