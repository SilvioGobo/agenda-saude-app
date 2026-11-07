import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/ui/shared/contador_grande.dart';

void main() {
  group('ContadorGrande Testes', () {
    var menos = 0;
    var mais = 0;

    setUp(() {
      menos = 0;
      mais = 0;
    });

    Future<void> montar(
      WidgetTester tester, {
      bool podeDiminuir = true,
      bool podeAumentar = true,
      double escalaTexto = 1,
      Size tamanho = const Size(800, 800),
    }) async {
      tester.view.physicalSize = tamanho;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          // Simula a opcao "tamanho da fonte" do celular.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escalaTexto)),
            child: child!,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: ContadorGrande(
                valor: '7 h 30 min',
                valorParaLeitor: '7 horas e 30 minutos',
                descricaoMenos: 'Diminuir meia hora',
                descricaoMais: 'Aumentar meia hora',
                aoDiminuir: podeDiminuir ? () => menos++ : null,
                aoAumentar: podeAumentar ? () => mais++ : null,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Deve mostrar o valor grande e os botões Menos e Mais', (
      tester,
    ) async {
      await montar(tester);

      expect(find.text('7 h 30 min'), findsOneWidget);
      expect(find.text('Menos'), findsOneWidget);
      expect(find.text('Mais'), findsOneWidget);
    });

    testWidgets('Deve chamar cada ação no seu botão', (tester) async {
      await montar(tester);

      await tester.tap(find.text('Mais'));
      await tester.tap(find.text('Mais'));
      await tester.tap(find.text('Menos'));

      expect(mais, 2);
      expect(menos, 1);
    });

    testWidgets('Deve desligar o botão que chegou ao limite', (tester) async {
      await montar(tester, podeDiminuir: false);

      expect(
        tester.widget<OutlinedButton>(find.bySubtype<OutlinedButton>()).onPressed,
        isNull,
      );
      expect(
        tester.widget<FilledButton>(find.bySubtype<FilledButton>()).onPressed,
        isNotNull,
      );

      await tester.tap(find.text('Menos'), warnIfMissed: false);
      expect(menos, 0);
    });

    testWidgets('Deve falar o valor e a ação de cada botão para o leitor de tela', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await montar(tester);

      expect(find.bySemanticsLabel('7 horas e 30 minutos'), findsOneWidget);
      expect(find.bySemanticsLabel('Diminuir meia hora'), findsOneWidget);
      expect(find.bySemanticsLabel('Aumentar meia hora'), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('Deve pôr um botão embaixo do outro com a fonte em 200%', (
      tester,
    ) async {
      // Celular pequeno (360x640) com a fonte no maximo: qualquer overflow
      // vira erro e reprova o teste.
      await montar(tester, escalaTexto: 2, tamanho: const Size(360, 640));

      final yMenos = tester.getTopLeft(find.bySubtype<OutlinedButton>()).dy;
      final yMais = tester.getTopLeft(find.bySubtype<FilledButton>()).dy;
      expect(yMais, lessThan(yMenos));
      expect(
        tester.getTopLeft(find.bySubtype<FilledButton>()).dx,
        tester.getTopLeft(find.bySubtype<OutlinedButton>()).dx,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
