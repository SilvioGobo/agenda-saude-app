import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/alimentos/alimento.dart';
import 'package:agenda_saude_app/domain/alimentos/catalogo_alimentos.dart';
import 'package:agenda_saude_app/ui/rotina/buscar_alimento_view.dart';
import 'package:agenda_saude_app/ui/rotina/buscar_alimento_viewmodel.dart';

import '../../helpers/catalogo_de_teste.dart';

void main() {
  late CatalogoAlimentos catalogo;

  setUpAll(() async {
    catalogo = await catalogoDeTeste();
  });

  group('BuscarAlimentoViewModel Testes', () {
    test('Deve começar sem consulta e sem resultados', () {
      final viewModel = BuscarAlimentoViewModel(catalogo);

      expect(viewModel.consulta, '');
      expect(viewModel.buscou, isFalse);
      expect(viewModel.resultados, isEmpty);
    });

    test('Deve buscar a cada mudança no texto e avisar quem escuta', () {
      final viewModel = BuscarAlimentoViewModel(catalogo);
      var avisos = 0;
      viewModel.addListener(() => avisos++);

      viewModel.definirConsulta('feij');
      expect(viewModel.buscou, isTrue);
      expect(
        viewModel.resultados.map((a) => a.nome),
        contains('Feijão, carioca, cozido'),
      );

      viewModel.definirConsulta('feij coz');
      expect(
        viewModel.resultados.every((a) => a.nome.toLowerCase().contains('coz')),
        isTrue,
      );
      expect(avisos, 2);
    });

    test('Não deve considerar busca só de espaços', () {
      final viewModel = BuscarAlimentoViewModel(catalogo);

      viewModel.definirConsulta('   ');

      expect(viewModel.buscou, isFalse);
      expect(viewModel.resultados, isEmpty);
    });
  });

  group('BuscarAlimentoView Testes', () {
    // Abre a busca a partir de um botao e guarda o alimento devolvido.
    Future<List<Alimento?>> abrir(
      WidgetTester tester, {
      double escala = 1,
    }) async {
      final escolhidos = <Alimento?>[];
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(escala)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => escolhidos.add(
                  await Navigator.of(context).push<Alimento>(
                    MaterialPageRoute(
                      builder: (_) => BuscarAlimentoView.comProviders(catalogo),
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
      return escolhidos;
    }

    testWidgets('Deve explicar como buscar e citar a fonte dos valores', (
      tester,
    ) async {
      await abrir(tester);

      expect(find.text('Escolher alimento'), findsOneWidget);
      expect(find.text('Voltar'), findsOneWidget);
      expect(find.textContaining('Digite o nome do alimento'), findsOneWidget);
      expect(find.textContaining('TACO'), findsOneWidget);
      expect(find.textContaining('NEPA/UNICAMP'), findsOneWidget);
    });

    testWidgets(
      'Deve listar os alimentos que combinam, com as calorias por 100 g',
      (tester) async {
        await abrir(tester);

        await tester.enterText(find.byType(TextField), 'feijao carioca');
        await tester.pumpAndSettle();

        expect(find.text('Feijão, carioca, cozido'), findsOneWidget);
        expect(find.textContaining('76 kcal por 100 g'), findsOneWidget);
        expect(find.textContaining('Leguminosas e derivados'), findsWidgets);
        expect(find.textContaining('Digite o nome do alimento'), findsNothing);
      },
    );

    testWidgets('Deve avisar quando nada combina', (tester) async {
      await abrir(tester);

      await tester.enterText(find.byType(TextField), 'xyzxyz');
      await tester.pumpAndSettle();

      expect(find.textContaining('Nenhum alimento encontrado'), findsOneWidget);
    });

    testWidgets('Deve devolver o alimento tocado e fechar a busca', (
      tester,
    ) async {
      final escolhidos = await abrir(tester);

      await tester.enterText(find.byType(TextField), 'banana prata');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Banana, prata, crua'));
      await tester.pumpAndSettle();

      expect(find.text('Escolher alimento'), findsNothing);
      expect(escolhidos.single!.id, idBananaPrata);
      expect(escolhidos.single!.nome, 'Banana, prata, crua');
    });

    testWidgets('Voltar deve fechar a busca sem escolher nada', (tester) async {
      final escolhidos = await abrir(tester);

      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('Abrir'), findsOneWidget);
      expect(escolhidos, [null]);
    });

    testWidgets('Deve falar o alimento e a ação para o leitor de tela', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await abrir(tester);

      await tester.enterText(find.byType(TextField), 'banana prata');
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(
          RegExp(
            r'Banana, prata, crua, 98 kcal por 100 g.* Toque para escolher\.',
          ),
        ),
        findsOneWidget,
      );
      semantica.dispose();
    });

    testWidgets('Não deve estourar o layout com a fonte do celular em 200%', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await abrir(tester, escala: 2);

      await tester.enterText(find.byType(TextField), 'arroz');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
