import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/services/notification_service.dart';

// Testa a implementacao real dos lembretes sem aparelho: o plugin conversa com o
// Android por um canal, e aqui o canal e trocado por um que anota as chamadas.
// Assim da para conferir o que realmente seria mandado ao sistema: o instante do
// aviso, o modo (exato ou aproximado) e o canal de notificacao.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationServiceImpl lembretes Testes', () {
    const canal = MethodChannel('dexterous.com/flutter/local_notifications');
    late List<MethodCall> chamadas;
    late bool alarmeExatoPermitido;
    late List<Map<String, Object?>> agendadasNoSistema;
    late NotificationServiceImpl servico;

    setUp(() {
      // Fora de um aparelho o teste roda como Android, mas o plugin so escolhe a
      // implementacao do Android quando o app registra; aqui registramos.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();

      chamadas = [];
      alarmeExatoPermitido = true;
      agendadasNoSistema = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(canal, (chamada) async {
        chamadas.add(chamada);
        switch (chamada.method) {
          case 'canScheduleExactNotifications':
            return alarmeExatoPermitido;
          case 'pendingNotificationRequests':
            return agendadasNoSistema;
        }
        return null;
      });
      servico = NotificationServiceImpl();
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(canal, null);
    });

    MethodCall chamadaDe(String metodo) =>
        chamadas.singleWhere((chamada) => chamada.method == metodo);

    Future<void> agendar(DateTime dataHora, {int id = 77}) {
      return servico.agendarLembrete(
        id: id,
        titulo: 'Hora do remédio',
        texto: 'Losartana 50 mg',
        dataHora: dataHora,
        payload: 'lembrete:remedio|m1|08:00@2026-11-20',
      );
    }

    test('Deve agendar o instante exato, em UTC, qualquer que seja o fuso do aparelho', () async {
      final dataHora = DateTime.now().add(const Duration(days: 2));

      await agendar(dataHora);

      final argumentos = chamadaDe('zonedSchedule').arguments as Map;
      expect(argumentos['id'], 77);
      expect(argumentos['title'], 'Hora do remédio');
      expect(argumentos['body'], 'Losartana 50 mg');
      expect(argumentos['payload'], 'lembrete:remedio|m1|08:00@2026-11-20');
      expect(argumentos['timeZoneName'], 'UTC');
      // O instante em UTC, sem os milissegundos: "2026-11-20T11:00:00".
      expect(
        argumentos['scheduledDateTime'],
        dataHora.toUtc().toIso8601String().split('.').first,
      );
    });

    test('Deve usar o canal de lembretes, separado do dos alertas', () async {
      await agendar(DateTime.now().add(const Duration(days: 1)));

      final especificos =
          (chamadaDe('zonedSchedule').arguments as Map)['platformSpecifics']
              as Map;
      expect(especificos['channelId'], 'lembretes_rotina');
      expect(especificos['channelName'], 'Lembretes da rotina');
    });

    test('Deve pedir o alarme exato quando o Android permite', () async {
      alarmeExatoPermitido = true;

      await agendar(DateTime.now().add(const Duration(days: 1)));

      final especificos =
          (chamadaDe('zonedSchedule').arguments as Map)['platformSpecifics']
              as Map;
      expect(especificos['scheduleMode'], 'exactAllowWhileIdle');
    });

    test('Deve cair no alarme aproximado, que ainda toca, sem a permissão de alarme exato', () async {
      alarmeExatoPermitido = false;

      await agendar(DateTime.now().add(const Duration(days: 1)));

      final especificos =
          (chamadaDe('zonedSchedule').arguments as Map)['platformSpecifics']
              as Map;
      expect(especificos['scheduleMode'], 'inexactAllowWhileIdle');
    });

    test('Deve recusar, sem mandar nada ao Android, uma data que já passou', () async {
      await expectLater(
        agendar(DateTime.now().subtract(const Duration(minutes: 5))),
        throwsArgumentError,
      );

      expect(chamadas.where((c) => c.method == 'zonedSchedule'), isEmpty);
    });

    test('Deve repetir o mesmo id para trocar o agendamento, sem acumular', () async {
      await agendar(DateTime.now().add(const Duration(days: 1)));
      await agendar(DateTime.now().add(const Duration(days: 2)));

      final ids = chamadas
          .where((c) => c.method == 'zonedSchedule')
          .map((c) => (c.arguments as Map)['id']);
      expect(ids, [77, 77]);
    });

    test('Deve listar só os ids dos agendamentos que são lembretes', () async {
      agendadasNoSistema = [
        {'id': 1, 'title': 'a', 'body': 'a', 'payload': 'lembrete:remedio|m1|08:00@2026-11-20'},
        {'id': 2, 'title': 'b', 'body': 'b', 'payload': 'outra-coisa'},
        {'id': 3, 'title': 'c', 'body': 'c', 'payload': 'lembrete:glicemia|Ao acordar@2026-11-20'},
        {'id': 4, 'title': 'd', 'body': 'd', 'payload': null},
      ];

      final ids = await servico.idsAgendados(prefixoDoPayload: 'lembrete:');

      expect(ids, [1, 3]);
    });

    test('Deve informar se o alarme exato está permitido', () async {
      alarmeExatoPermitido = false;
      expect(await servico.alarmesExatosPermitidos(), isFalse);

      alarmeExatoPermitido = true;
      expect(await servico.alarmesExatosPermitidos(), isTrue);
    });

    test('Deve abrir a tela do sistema para permitir os alarmes exatos', () async {
      await servico.solicitarAlarmesExatos();

      expect(chamadaDe('requestExactAlarmsPermission'), isNotNull);
    });

    test('Deve cancelar pelo id, o que tira da bandeja e desfaz o agendamento', () async {
      await servico.cancelar(77);

      final argumentos = chamadaDe('cancel').arguments as Map;
      expect(argumentos['id'], 77);
    });

    test('Não deve fazer nada em plataforma sem notificação do sistema', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      await agendar(DateTime.now().add(const Duration(days: 1)));
      await servico.solicitarAlarmesExatos();

      expect(servico.disponivel, isFalse);
      expect(chamadas, isEmpty);
      expect(await servico.idsAgendados(prefixoDoPayload: 'lembrete:'), isEmpty);
      expect(await servico.alarmesExatosPermitidos(), isFalse);
    });
  });
}
