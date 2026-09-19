import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/data/repositories/acompanhante_repository.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/domain/models/acompanhante.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/acompanhante/acompanhante_view.dart';
import 'package:agenda_saude_app/ui/acompanhante/acompanhante_viewmodel.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late AcompanhanteRepository acompanhanteRepository;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    acompanhanteRepository = AcompanhanteRepository(firestore: fakeFirestore);
    await acompanhanteRepository.salvarAcompanhante(Acompanhante(
      id: 'cuidador_01',
      nome: 'Carlos Souza',
      email: 'carlos@email.com',
      perfil: 'Acompanhante',
      pacientesVinculadosIds: [],
    ));
  });

  Future<void> montarPainel(WidgetTester tester) async {
    final acompanhante =
        (await acompanhanteRepository.getAcompanhante('cuidador_01'))!;
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => AcompanhanteViewModel(
            acompanhante: acompanhante,
            acompanhanteRepository: acompanhanteRepository,
          )..carregarPacientes(),
          child: const AcompanhanteView(),
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
}
