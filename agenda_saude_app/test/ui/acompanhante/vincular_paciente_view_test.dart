import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/data/repositories/acompanhante_repository.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/domain/models/acompanhante.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/acompanhante/vincular_paciente_view.dart';
import 'package:agenda_saude_app/ui/acompanhante/vincular_paciente_viewmodel.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late PacienteRepository pacienteRepository;
  late AcompanhanteRepository acompanhanteRepository;
  late Acompanhante acompanhante;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    pacienteRepository = PacienteRepository(firestore: fakeFirestore);
    acompanhanteRepository = AcompanhanteRepository(firestore: fakeFirestore);

    acompanhante = Acompanhante(
      id: 'cuidador_01',
      nome: 'Carlos Souza',
      email: 'carlos@email.com',
      perfil: 'Acompanhante',
      pacientesVinculadosIds: [],
    );
    await acompanhanteRepository.salvarAcompanhante(acompanhante);
    await pacienteRepository.salvarPaciente(Paciente(
      id: 'paciente_01',
      nome: 'José Silva',
      email: 'jose@email.com',
      perfil: 'Paciente',
      possuiDiabetes: false,
      possuiCardiopatia: false,
      codigoVinculo: 'ABC123',
    ));
  });

  // A tela e aberta por cima de uma tela base para podermos verificar o
  // resultado devolvido ao fechar (Navigator.pop(true)).
  Future<Future<bool?>> abrirTela(WidgetTester tester) async {
    late Future<bool?> resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                resultado = Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider(
                      create: (_) => VincularPacienteViewModel(
                        acompanhante: acompanhante,
                        pacienteRepository: pacienteRepository,
                        acompanhanteRepository: acompanhanteRepository,
                      ),
                      child: const VincularPacienteView(),
                    ),
                  ),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return resultado;
  }

  testWidgets('Tela de vínculo mostra a orientação, o campo de código e o botão de busca', (
    tester,
  ) async {
    await abrirTela(tester);

    expect(find.text('Vincular paciente'), findsOneWidget);
    expect(find.textContaining('Peça ao paciente o código de vínculo'), findsOneWidget);
    expect(find.text('Código de vínculo'), findsOneWidget);
    expect(find.text('Buscar paciente'), findsOneWidget);
    expect(find.text('Confirmar vínculo'), findsNothing);
  });

  testWidgets('Campo de código converte para maiúsculas e mostra erro para código inexistente', (
    tester,
  ) async {
    await abrirTela(tester);

    await tester.enterText(find.byType(TextField), 'zzz999');
    await tester.pump();
    expect(find.text('ZZZ999'), findsOneWidget);

    await tester.tap(find.text('Buscar paciente'));
    await tester.pumpAndSettle();

    expect(find.text('Código não encontrado. Confira com o paciente.'), findsOneWidget);
    expect(find.text('Confirmar vínculo'), findsNothing);
  });

  testWidgets('Fluxo completo: busca, confirma o nome, grava o vínculo e fecha com sucesso', (
    tester,
  ) async {
    final resultado = await abrirTela(tester);

    await tester.enterText(find.byType(TextField), 'abc123');
    await tester.tap(find.text('Buscar paciente'));
    await tester.pumpAndSettle();

    expect(find.text('Paciente encontrado'), findsOneWidget);
    expect(find.text('José Silva'), findsOneWidget);
    expect(find.text('Confirmar vínculo'), findsOneWidget);
    expect(find.text('Digitar outro código'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.ensureVisible(find.text('Confirmar vínculo'));
    await tester.tap(find.text('Confirmar vínculo'));
    await tester.pumpAndSettle();

    expect(await resultado, true);
    expect(find.text('abrir'), findsOneWidget);
    final salvo = await acompanhanteRepository.getAcompanhante('cuidador_01');
    expect(salvo!.pacientesVinculadosIds, ['paciente_01']);
  });

  testWidgets('"Digitar outro código" volta para o campo de código limpo', (
    tester,
  ) async {
    await abrirTela(tester);
    await tester.enterText(find.byType(TextField), 'ABC123');
    await tester.tap(find.text('Buscar paciente'));
    await tester.pumpAndSettle();
    expect(find.text('José Silva'), findsOneWidget);

    // O botao fica abaixo da dobra no viewport de teste; e preciso rolar.
    await tester.ensureVisible(find.text('Digitar outro código'));
    await tester.tap(find.text('Digitar outro código'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
    expect(find.text('José Silva'), findsNothing);
  });
}
