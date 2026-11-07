import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/acompanhante_repository.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/data/repositories/relatorios_repository.dart';
import 'package:agenda_saude_app/domain/models/acompanhante.dart';
import 'package:agenda_saude_app/domain/models/alerta.dart';
import 'package:agenda_saude_app/domain/models/batimento_cardiaco.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_agua.dart';
import 'package:agenda_saude_app/domain/models/registro_diabete.dart';
import 'package:agenda_saude_app/ui/acompanhante/acompanhante_view.dart';
import 'package:agenda_saude_app/ui/insulina/formatacao_diabete.dart';

import '../../core/services/fake_notification_service.dart';
import '../../core/services/fake_push_service.dart';

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

  Future<void> montarPainel(
    WidgetTester tester, {
    FakePushService? pushService,
  }) async {
    final acompanhante =
        (await acompanhanteRepository.getAcompanhante('cuidador_01'))!;
    await tester.pumpWidget(
      MaterialApp(
        home: AcompanhanteView.comProviders(
          acompanhante,
          acompanhanteRepository: acompanhanteRepository,
          dadosRepository: dadosRepository,
          relatoriosRepository: RelatoriosRepository(firestore: fakeFirestore),
          notificationService: notificationService,
          pushService: pushService,
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

    // Tela alta o bastante para os dois cards (com BPM e status) ja ficarem
    // montados sem rolar.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await montarPainel(tester);

    expect(find.text('Você acompanha 2 pacientes.'), findsOneWidget);
    expect(find.text('José Silva'), findsOneWidget);
    expect(find.text('Diabetes'), findsOneWidget);
    expect(find.text('Maria Souza'), findsOneWidget);
    expect(find.text('Triagem pendente'), findsOneWidget);
    // Cada card tem os atalhos para os relatorios e para a localizacao.
    expect(find.text('Ver relatórios'), findsNWidgets(2));
    expect(find.text('Ver localização'), findsNWidgets(2));
  });

  testWidgets('Botão "Ver relatórios" abre os relatórios do paciente, com o nome dele, e volta ao painel', (
    tester,
  ) async {
    await vincularJose();
    final ontem = DateTime.now().subtract(const Duration(days: 1));
    await dadosRepository.salvarRegistro(RegistroAgua(
      id: '',
      pacienteId: 'paciente_01',
      dataHora: DateTime(ontem.year, ontem.month, ontem.day, 9),
      quantidadeML: 250,
    ));
    await montarPainel(tester);

    await tester.ensureVisible(find.text('Ver relatórios'));
    await tester.tap(find.text('Ver relatórios'));
    await tester.pumpAndSettle();

    expect(find.text('Relatórios de José'), findsOneWidget);
    expect(find.text('Meus relatórios'), findsNothing);
    expect(find.text('Ontem'), findsOneWidget);
    expect(find.text('Mês'), findsOneWidget);
    // Os dados de ontem do paciente.
    expect(find.text('250 ml de 2.000 ml'), findsOneWidget);

    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('Monitoramento'), findsOneWidget);
    expect(find.text('José Silva'), findsOneWidget);
  });

  testWidgets('Card do paciente diabético mostra a última glicemia e a última dose de insulina', (
    tester,
  ) async {
    await PacienteRepository(firestore: fakeFirestore).salvarPaciente(Paciente(
      id: 'paciente_01',
      nome: 'José Silva',
      email: 'jose@email.com',
      perfil: 'Paciente',
      possuiDiabetes: true,
      tipoDiabetes: 'Tipo 1',
      usaInsulina: true,
      possuiCardiopatia: false,
      codigoVinculo: 'ABC123',
      triagemConcluida: true,
    ));
    await acompanhanteRepository.vincularPaciente('cuidador_01', 'paciente_01');
    final ontem = DateTime.now().subtract(const Duration(days: 1));
    await dadosRepository.salvarRegistro(RegistroDiabete(
      id: '',
      pacienteId: 'paciente_01',
      dataHora: DateTime(ontem.year, ontem.month, ontem.day, 22, 0),
      momento: 'Insulina lenta (22h)',
      doseInsulina: 14,
      tipoInsulina: 'Lenta',
    ));
    await dadosRepository.salvarRegistro(RegistroDiabete(
      id: '',
      pacienteId: 'paciente_01',
      dataHora: DateTime.now().subtract(const Duration(minutes: 5)),
      nivelGlicose: 62,
      momento: 'Ao acordar',
    ));

    await montarPainel(tester);

    expect(find.text('GLICEMIA: ${formatarGlicemia(62)}'), findsOneWidget);
    expect(find.text('BAIXA'), findsOneWidget);
    expect(find.text('AO ACORDAR · HÁ 5 MINUTOS'), findsOneWidget);
    expect(find.text(descreverInsulina('Lenta', 14).toUpperCase()), findsOneWidget);
    // A glicemia e a ultima atividade, mas ja aparece no resumo: sem repetir.
    expect(find.textContaining('MEDIU A GLICEMIA'), findsNothing);
    expect(find.textContaining('ÚLTIMA ATIVIDADE'), findsNothing);
    expect(find.text('INSULINA LENTA (22\u00A0HORAS) · ONTEM ÀS 22:00'), findsOneWidget);
  });

  Future<void> salvarBatimento(int bpm, DateTime timestamp) {
    return dadosRepository.salvarBatimento(BatimentoCardiaco(
      id: '',
      pacienteId: 'paciente_01',
      bpm: bpm,
      timestamp: timestamp,
    ));
  }

  testWidgets('Card mostra o BPM mais recente, há quanto tempo foi medido e o status ESTÁVEL', (
    tester,
  ) async {
    await vincularJose();
    await salvarBatimento(72, DateTime.now().subtract(const Duration(minutes: 3)));
    await montarPainel(tester);

    expect(find.text('72'), findsOneWidget);
    expect(find.text('BPM'), findsOneWidget);
    expect(find.text('HÁ 3 MINUTOS'), findsOneWidget);
    expect(find.text('ESTÁVEL'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Batimentos: 72 por minuto, medidos há 3 minutos.'),
      findsOneWidget,
    );
  });

  testWidgets('Card muda para ATENÇÃO em tempo real quando o smartwatch mede fora da zona', (
    tester,
  ) async {
    await vincularJose();
    await salvarBatimento(72, DateTime.now().subtract(const Duration(minutes: 3)));
    await montarPainel(tester);
    expect(find.text('ESTÁVEL'), findsOneWidget);

    // O app do paciente grava uma leitura nova: o card muda sem recarregar.
    await salvarBatimento(128, DateTime.now());
    await tester.pumpAndSettle();

    expect(find.text('128'), findsOneWidget);
    expect(find.text('AGORA MESMO'), findsOneWidget);
    expect(find.text('ATENÇÃO'), findsOneWidget);
    expect(find.text('ESTÁVEL'), findsNothing);
    expect(
      find.text('Acima da zona de segurança (60 a 100 batimentos por minuto).'),
      findsOneWidget,
    );
  });

  testWidgets('Card mostra SEM DADOS quando o smartwatch nunca enviou medição', (
    tester,
  ) async {
    await vincularJose();
    await montarPainel(tester);

    expect(find.text('NENHUMA MEDIÇÃO DE BATIMENTOS'), findsOneWidget);
    expect(find.text('SEM DADOS'), findsOneWidget);
    expect(
      find.textContaining('Peça a José para abrir o Agenda Saúde'),
      findsOneWidget,
    );
  });

  testWidgets('Card mostra SEM DADOS e o horário quando a última leitura é antiga', (
    tester,
  ) async {
    await vincularJose();
    final ontem = DateTime.now().subtract(const Duration(days: 1));
    await salvarBatimento(72, DateTime(ontem.year, ontem.month, ontem.day, 9, 15));
    await montarPainel(tester);

    expect(find.text('72'), findsOneWidget);
    expect(find.text('ONTEM ÀS 09:15'), findsOneWidget);
    expect(find.text('SEM DADOS'), findsOneWidget);
    expect(find.text('ESTÁVEL'), findsNothing);
    expect(find.textContaining('há mais de uma hora'), findsOneWidget);
  });

  testWidgets('Card mostra a última atividade da rotina do paciente', (
    tester,
  ) async {
    await vincularJose();
    await dadosRepository.salvarRegistro(RegistroAgua(
      id: '',
      pacienteId: 'paciente_01',
      dataHora: DateTime.now().subtract(const Duration(minutes: 10)),
      quantidadeML: 250,
    ));
    await montarPainel(tester);

    expect(find.text('BEBEU ÁGUA: 250 ML'), findsOneWidget);
    expect(find.text('ÚLTIMA ATIVIDADE · HÁ 10 MINUTOS'), findsOneWidget);
  });

  testWidgets('Card com BPM, status e última atividade não estoura com a fonte em 200%', (
    tester,
  ) async {
    // Celular pequeno (360x640) com a fonte no maximo: overflow reprova.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await PacienteRepository(firestore: fakeFirestore).salvarPaciente(Paciente(
      id: 'paciente_01',
      nome: 'José da Silva Albuquerque',
      email: 'jose@email.com',
      perfil: 'Paciente',
      possuiDiabetes: true,
      usaInsulina: true,
      possuiCardiopatia: true,
      codigoVinculo: 'ABC123',
      triagemConcluida: true,
    ));
    await acompanhanteRepository.vincularPaciente('cuidador_01', 'paciente_01');
    await salvarBatimento(128, DateTime.now().subtract(const Duration(minutes: 2)));
    await dadosRepository.salvarRegistro(RegistroDiabete(
      id: '',
      pacienteId: 'paciente_01',
      dataHora: DateTime.now().subtract(const Duration(minutes: 1)),
      nivelGlicose: 112,
      momento: 'Antes do almoço',
      doseInsulina: 6,
      tipoInsulina: 'Rápida',
    ));

    final acompanhante =
        (await acompanhanteRepository.getAcompanhante('cuidador_01'))!;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: AcompanhanteView.comProviders(
          acompanhante,
          acompanhanteRepository: acompanhanteRepository,
          dadosRepository: dadosRepository,
          relatoriosRepository: RelatoriosRepository(firestore: fakeFirestore),
          notificationService: notificationService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('ATENÇÃO'), 200);
    await tester.scrollUntilVisible(
      find.text(descreverInsulina('Rápida', 6).toUpperCase()),
      200,
    );
    await tester.scrollUntilVisible(find.text('Ver localização'), 200);
    expect(find.text('Ver localização'), findsOneWidget);
  });

  testWidgets('Card do paciente sem diabetes não mostra glicemia', (
    tester,
  ) async {
    await vincularJose();
    await montarPainel(tester);

    expect(find.text('José Silva'), findsOneWidget);
    expect(find.textContaining('GLICEMIA'), findsNothing);
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

  testWidgets('Tocar na notificação de emergência abre a tela de emergência com o botão de ligar', (
    tester,
  ) async {
    await PacienteRepository(firestore: fakeFirestore).salvarPaciente(Paciente(
      id: 'paciente_01',
      nome: 'José Silva',
      email: 'jose@email.com',
      perfil: 'Paciente',
      telefone: '67999990000',
      possuiDiabetes: false,
      possuiCardiopatia: false,
      codigoVinculo: 'ABC123',
    ));
    await acompanhanteRepository.vincularPaciente('cuidador_01', 'paciente_01');
    await montarPainel(tester);
    await dadosRepository.gerarAlerta(Alerta(
      id: '',
      pacienteId: 'paciente_01',
      tipo: Alerta.tipoEmergencia,
      mensagem: 'Batimentos fora da zona de segurança há 6 minutos '
          '(última leitura: 128 BPM).',
      bpm: 128,
      dataHora: DateTime.now(),
    ));
    await tester.pumpAndSettle();
    final notificacao = notificationService.mostradas.single;
    expect(notificacao.titulo, 'Emergência: José Silva');
    expect(notificacao.urgente, isTrue);

    notificationService.simularToque(notificacao.payload!);
    await tester.pumpAndSettle();

    expect(find.text('ALERTA CRÍTICO'), findsOneWidget);
    expect(find.text('BATIMENTOS CARDÍACOS ELEVADOS'), findsOneWidget);
    expect(find.text('128'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('LIGAR PARA O SAMU (192)'), 200);
    expect(find.text('LIGAR PARA JOSÉ'), findsOneWidget);
    expect(find.text('LIGAR PARA O SAMU (192)'), findsOneWidget);

    // "Voltar" leva para a lista de notificacoes, com o alerta ja lido.
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Notificações'), findsOneWidget);
    expect(find.text('Nenhuma notificação nova.'), findsOneWidget);
  });

  testWidgets('Painel registra este aparelho para receber o push dos alertas', (
    tester,
  ) async {
    await montarPainel(tester, pushService: FakePushService());

    final doc = await fakeFirestore.collection('usuarios').doc('cuidador_01').get();
    expect(doc.data()!['fcmTokens'], ['token_aparelho_01']);
  });

  testWidgets('Tocar no push de emergência com o app fechado abre a tela de emergência', (
    tester,
  ) async {
    await PacienteRepository(firestore: fakeFirestore).salvarPaciente(Paciente(
      id: 'paciente_01',
      nome: 'José Silva',
      email: 'jose@email.com',
      perfil: 'Paciente',
      telefone: '67999990000',
      possuiDiabetes: false,
      possuiCardiopatia: false,
      codigoVinculo: 'ABC123',
    ));
    await acompanhanteRepository.vincularPaciente('cuidador_01', 'paciente_01');
    // O alerta que gerou o push ja existe; o app abre pelo toque na
    // notificacao e ainda precisa carregar os pacientes e os alertas.
    await fakeFirestore.collection('alertas').doc('alerta_push').set(Alerta(
      id: '',
      pacienteId: 'paciente_01',
      tipo: Alerta.tipoEmergencia,
      mensagem: 'Batimentos fora da zona de segurança há 6 minutos '
          '(última leitura: 128 BPM).',
      bpm: 128,
      dataHora: DateTime.now(),
    ).toJson());
    notificationService.payloadDeAbertura = 'alerta_push';

    await montarPainel(tester, pushService: FakePushService());

    expect(find.text('ALERTA CRÍTICO'), findsOneWidget);
    expect(find.text('128'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('LIGAR PARA O SAMU (192)'), 200);
    expect(find.text('LIGAR PARA JOSÉ'), findsOneWidget);
    // O alerta ja existia: abrir a tela nao gera outra notificacao.
    expect(notificationService.mostradas, isEmpty);
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
