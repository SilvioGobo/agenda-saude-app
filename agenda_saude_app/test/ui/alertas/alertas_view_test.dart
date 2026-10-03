import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/alerta.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/alertas/alertas_view.dart';
import 'package:agenda_saude_app/ui/alertas/alertas_viewmodel.dart';
import 'package:agenda_saude_app/ui/alertas/card_alerta.dart';

import '../../core/services/fake_notification_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late DadosMedicosRepository dadosRepository;

  final jose = Paciente(
    id: 'paciente_01',
    nome: 'José Silva',
    email: 'jose@email.com',
    perfil: 'Paciente',
    possuiDiabetes: false,
    possuiCardiopatia: false,
    codigoVinculo: 'ABC123',
  );

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
  });

  Future<void> gerarAlerta({
    String tipo = Alerta.tipoAtencao,
    String mensagem = 'Batimentos acima da zona de segurança (118 BPM).',
    int bpm = 118,
  }) {
    return dadosRepository.gerarAlerta(Alerta(
      id: '',
      pacienteId: 'paciente_01',
      tipo: tipo,
      mensagem: mensagem,
      bpm: bpm,
      dataHora: DateTime.now().subtract(const Duration(minutes: 3)),
    ));
  }

  Future<AlertasViewModel> montarTela(WidgetTester tester) async {
    final viewModel = AlertasViewModel(
      dadosRepository: dadosRepository,
      notificationService: FakeNotificationService(),
    )..acompanharPacientes([jose]);
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: viewModel,
          child: const AlertasView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return viewModel;
  }

  testWidgets('Tela de notificações orienta quando ainda não há alertas', (
    tester,
  ) async {
    await montarTela(tester);

    expect(find.text('Notificações'), findsOneWidget);
    expect(find.text('Nenhuma notificação nova.'), findsOneWidget);
    expect(find.textContaining('Nenhum alerta por enquanto'), findsOneWidget);
    expect(find.text('Marcar todas como lidas'), findsNothing);
  });

  testWidgets('Tela de notificações lista os alertas com nível, paciente e horário', (
    tester,
  ) async {
    await gerarAlerta();
    await gerarAlerta(
      tipo: Alerta.tipoEmergencia,
      mensagem: 'Batimentos fora da zona de segurança há 6 minutos '
          '(última leitura: 125 BPM).',
      bpm: 125,
    );

    await montarTela(tester);

    expect(find.text('Você tem 2 notificações não lidas.'), findsOneWidget);
    expect(find.byType(CardAlerta), findsNWidgets(2));
    expect(find.text('ATENÇÃO'), findsOneWidget);
    expect(find.text('EMERGÊNCIA'), findsOneWidget);
    expect(find.text('José Silva'), findsNWidgets(2));
    expect(find.text('Há 3 minutos'), findsNWidgets(2));
    expect(find.text('Marcar todas como lidas'), findsOneWidget);
  });

  testWidgets('Tocar no alerta abre os detalhes e marca como lido', (
    tester,
  ) async {
    await gerarAlerta();
    final viewModel = await montarTela(tester);

    await tester.tap(find.byType(CardAlerta));
    await tester.pumpAndSettle();

    expect(find.text('118 BPM', findRichText: true), findsOneWidget);
    expect(find.text('O que fazer'), findsOneWidget);
    expect(find.textContaining('Entre em contato'), findsOneWidget);
    expect(viewModel.totalNaoLidos, 0);

    await tester.ensureVisible(find.text('Entendi'));
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma notificação nova.'), findsOneWidget);
  });

  testWidgets('Botão "Marcar todas como lidas" zera as não lidas', (
    tester,
  ) async {
    await gerarAlerta();
    await gerarAlerta();
    await montarTela(tester);

    await tester.tap(find.text('Marcar todas como lidas'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma notificação nova.'), findsOneWidget);
    expect(find.text('Marcar todas como lidas'), findsNothing);
    final salvos = await dadosRepository.getAlertas('paciente_01');
    expect(salvos.every((a) => a.lido), true);
  });

  group('descreverHorario Testes', () {
    final agora = DateTime(2026, 9, 19, 14, 30);

    test('Deve descrever horários recentes em minutos', () {
      expect(descreverHorario(agora, agora: agora), 'Agora mesmo');
      expect(
        descreverHorario(agora.subtract(const Duration(minutes: 1)), agora: agora),
        'Há 1 minuto',
      );
      expect(
        descreverHorario(agora.subtract(const Duration(minutes: 45)), agora: agora),
        'Há 45 minutos',
      );
    });

    test('Deve descrever horários mais antigos pelo dia', () {
      expect(
        descreverHorario(DateTime(2026, 9, 19, 9, 5), agora: agora),
        'Hoje às 09:05',
      );
      expect(
        descreverHorario(DateTime(2026, 9, 18, 21, 0), agora: agora),
        'Ontem às 21:00',
      );
      expect(
        descreverHorario(DateTime(2026, 9, 10, 7, 30), agora: agora),
        '10/09 às 07:30',
      );
    });
  });
}
