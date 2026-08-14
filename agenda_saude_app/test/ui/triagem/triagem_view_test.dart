import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/triagem/triagem_view.dart';
import 'package:agenda_saude_app/ui/triagem/triagem_viewmodel.dart';

Future<void> _montarTela(WidgetTester tester) async {
  final pacienteRecemCadastrado = Paciente(
    id: 'paciente_001',
    nome: 'Maria Souza',
    email: 'maria@email.com',
    perfil: 'Paciente',
    possuiDiabetes: false,
    possuiCardiopatia: false,
    codigoVinculo: 'ABC123',
  );

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider(
        create: (_) => TriagemViewModel(
          paciente: pacienteRecemCadastrado,
          pacienteRepository:
              PacienteRepository(firestore: FakeFirebaseFirestore()),
        ),
        child: const TriagemView(),
      ),
    ),
  );
}

void main() {
  testWidgets('Tela de triagem mostra os dados gerais e as perguntas de diabetes/cardiopatia', (
    tester,
  ) async {
    await _montarTela(tester);

    expect(find.text('Sobre você'), findsOneWidget);
    expect(find.text('Data de nascimento'), findsOneWidget);
    expect(find.text('Sexo biológico'), findsOneWidget);
    expect(find.text('Altura (cm)'), findsOneWidget);
    expect(find.text('Peso (kg)'), findsOneWidget);
    expect(find.text('Nível de atividade física habitual'), findsOneWidget);
    expect(find.text('Você possui diabetes?'), findsOneWidget);
    expect(find.text('Você possui alguma cardiopatia?'), findsOneWidget);
    expect(find.text('Alergias e restrições alimentares'), findsOneWidget);
    expect(find.text('Medicamentos em uso contínuo'), findsOneWidget);
    expect(find.text('Concluir'), findsOneWidget);
    expect(find.text('Usa insulina?'), findsNothing);
    expect(find.text('Usa marcapasso?'), findsNothing);
  });

  testWidgets('Deve mostrar as perguntas extras de diabetes só depois de responder Sim', (
    tester,
  ) async {
    await _montarTela(tester);

    await tester.ensureVisible(find.text('Sim').first);
    await tester.tap(find.text('Sim').first);
    await tester.pump();

    expect(find.text('Qual tipo?'), findsOneWidget);
    expect(find.text('Usa insulina?'), findsOneWidget);
  });

  testWidgets('Deve mostrar as perguntas extras de cardiopatia só depois de responder Sim', (
    tester,
  ) async {
    await _montarTela(tester);

    await tester.ensureVisible(find.text('Sim').last);
    await tester.tap(find.text('Sim').last);
    await tester.pump();

    expect(find.text('Qual? (opcional)'), findsOneWidget);
    expect(find.text('Usa marcapasso?'), findsOneWidget);
  });
}
