import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/core/theme/app_theme.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/domain/medicacao/remedio.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/triagem/meus_dados_view.dart';
import 'package:agenda_saude_app/ui/triagem/triagem_viewmodel.dart';

import '../../helpers/catalogo_de_teste.dart';
import '../shared/escolher_na_busca.dart';

void main() {
  group('MeusDadosView Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late Paciente paciente;
    late List<Paciente> salvos;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      paciente = Paciente(
        id: 'paciente_001',
        nome: 'Maria Souza',
        email: 'maria@email.com',
        perfil: 'Paciente',
        codigoVinculo: 'ABC123',
        triagemConcluida: true,
        possuiDiabetes: true,
        tipoDiabetes: 'Tipo 2',
        usaInsulina: true,
        tipoInsulina: 'NPH',
        possuiCardiopatia: true,
        usaMarcapasso: false,
        limiteLiquidoMl: 1500,
        dataNascimento: DateTime(1958, 3, 2),
        sexoBiologico: 'Feminino',
        alturaCm: 165,
        pesoKg: 70,
        nivelAtividadeFisica: 'Leve',
        alergiasAlimentos: const ['Camarão'],
        alergiasRemedios: const ['Dipirona'],
        alergias: 'Látex',
        medicamentosEmUso: const [
          Remedio(nome: 'Losartana potássica', substancias: ['Losartana']),
        ],
      );
      // "Meus dados" grava por update: o documento precisa existir.
      await PacienteRepository(firestore: fakeFirestore)
          .salvarPaciente(paciente);
      salvos = [];
    });

    // Abre a tela por cima de outra, como o menu faz. A tela de teste e alta
    // para todas as perguntas ficarem montadas.
    Future<void> abrir(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 4000);
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
                      create: (_) => TriagemViewModel(
                        paciente: paciente,
                        pacienteRepository:
                            PacienteRepository(firestore: fakeFirestore),
                        edicao: true,
                      ),
                      child: MeusDadosView(
                        aoSalvar: salvos.add,
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

    Finder campo(String rotulo) => find.widgetWithText(TextField, rotulo);

    testWidgets('Deve abrir com todas as respostas da triagem preenchidas', (
      tester,
    ) async {
      await abrir(tester);

      expect(find.text('Meus dados'), findsOneWidget);
      for (final secao in [
        'SOBRE VOCÊ',
        'DIABETES',
        'CORAÇÃO',
        'ALERGIAS',
        'REMÉDIOS EM USO',
      ]) {
        expect(find.text(secao), findsOneWidget);
      }
      expect(find.text('02/03/1958'), findsOneWidget);
      expect(find.widgetWithText(TextField, '165'), findsOneWidget);
      expect(find.widgetWithText(TextField, '70'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'NPH'), findsOneWidget);
      expect(find.widgetWithText(TextField, '1,5'), findsOneWidget);
      expect(find.text('Camarão'), findsOneWidget);
      expect(find.text('Dipirona'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Látex'), findsOneWidget);
      expect(find.text('Losartana potássica'), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);
    });

    testWidgets('Deve salvar o que mudou, avisar o painel e fechar', (
      tester,
    ) async {
      await abrir(tester);

      await tester.enterText(campo('Peso (kg)'), '72,5');
      await tester.tap(find.text('Adicionar alimento'));
      await tester.pumpAndSettle();
      await escolherNaBusca(tester, 'amendo', 'Amendoim');
      expect(find.text('Amendoim'), findsOneWidget);

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Meus dados'), findsNothing);
      expect(find.text('Seus dados foram salvos.'), findsOneWidget);
      final salvo = salvos.single;
      expect(salvo.pesoKg, 72.5);
      expect(salvo.alergiasAlimentos, ['Camarão', 'Amendoim']);
      expect(salvo.metas, isNotNull);
      final gravado = await PacienteRepository(firestore: fakeFirestore)
          .getPaciente('paciente_001');
      expect(gravado!.pesoKg, 72.5);
      expect(gravado.alergiasAlimentos, ['Camarão', 'Amendoim']);
    });

    testWidgets('Deve mostrar o que falta e continuar aberta', (tester) async {
      await abrir(tester);

      await tester.enterText(campo('Altura (cm)'), '');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Preencha data de nascimento'), findsOneWidget);
      expect(find.text('Meus dados'), findsOneWidget);
      expect(salvos, isEmpty);
    });

    testWidgets('Cancelar fecha sem salvar nada', (tester) async {
      await abrir(tester);

      await tester.enterText(campo('Peso (kg)'), '99');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Meus dados'), findsNothing);
      expect(salvos, isEmpty);
      final gravado = await PacienteRepository(firestore: fakeFirestore)
          .getPaciente('paciente_001');
      expect(gravado!.pesoKg, 70);
    });
  });
}
