import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Contrato das notificacoes no aparelho (RF06). A central de alertas do
// acompanhante depende so desta interface, entao nos testes basta injetar um
// fake em memoria.
abstract class NotificationService {
  // Falso em plataformas sem notificacao do sistema (web, desktop): o app
  // continua funcionando, so sem o aviso fora da tela.
  bool get disponivel;

  Future<void> inicializar();

  Future<bool> notificacoesPermitidas();

  // Mostra o pedido de permissao do sistema (Android 13+); retorna se as
  // notificacoes ficaram permitidas.
  Future<bool> solicitarPermissao();

  // Abre as configuracoes de notificacao do app. Necessario quando o usuario
  // ja negou a permissao e o Android nao mostra mais o pedido.
  Future<void> abrirConfiguracoes();

  Future<void> mostrar({
    required int id,
    required String titulo,
    required String texto,
    required DateTime dataHora,
    bool urgente = false,
    String? payload,
  });

  Future<void> cancelar(int id);

  // Payload de cada notificacao tocada pelo usuario com o app aberto ou em
  // segundo plano.
  Stream<String> get toques;
}

// Implementacao real em cima do plugin `flutter_local_notifications`.
class NotificationServiceImpl implements NotificationService {
  static const _canal = MethodChannel('agenda_saude_app/notificacoes');

  // Canal de notificacao do Android: aparece com este nome nas configuracoes
  // do app, onde o usuario pode ajusta-lo sem desligar as demais.
  static const _idCanalAndroid = 'alertas_pacientes';
  static const _nomeCanalAndroid = 'Alertas dos pacientes';
  static const _descricaoCanalAndroid =
      'Avisos de batimentos fora da zona de segurança dos pacientes que você '
      'acompanha.';

  static const _vermelho = Color(0xFFD32F2F);

  final FlutterLocalNotificationsPlugin _plugin;
  final _toques = StreamController<String>.broadcast();
  bool _inicializado = false;

  NotificationServiceImpl({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  @override
  bool get disponivel =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> inicializar() async {
    if (!disponivel || _inicializado) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // A permissao e pedida pela central de alertas, nao ao inicializar.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (resposta) {
        final payload = resposta.payload;
        if (payload != null) _toques.add(payload);
      },
    );
    _inicializado = true;
  }

  @override
  Future<bool> notificacoesPermitidas() async {
    if (!disponivel) return false;
    final android = _android;
    if (android != null) return await android.areNotificationsEnabled() ?? false;
    final opcoes = await _ios?.checkPermissions();
    return opcoes?.isEnabled ?? false;
  }

  @override
  Future<bool> solicitarPermissao() async {
    if (!disponivel) return false;
    final android = _android;
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return await _ios?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  @override
  Future<void> abrirConfiguracoes() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await _canal.invokeMethod<bool>('abrirConfiguracoes');
  }

  @override
  Future<void> mostrar({
    required int id,
    required String titulo,
    required String texto,
    required DateTime dataHora,
    bool urgente = false,
    String? payload,
  }) async {
    if (!disponivel) return;
    await _plugin.show(
      id: id,
      title: titulo,
      body: texto,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _idCanalAndroid,
          _nomeCanalAndroid,
          channelDescription: _descricaoCanalAndroid,
          // max: aparece por cima da tela (heads-up), mesmo com outro app aberto
          importance: Importance.max,
          priority: Priority.high,
          category: urgente ? AndroidNotificationCategory.alarm : null,
          color: _vermelho,
          // horario da leitura de BPM, nao o de quando a notificacao chegou
          when: dataHora.millisecondsSinceEpoch,
          styleInformation: BigTextStyleInformation(texto),
          ticker: titulo,
        ),
      ),
    );
  }

  @override
  Future<void> cancelar(int id) async {
    if (!disponivel) return;
    await _plugin.cancel(id: id);
  }

  @override
  Stream<String> get toques => _toques.stream;
}
