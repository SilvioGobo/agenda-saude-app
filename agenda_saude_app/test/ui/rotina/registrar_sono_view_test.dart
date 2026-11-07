import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/theme/app_theme.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_base.dart';
import 'package:agenda_saude_app/domain/models/registro_sono.dart';
import 'package:agenda_saude_app/ui/rotina/registrar_sono_view.dart';
import 'package:agenda_saude_app/ui/rotina/registrar_sono_viewmodel.dart';

// Nao consegue gravar (ex.: sem internet).
class _RepositorioQueFalha extends DadosMedicosRepository {
  _RepositorioQueFalha(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Future<void> salvarRegistro(RegistroBase registro) =>
      throw Exception('sem conexao');
}

void main() {
  group('RegistrarSonoView Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    bool? resultado;

    final agora = DateTime(2026, 10, 25, 7, 30);
    final paciente = Paciente(
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
      resultado = null;
    });

    // Abre a tela por cima de outra, como o cartao da rotina faz, e guarda o
    // que ela devolve ao fechar. A tela de teste e alta para tudo ficar visivel.
    Future<void> abrir(
      WidgetTester tester, {
      RegistroSono? registroAtual,
      DadosMedicosRepository? repositorio,
      double escalaTexto = 1,
      Size tamanho = const Size(800, 1600),
    }) async {
      tester.view.physicalSize = tamanho;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          // Simula a opcao "tamanho da fonte" do celular.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escalaTexto)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  resultado = await Navigator.of(context).push(
                    RegistrarSonoView.rota(
                      RegistrarSonoViewModel(
                        paciente: paciente,
                        registroAtual: registroAtual,
                        dadosRepository: repositorio ?? dadosRepository,
                        agora: () => agora,
                      ),
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
    }

    Future<List<Map<String, dynamic>>> registrosGravados() async {
      final snapshot = await fakeFirestore.collection('registros_diarios').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    }

    testWidgets('Deve mostrar as duas perguntas, a meta e as cinco notas', (
      tester,
    ) async {
      await abrir(tester);

      expect(find.text('Registrar sono'), findsOneWidget);
      expect(find.text('1. QUANTAS HORAS VOCÊ DORMIU?'), findsOneWidget);
      expect(find.text('A meta é dormir de 7 a 9 horas por noite.'),
          findsOneWidget);
      expect(find.text('7 h'), findsOneWidget);
      expect(find.text('2. COMO FOI O SEU SONO?'), findsOneWidget);
      expect(find.text('1 - Muito ruim'), findsOneWidget);
      expect(find.text('2 - Ruim'), findsOneWidget);
      expect(find.text('3 - Regular'), findsOneWidget);
      expect(find.text('4 - Bom'), findsOneWidget);
      expect(find.text('5 - Muito bom'), findsOneWidget);
      expect(find.text('SALVAR'), findsOneWidget);
    });

    testWidgets('Deve mudar as horas de meia em meia hora', (tester) async {
      await abrir(tester);

      await tester.tap(find.text('Mais'));
      await tester.pump();
      expect(find.text('7 h 30 min'), findsOneWidget);

      await tester.tap(find.text('Menos'));
      await tester.tap(find.text('Menos'));
      await tester.pump();
      expect(find.text('6 h 30 min'), findsOneWidget);
    });

    testWidgets('Deve pedir a nota ao salvar sem escolher, e não fechar a tela', (
      tester,
    ) async {
      await abrir(tester);

      await tester.tap(find.text('SALVAR'));
      await tester.pumpAndSettle();

      expect(find.text('ESCOLHA COMO FOI O SEU SONO.'), findsOneWidget);
      expect(find.text('Registrar sono'), findsOneWidget);
      expect(resultado, isNull);
      expect(await registrosGravados(), isEmpty);
    });

    testWidgets('Deve salvar a noite e fechar devolvendo true', (tester) async {
      await abrir(tester);

      await tester.tap(find.text('Mais'));
      await tester.tap(find.text('4 - Bom'));
      await tester.pump();
      await tester.tap(find.text('SALVAR'));
      await tester.pumpAndSettle();

      expect(resultado, isTrue);
      expect(find.text('Registrar sono'), findsNothing);
      final gravados = await registrosGravados();
      expect(gravados, hasLength(1));
      expect(gravados.single['tipo'], 'sono');
      expect(gravados.single['pacienteId'], 'paciente_01');
      expect(gravados.single['horasTotais'], 7.5);
      expect(gravados.single['qualidade'], 4);
    });

    testWidgets('Deve marcar com um check a nota escolhida', (tester) async {
      await abrir(tester);

      Finder checkNa(String nota) => find.descendant(
            of: find.widgetWithText(OutlinedButton, nota),
            matching: find.byIcon(Icons.check_rounded),
          );
      expect(checkNa('3 - Regular'), findsNothing);

      await tester.tap(find.text('3 - Regular'));
      await tester.pump();

      expect(checkNa('3 - Regular'), findsOneWidget);
      expect(checkNa('4 - Bom'), findsNothing);
    });

    testWidgets('Deve abrir com a noite de hoje para corrigir', (tester) async {
      await abrir(
        tester,
        registroAtual: RegistroSono(
          id: 'sono1',
          pacienteId: 'paciente_01',
          dataHora: DateTime(2026, 10, 25, 6, 45),
          dataFim: DateTime(2026, 10, 25, 6, 45),
          horasTotais: 6,
          qualidade: 2,
        ),
      );

      expect(find.text('Corrigir o sono'), findsOneWidget);
      expect(find.text('6 h'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(OutlinedButton, '2 - Ruim'),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Deve voltar sem salvar ao tocar em "Voltar"', (tester) async {
      await abrir(tester);

      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();

      expect(resultado, isFalse);
      expect(find.text('Registrar sono'), findsNothing);
      expect(await registrosGravados(), isEmpty);
    });

    testWidgets('Deve avisar quando não consegue gravar e manter a tela aberta', (
      tester,
    ) async {
      await abrir(tester, repositorio: _RepositorioQueFalha(fakeFirestore));

      await tester.tap(find.text('4 - Bom'));
      await tester.pump();
      await tester.tap(find.text('SALVAR'));
      await tester.pumpAndSettle();

      expect(find.text('NÃO FOI POSSÍVEL SALVAR. TENTE DE NOVO.'),
          findsOneWidget);
      expect(find.text('Registrar sono'), findsOneWidget);
      expect(resultado, isNull);
    });

    testWidgets('Não estoura com a fonte do celular em 200%', (tester) async {
      // Celular pequeno (360x640) com a fonte no maximo: qualquer overflow
      // vira erro e reprova o teste.
      await abrir(tester, escalaTexto: 2, tamanho: const Size(360, 640));

      await tester.scrollUntilVisible(
        find.text('SALVAR'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('SALVAR'));
      await tester.pumpAndSettle();

      expect(find.text('SALVAR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
