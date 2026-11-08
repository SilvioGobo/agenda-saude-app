import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/services/notification_service.dart';
import 'package:agenda_saude_app/core/services/push_service.dart';

import 'fake_notification_service.dart';

void main() {
  final medidoEm = DateTime(2026, 11, 7, 10, 30);

  // Dados como a Cloud Function manda (functions/notificacao.js): tudo texto.
  Map<String, dynamic> dadosDoPush({
    String tipo = AlertaPush.tipoDaMensagem,
    String? alertaId = 'alerta_01',
    String? acompanhanteId = 'cuidador_01',
    String? nivel = 'emergencia',
  }) {
    return {
      'tipo': tipo,
      if (alertaId != null) 'alertaId': alertaId,
      'pacienteId': 'paciente_01',
      if (acompanhanteId != null) 'acompanhanteId': acompanhanteId,
      if (nivel != null) 'nivel': nivel,
      'titulo': 'Emergência: José Silva',
      'texto': 'Batimentos fora da zona de segurança há 6 minutos '
          '(última leitura: 128 BPM).',
      'dataHora': '${medidoEm.millisecondsSinceEpoch}',
    };
  }

  group('AlertaPush Testes', () {
    test('Deve ler os dados do push de um alerta', () {
      final alerta = AlertaPush.daMensagem(dadosDoPush())!;

      expect(alerta.alertaId, 'alerta_01');
      expect(alerta.pacienteId, 'paciente_01');
      expect(alerta.acompanhanteId, 'cuidador_01');
      expect(alerta.ehEmergencia, true);
      expect(alerta.titulo, 'Emergência: José Silva');
      expect(alerta.texto, contains('128 BPM'));
      expect(alerta.dataHora, medidoEm);
    });

    test('Deve reconhecer o push de "Atenção"', () {
      final alerta = AlertaPush.daMensagem(dadosDoPush(nivel: 'atencao'))!;

      expect(alerta.ehEmergencia, false);
    });

    test('Deve tratar o push sem nível como emergência', () {
      final alerta = AlertaPush.daMensagem(dadosDoPush(nivel: null))!;

      expect(alerta.ehEmergencia, true);
    });

    test('Não deve tratar o push de pendência de atividade como emergência', () {
      final alerta = AlertaPush.daMensagem(dadosDoPush(nivel: 'pendencia'))!;

      expect(alerta.nivel, 'pendencia');
      expect(alerta.ehEmergencia, false);
    });

    test('Deve ignorar mensagem que não é de alerta', () {
      expect(AlertaPush.daMensagem(dadosDoPush(tipo: 'outra_coisa')), isNull);
      expect(AlertaPush.daMensagem({}), isNull);
    });

    test('Deve ignorar push sem o id do alerta ou do acompanhante', () {
      expect(AlertaPush.daMensagem(dadosDoPush(alertaId: null)), isNull);
      expect(AlertaPush.daMensagem(dadosDoPush(acompanhanteId: null)), isNull);
    });
  });

  group('mostrarAlertaDoPush Testes', () {
    late FakeNotificationService notificacoes;
    final alerta = AlertaPush.daMensagem(dadosDoPush())!;

    setUp(() {
      notificacoes = FakeNotificationService();
    });

    test('Deve mostrar o alerta ao acompanhante logado, com o id e o payload do alerta', () async {
      final mostrou = await mostrarAlertaDoPush(
        alerta,
        uidLogado: 'cuidador_01',
        notificacoes: notificacoes,
      );

      expect(mostrou, true);
      expect(notificacoes.inicializacoes, 1);
      final notificacao = notificacoes.mostradas.single;
      // Mesmo id da escuta do app: um substitui o outro, sem duplicar.
      expect(notificacao.id, idDaNotificacaoDoAlerta('alerta_01'));
      expect(notificacao.titulo, 'Emergência: José Silva');
      expect(notificacao.urgente, true);
      expect(notificacao.payload, 'alerta_01');
    });

    test('Não deve mostrar o alerta com ninguém logado no aparelho', () async {
      final mostrou = await mostrarAlertaDoPush(
        alerta,
        uidLogado: null,
        notificacoes: notificacoes,
      );

      expect(mostrou, false);
      expect(notificacoes.mostradas, isEmpty);
    });

    test('Não deve mostrar o alerta a outra conta logada no aparelho (NF005)', () async {
      final mostrou = await mostrarAlertaDoPush(
        alerta,
        uidLogado: 'outro_usuario',
        notificacoes: notificacoes,
      );

      expect(mostrou, false);
      expect(notificacoes.mostradas, isEmpty);
    });
  });
}
