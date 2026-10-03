import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/acompanhante_repository.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/domain/models/acompanhante.dart';
import 'package:agenda_saude_app/domain/models/alerta.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/acompanhante/acompanhante_view.dart';

import '../../core/services/fake_notification_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late AcompanhanteRepository acompanhanteRepository;
  late DadosMedicosRepository dadosRepository;
  late FakeNotificationService notificationService;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    acompanhanteRepository = AcompanhanteRepository(firestore: fakeFirestore);
    dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
    notificationService = FakeNotificationService();
    await acompanhanteRepository.salvarAcompanhante(Acompanhante(
      id: 'cuidador_01',
      nome: 'Carlos Souza',
      email: 'carlos@email.com',
      perfil: 'Acompanhante',
      pacientesVinculadosIds: [],
    ));
  });

  Future<void> vincularJose() async {
    await PacienteRepository(firestore: fakeFirestore).salvarPaciente(Paciente(
      id: 'paciente_01',
      nome: 'José Silva',
      email: 'jose@email.com',
      perfil: 'Paciente',
      possuiDiabetes: false,
      possuiCardiopatia: false,
      codigoVinculo: 'ABC123',
    ));
    await acompanhanteRepository.vincularPaciente('cuidador_01', 'paciente_01');
  }

  Future<void> gerarAlertaDeAtencao() {
    return dadosRepository.gerarAlerta(Alerta(
      id: '',
      pacienteId: 'paciente_01',
      tipo: Alerta.tipoAtencao,
      mensagem: 'Batimentos acima da zona de segurança (118 BPM).',
      bpm: 118,
      dataHora: DateTime.now(),
    ));
  }

  Future<void> montarPainel(WidgetTester tester) async {
    final acompanhante =
        (await acompanhanteRepository.getAcompanhante('cuidador_01'))!;
    await tester.pumpWidget(
      MaterialApp(
        home: AcompanhanteView.comProviders(
          acompanhante,
          acompanhanteRepository: acompanhanteRepository,
          dadosRepository: dadosRepository,
          notificationService: notificationService,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Painel do acompanhante mostra saudação, orientação e botão de vincular quando não há pacientes', (
    tester,
  ) async {
    await montarPainel(tester);

    expect(find.text('Monitoramento'), findsOneWidget);
    expect(find.text('Olá, Carlos'), findsOneWidget);
    expect(find.text('Você ainda não acompanha nenhum paciente.'), findsOneWidget);
    expect(find.textContaining('Peça ao paciente o código de vínculo'), findsOneWidget);
    expect(find.text('Vincular paciente'), findsOneWidget);
    expect(find.byTooltip('Notificações'), findsOneWidget);
  });

  testWidgets('Painel do acompanhante lista os pacientes vinculados em cards', (
    tester,
  ) async {
    final pacienteRepository = PacienteRepository(firestore: fakeFirestore);
    await pacienteRepository.salvarPaciente(Paciente(
      id: 'paciente_01',
      nome: 'José Silva',
      email: 'jose@email.com',
      perfil: 'Paciente',
      possuiDiabetes: true,
      possuiCardiopatia: false,
      codigoVinculo: 'ABC123',
      triagemConcluida: true,
    ));
    await pacienteRepository.salvarPaciente(Paciente(
      id: 'paciente_02',
      nome: 'Maria Souza',
      email: 'maria@email.com',
      perfil: 'Paciente',
      possuiDiabetes: false,
      possuiCardiopatia: false,
      codigoVinculo: 'XYZ789',
    ));
    await acompanhanteRepository.vincularPaciente('cuidador_01', 'paciente_01');
    await acompanhanteRepository.vincularPaciente('cuidador_01', 'paciente_02');

    await montarPainel(tester);

    expect(find.text('Você acompanha 2 pacientes.'), findsOneWidget);
    expect(find.text('José Silva'), findsOneWidget);
    expect(find.text('Diabetes'), findsOneWidget);
    expect(find.text('Maria Souza'), findsOneWidget);
    expect(find.text('Triagem pendente'), findsOneWidget);
  });

  testWidgets('Desvincular pelo menu do card pede confirmação e remove o paciente', (
    tester,
  ) async {
    await vincularJose();
    await montarPainel(tester);
    expect(find.text('José Silva'), findsOneWidget);

    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desvincular'));
    await tester.pumpAndSettle();

    expect(find.text('Desvincular paciente?'), findsOneWidget);

    // O dialogo tem um botao "Desvincular" proprio; o do menu ja fechou.
    await tester.tap(find.widgetWithText(TextButton, 'Desvincular'));
    await tester.pumpAndSettle();

    expect(find.text('José Silva foi desvinculado.'), findsOneWidget);
    expect(find.text('Você ainda não acompanha nenhum paciente.'), findsOneWidget);
    final salvo = await acompanhanteRepository.getAcompanhante('cuidador_01');
    expect(salvo!.pacientesVinculadosIds, isEmpty);
  });

  testWidgets('Alerta de "Atenção" do paciente chega em tempo real no painel e como notificação', (
    tester,
  ) async {
    await vincularJose();
    await montarPainel(tester);
    expect(find.text('José Silva precisa de atenção'), findsNothing);

    await gerarAlertaDeAtencao();
    await tester.pumpAndSettle();

    expect(find.text('José Silva precisa de atenção'), findsOneWidget);
    expect(
      find.text('Batimentos acima da zona de segurança (118 BPM).'),
      findsOneWidget,
    );
    expect(find.text('1 alerta não lido'), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // contador do sino
    expect(notificationService.mostradas.single.titulo, 'Atenção: José Silva');
  });

  testWidgets('Botão "Ver notificações" abre a lista de alertas', (
    tester,
  ) async {
    await vincularJose();
    await gerarAlertaDeAtencao();
    await montarPainel(tester);

    await tester.tap(find.text('Ver notificações'));
    await tester.pumpAndSettle();

    expect(find.text('Notificações'), findsOneWidget);
    expect(find.text('Você tem 1 notificação não lida.'), findsOneWidget);
  });

  testWidgets('Tocar na notificação abre os detalhes do alerta', (
    tester,
  ) async {
    await vincularJose();
    await montarPainel(tester);
    await gerarAlertaDeAtencao();
    await tester.pumpAndSettle();

    notificationService.simularToque(notificationService.mostradas.single.payload!);
    await tester.pumpAndSettle();

    expect(find.text('Notificações'), findsOneWidget);
    expect(find.text('O que fazer'), findsOneWidget);
    expect(find.text('118 BPM', findRichText: true), findsOneWidget);
  });

  testWidgets('Painel pede para ativar as notificações quando estão bloqueadas', (
    tester,
  ) async {
    notificationService
      ..permitidas = false
      ..concederAoSolicitar = false;
    await vincularJose();
    await montarPainel(tester);

    expect(find.text('Notificações desativadas'), findsOneWidget);

    await tester.ensureVisible(find.text('Ativar notificações'));
    await tester.tap(find.text('Ativar notificações'));
    await tester.pumpAndSettle();

    expect(notificationService.aberturasDasConfiguracoes, 1);
  });
}
