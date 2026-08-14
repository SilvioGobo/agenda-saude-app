import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/triagem/triagem_cardiopatia_view.dart';
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
        child: const TriagemCardiopatiaView(),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'Etapa 3 (Cardiopatia) mostra o progresso e a pergunta principal',
    (tester) async {
      await _montarTela(tester);

      expect(find.text('Cardiopatia'), findsOneWidget);
      expect(find.text('Etapa 3 de 4'), findsOneWidget);
      expect(find.text('Você possui alguma cardiopatia?'), findsOneWidget);
      expect(find.text('Usa marcapasso?'), findsNothing);
    },
  );

  testWidgets('Deve mostrar as perguntas extras só depois de responder Sim', (
    tester,
  ) async {
    await _montarTela(tester);

    await tester.tap(find.text('Sim'));
    await tester.pump();

    expect(find.text('Qual? (opcional)'), findsOneWidget);
    expect(find.text('Usa marcapasso?'), findsOneWidget);
  });
}
