import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/core/theme/app_theme.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/alergias/buscar_alergia_viewmodel.dart';
import 'package:agenda_saude_app/ui/alergias/minhas_alergias_view.dart';
import 'package:agenda_saude_app/ui/alergias/minhas_alergias_viewmodel.dart';

import '../../helpers/catalogo_de_teste.dart';
import '../shared/escolher_na_busca.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late PacienteRepository repositorio;
  late Paciente paciente;
  late List<Paciente> salvos;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    repositorio = PacienteRepository(firestore: fakeFirestore);
    paciente = Paciente(
      id: 'paciente_01',
      nome: 'José Silva',
      email: 'jose@email.com',
      perfil: 'Paciente',
      possuiDiabetes: false,
      possuiCardiopatia: false,
      codigoVinculo: 'ABC123',
      alergiasAlimentos: const ['Camarão'],
      alergiasRemedios: const ['Dipirona'],
      alergias: 'Látex',
    );
    // As alergias sao um update: o documento precisa existir.
    await repositorio.salvarPaciente(paciente);
    salvos = [];
  });

  MinhasAlergiasViewModel criar() => MinhasAlergiasViewModel(
    paciente: paciente,
    pacienteRepository: repositorio,
    aoSalvar: salvos.add,
  );

  group('MinhasAlergiasViewModel Testes', () {
    test('Deve começar com as alergias do paciente', () {
      final viewModel = criar();

      expect(viewModel.alimentos, ['Camarão']);
      expect(viewModel.remedios, ['Dipirona']);
      expect(viewModel.outras, 'Látex');
    });

    test(
      'Deve juntar sem repetir, tirar, salvar e avisar quem abriu',
      () async {
        final viewModel = criar()
          ..adicionarAlimento('camarao')
          ..adicionarAlimento('Amendoim')
          ..tirarAlimento('Camarão')
          ..adicionarRemedio('Amoxicilina')
          ..definirOutras('');

        expect(await viewModel.salvar(), isTrue);

        final gravado = await repositorio.getPaciente('paciente_01');
        expect(gravado!.alergiasAlimentos, ['Amendoim']);
        expect(gravado.alergiasRemedios, ['Dipirona', 'Amoxicilina']);
        expect(gravado.alergias, isNull);
        expect(salvos.single.alergiasAlimentos, ['Amendoim']);
        expect(salvos.single.alergias, isNull);
        // O resto do paciente nao muda.
        expect(salvos.single.nome, 'José Silva');
      },
    );

    test('Deve avisar quando não consegue salvar', () async {
      final viewModel = MinhasAlergiasViewModel(
        paciente: paciente,
        // Sem o documento do paciente, o update falha.
        pacienteRepository: PacienteRepository(
          firestore: FakeFirebaseFirestore(),
        ),
        aoSalvar: salvos.add,
      );

      expect(await viewModel.salvar(), isFalse);
      expect(viewModel.mensagemErro, 'Não foi possível salvar. Tente de novo.');
      expect(viewModel.salvando, isFalse);
      expect(salvos, isEmpty);
    });
  });

  group('BuscarAlergiaViewModel Testes', () {
    test('Deve avisar quando a lista não abre', () async {
      final viewModel = BuscarAlergiaViewModel(
        Future.error(Exception('sem arquivo')),
      );
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.carregando, isFalse);
      expect(viewModel.erroAoCarregar, isTrue);
      viewModel.definirConsulta('dipi');
      expect(viewModel.resultados, isEmpty);
    });
  });

  group('MinhasAlergiasView Testes', () {
    Future<void> abrir(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChangeNotifierProvider(
                      create: (_) => criar(),
                      child: const MinhasAlergiasView(
                        carregarAlimentos: catalogoDeTeste,
                        carregarRemedios: carregarRemediosPequeno,
                      ),
                    ),
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'Deve mostrar as alergias, escolher novas nas listas e salvar',
      (tester) async {
        await abrir(tester);

        expect(find.text('Minhas alergias'), findsOneWidget);
        expect(find.text('Camarão'), findsOneWidget);
        expect(find.text('Dipirona'), findsOneWidget);
        expect(find.widgetWithText(TextFormField, 'Látex'), findsOneWidget);

        await tester.tap(find.text('Adicionar alimento'));
        await tester.pumpAndSettle();
        await escolherNaBusca(tester, 'amendo', 'Amendoim');

        await tester.tap(find.text('Adicionar remédio'));
        await tester.pumpAndSettle();
        // Pela marca: o Glifage leva a metformina.
        await escolherNaBusca(tester, 'glifage', 'Metformina');
        expect(find.text('Metformina'), findsOneWidget);

        // Tira o camarao.
        await tester.tap(find.text('Tirar').first);
        await tester.pumpAndSettle();
        expect(find.text('Camarão'), findsNothing);

        await tester.tap(find.text('Salvar'));
        await tester.pumpAndSettle();

        expect(find.text('Minhas alergias'), findsNothing);
        expect(salvos.single.alergiasAlimentos, ['Amendoim']);
        expect(salvos.single.alergiasRemedios, ['Dipirona', 'Metformina']);
        expect(salvos.single.alergias, 'Látex');
      },
    );

    testWidgets('Cancelar fecha sem salvar', (tester) async {
      await abrir(tester);

      await tester.tap(find.text('Tirar').first);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Minhas alergias'), findsNothing);
      expect(salvos, isEmpty);
      final gravado = await repositorio.getPaciente('paciente_01');
      expect(gravado!.alergiasAlimentos, ['Camarão']);
    });
  });
}
