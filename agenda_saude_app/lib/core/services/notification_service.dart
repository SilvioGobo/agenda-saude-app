import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

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

  // Tira a notificacao da bandeja e, se ela estava agendada, cancela o
  // agendamento tambem.
  Future<void> cancelar(int id);

  // Agenda um lembrete (RF 07.3) para [dataHora], no horario do aparelho. Ele
  // toca mesmo com o app fechado e volta a ser agendado sozinho quando o
  // celular reinicia. Agendar de novo o mesmo [id] troca o agendamento
  // anterior; [dataHora] precisa estar no futuro.
  Future<void> agendarLembrete({
    required int id,
    required String titulo,
    required String texto,
    required DateTime dataHora,
    String? payload,
  });

  // Ids das notificacoes agendadas que ainda nao tocaram e cujo payload comeca
  // com [prefixoDoPayload].
  Future<List<int>> idsAgendados({required String prefixoDoPayload});

  // No Android 12 ou mais novo o aviso so toca na hora exata se o usuario
  // permitir "Alarmes e lembretes" para o app; sem isso ele pode atrasar alguns
  // minutos. Nas demais plataformas nao ha essa restricao.
  Future<bool> alarmesExatosPermitidos();

  // Abre a tela do sistema em que o usuario permite os alarmes exatos.
  Future<void> solicitarAlarmesExatos();

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

  // Canal dos lembretes da rotina, separado do dos alertas: quem quiser pode
  // silenciar um sem desligar o outro.
  static const _idCanalLembretes = 'lembretes_rotina';
  static const _nomeCanalLembretes = 'Lembretes da rotina';
  static const _descricaoCanalLembretes =
      'Avisos para tomar os remédios e, para quem tem diabetes, medir a '
      'glicemia e aplicar a insulina nos horários combinados.';

  // Cor principal do tema (primary), para o icone da notificacao.
  static const _verdeAgua = Color(0xFF006B5F);

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
  Future<void> agendarLembrete({
    required int id,
    required String titulo,
    required String texto,
    required DateTime dataHora,
    String? payload,
  }) async {
    if (!disponivel) return;
    await _plugin.zonedSchedule(
      id: id,
      title: titulo,
      body: texto,
      payload: payload,
      // O instante exato, em UTC: nao depende de o banco de fusos do pacote
      // `timezone` ter sido carregado nem de qual e o fuso do aparelho. O Dart
      // ja converteu "08:00 de hoje" no horario do aparelho para este instante.
      scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.UTC,
        dataHora.millisecondsSinceEpoch,
      ),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _idCanalLembretes,
          _nomeCanalLembretes,
          channelDescription: _descricaoCanalLembretes,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          color: _verdeAgua,
          styleInformation: BigTextStyleInformation(texto),
          ticker: titulo,
        ),
      ),
      // Sem a permissao de alarme exato o Android recusaria o agendamento
      // exato: o aviso cai no modo aproximado, que ainda toca, so pode atrasar.
      androidScheduleMode: await alarmesExatosPermitidos()
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<List<int>> idsAgendados({required String prefixoDoPayload}) async {
    if (!disponivel) return const [];
    final agendadas = await _plugin.pendingNotificationRequests();
    return [
      for (final agendada in agendadas)
        if (agendada.payload?.startsWith(prefixoDoPayload) ?? false) agendada.id,
    ];
  }

  @override
  Future<bool> alarmesExatosPermitidos() async {
    if (!disponivel) return false;
    final android = _android;
    if (android == null) return true;
    return await android.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<void> solicitarAlarmesExatos() async {
    if (!disponivel) return;
    await _android?.requestExactAlarmsPermission();
  }

  @override
  Stream<String> get toques => _toques.stream;
}
