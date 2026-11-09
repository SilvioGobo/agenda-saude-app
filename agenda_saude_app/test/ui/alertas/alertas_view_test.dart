import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/data/repositories/preferencias_repository.dart';
import 'package:agenda_saude_app/domain/models/alerta.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/alertas/alertas_view.dart';
import 'package:agenda_saude_app/ui/alertas/alertas_viewmodel.dart';
import 'package:agenda_saude_app/ui/alertas/card_alerta.dart';
import 'package:agenda_saude_app/ui/alertas/emergencia_view.dart';
import 'package:agenda_saude_app/ui/configuracoes/configuracoes_viewmodel.dart';

import '../../core/services/fake_notification_service.dart';
import '../../core/services/fake_tts_service.dart';

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
    int minutosAtras = 3,
  }) {
    return dadosRepository.gerarAlerta(Alerta(
      id: '',
      pacienteId: 'paciente_01',
      tipo: tipo,
      mensagem: mensagem,
      bpm: bpm,
      dataHora: DateTime.now().subtract(Duration(minutes: minutosAtras)),
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

  testWidgets('Pendência de atividade aparece como PENDÊNCIA e os detalhes orientam a lembrar o paciente', (
    tester,
  ) async {
    await dadosRepository.gerarAlerta(Alerta(
      id: '',
      pacienteId: 'paciente_01',
      tipo: Alerta.tipoPendencia,
      mensagem: 'Não marcou como tomado o remédio das 08:00 (Losartana 50 mg).',
      dataHora: DateTime.now().subtract(const Duration(minutes: 3)),
    ));
    await montarTela(tester);

    expect(find.text('PENDÊNCIA'), findsOneWidget);
    expect(
      find.text('Não marcou como tomado o remédio das 08:00 (Losartana 50 mg).'),
      findsOneWidget,
    );

    await tester.tap(find.byType(CardAlerta));
    await tester.pumpAndSettle();

    // Nao e emergencia: abre a folha de detalhes, sem BPM.
    expect(find.byType(EmergenciaView), findsNothing);
    expect(find.text('O que fazer'), findsOneWidget);
    expect(find.textContaining('para lembrar José Silva'), findsOneWidget);
    expect(find.text('BPM', findRichText: true), findsNothing);
  });

  testWidgets('Aviso de sem dados do smartwatch aparece como SEM DADOS e os detalhes pedem o relógio no pulso', (
    tester,
  ) async {
    await dadosRepository.gerarAlerta(Alerta(
      id: '',
      pacienteId: 'paciente_01',
      tipo: Alerta.tipoSemDados,
      mensagem: 'O smartwatch não envia medições desde as 10:15. Peça a José '
          'para abrir o Agenda Saúde com o relógio no pulso.',
      dataHora: DateTime.now().subtract(const Duration(minutes: 3)),
    ));
    await montarTela(tester);

    expect(find.text('SEM DADOS'), findsOneWidget);
    expect(find.textContaining('desde as 10:15'), findsOneWidget);

    await tester.tap(find.byType(CardAlerta));
    await tester.pumpAndSettle();

    expect(find.byType(EmergenciaView), findsNothing);
    expect(find.textContaining('colocar o relógio no pulso'), findsOneWidget);
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
    // A localizacao so e oferecida nos alertas de emergencia.
    expect(find.text('Ver localização'), findsNothing);
    expect(viewModel.totalNaoLidos, 0);

    await tester.ensureVisible(find.text('Entendi'));
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma notificação nova.'), findsOneWidget);
  });

  testWidgets('Tocar no alerta de emergência abre a tela de emergência e volta à lista', (
    tester,
  ) async {
    await gerarAlerta(
      tipo: Alerta.tipoEmergencia,
      mensagem: 'Batimentos fora da zona de segurança há 6 minutos.',
      bpm: 132,
    );
    final viewModel = await montarTela(tester);

    await tester.tap(find.byType(CardAlerta));
    await tester.pumpAndSettle();

    expect(find.byType(EmergenciaView), findsOneWidget);
    expect(find.text('ALERTA CRÍTICO'), findsOneWidget);
    expect(find.text('132'), findsOneWidget);
    // José nao tem telefone cadastrado: so o SAMU e a localizacao.
    expect(find.text('LIGAR PARA JOSÉ'), findsNothing);
    await tester.scrollUntilVisible(find.text('VER LOCALIZAÇÃO'), 200);
    expect(find.text('LIGAR PARA O SAMU (192)'), findsOneWidget);
    expect(find.text('VER LOCALIZAÇÃO'), findsOneWidget);
    expect(viewModel.totalNaoLidos, 0);

    await tester.tap(find.text('Voltar'));
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

  group('Ouvir esta tela', () {
    late FakeTtsService tts;
    final ouvir = find.text('Ouvir esta tela');

    setUp(() => tts = FakeTtsService());

    // O narrador como o app o entrega: carregado e ligado.
    Future<ConfiguracoesViewModel> narradorLigado() async {
      SharedPreferences.setMockInitialValues({'narrador.ligado': true});
      final viewModel = ConfiguracoesViewModel(
        preferencias: PreferenciasRepository(),
        ttsService: tts,
      );
      await viewModel.carregar();
      return viewModel;
    }

    // Abre a tela como o painel a abre - empurrando a rota, que leva o
    // narrador junto - e devolve o ViewModel dos alertas.
    Future<AlertasViewModel> abrirComNarrador(
      WidgetTester tester,
      ConfiguracoesViewModel narrador,
    ) async {
      final viewModel = AlertasViewModel(
        dadosRepository: dadosRepository,
        notificationService: FakeNotificationService(),
      )..acompanharPacientes([jose]);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    AlertasView.rota(viewModel, narrador: narrador),
                  ),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      return viewModel;
    }

    testWidgets('Não deve aparecer sem narrador, como no painel do acompanhante hoje', (tester) async {
      await gerarAlerta();
      await montarTela(tester);

      expect(ouvir, findsNothing);
      expect(find.text('Notificações'), findsOneWidget);
    });

    testWidgets('Deve aparecer no topo da lista quando a rota leva o narrador', (tester) async {
      await gerarAlerta();
      await abrirComNarrador(tester, await narradorLigado());

      expect(ouvir, findsOneWidget);
      expect(
        tester.getTopLeft(ouvir).dy,
        lessThan(tester.getTopLeft(find.text('Você tem 1 notificação não lida.')).dy),
      );
    });

    testWidgets('Deve ler as não lidas, a mais nova primeiro', (tester) async {
      await gerarAlerta(minutosAtras: 4);
      await gerarAlerta(
        tipo: Alerta.tipoEmergencia,
        mensagem: 'Batimentos fora da zona de segurança há 6 minutos.',
        bpm: 125,
      );
      await abrirComNarrador(tester, await narradorLigado());

      await tester.tap(ouvir);
      await tester.pump();

      expect(
        tts.faladas.single,
        'Você tem 2 notificações não lidas. '
        'Emergência com José: 125 batimentos por minuto, há 3 minutos. '
        'José precisa de atenção: 118 batimentos por minuto, há 4 minutos.',
      );
    });

    testWidgets('Deve explicar quando ainda não há notificações', (tester) async {
      await abrirComNarrador(tester, await narradorLigado());

      await tester.tap(ouvir);
      await tester.pump();

      expect(tts.faladas.single, startsWith('Nenhuma notificação por enquanto.'));
    });

    testWidgets('Deve falar a emergência sozinha ao abri-la pela lista, com o narrador que veio junto', (tester) async {
      await gerarAlerta(
        tipo: Alerta.tipoEmergencia,
        mensagem: 'Batimentos fora da zona de segurança há 6 minutos.',
        bpm: 132,
      );
      await abrirComNarrador(tester, await narradorLigado());
      // A lista nao fala sozinha: so a emergencia.
      expect(tts.faladas, isEmpty);

      await tester.tap(find.byType(CardAlerta));
      await tester.pumpAndSettle();

      expect(find.byType(EmergenciaView), findsOneWidget);
      expect(
        tts.faladas.single,
        startsWith('Alerta crítico! José está com batimentos cardíacos elevados: 132'),
      );
    });

    testWidgets('Deve calar a leitura da lista ao abrir os detalhes de um alerta', (tester) async {
      await gerarAlerta();
      await abrirComNarrador(tester, await narradorLigado());
      await tester.tap(ouvir);
      await tester.pump();
      expect(find.text('Parar de ouvir'), findsOneWidget);

      await tester.tap(find.byType(CardAlerta));
      await tester.pumpAndSettle();

      expect(tts.paradas, 1);
    });
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
