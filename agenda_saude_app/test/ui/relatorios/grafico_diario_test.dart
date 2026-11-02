import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/theme/app_theme.dart';
import 'package:agenda_saude_app/ui/relatorios/grafico_diario.dart';

void main() {
  group('GraficoDiario Testes', () {
    // 30 dias: so os dias 1, 2 e 4 tem valor.
    List<double?> valores() => [
          for (var dia = 1; dia <= 30; dia++)
            switch (dia) {
              1 => 2000.0,
              2 => 1000.0,
              4 => 500.0,
              _ => null,
            },
        ];

    Future<void> montar(
      WidgetTester tester, {
      List<double?>? serie,
      Color Function(double valor)? corDaBarra,
      List<LinhaDeReferencia> linhas = const [],
      List<LegendaDeCor> legendas = const [],
      double maximo = 2500,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: GraficoDiario(
                valores: serie ?? valores(),
                maximo: maximo,
                linhas: linhas,
                legendas: legendas,
                corDaBarra: corDaBarra ?? (_) => Colors.teal,
                descricao: 'Gráfico da água de novembro.',
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Deve desenhar uma barra só para os dias que têm valor', (tester) async {
      await montar(tester);

      expect(find.byType(FractionallySizedBox), findsNWidgets(3));
    });

    testWidgets('Deve dar a cada barra a altura proporcional ao valor e ao máximo', (tester) async {
      await montar(tester, maximo: 2000);

      final alturas = tester
          .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .map((barra) => barra.heightFactor)
          .toList();
      expect(alturas, [1.0, 0.5, 0.25]);
    });

    testWidgets('Não deve deixar a barra passar do máximo nem sumir quando o valor é pequeno', (tester) async {
      await montar(tester, serie: [3000, 1, null], maximo: 2000);

      final alturas = tester
          .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .map((barra) => barra.heightFactor)
          .toList();
      expect(alturas[0], 1.0);
      expect(alturas[1], 0.03);
    });

    testWidgets('Deve pedir a cor de cada barra a quem usa o gráfico', (tester) async {
      final consultados = <double>[];
      await montar(
        tester,
        corDaBarra: (valor) {
          consultados.add(valor);
          return valor >= 1500 ? Colors.green : Colors.grey;
        },
      );

      expect(consultados.toSet(), {2000.0, 1000.0, 500.0});
      final cores = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(FractionallySizedBox),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((caixa) => (caixa.decoration as BoxDecoration).color)
          .toList();
      expect(cores, [Colors.green, Colors.grey, Colors.grey]);
    });

    testWidgets('Deve mostrar a legenda das linhas e das cores', (tester) async {
      await montar(
        tester,
        linhas: const [LinhaDeReferencia(valor: 2000, rotulo: 'Meta: 2.000 ml')],
        legendas: const [
          LegendaDeCor(cor: Colors.green, rotulo: 'Meta atingida'),
          LegendaDeCor(cor: Colors.grey, rotulo: 'Abaixo da meta'),
        ],
      );

      expect(find.text('Meta: 2.000 ml'), findsOneWidget);
      expect(find.text('Meta atingida'), findsOneWidget);
      expect(find.text('Abaixo da meta'), findsOneWidget);
    });

    testWidgets('Não deve ter legenda quando não há linhas nem cores a explicar', (tester) async {
      await montar(tester);

      expect(find.text('Meta atingida'), findsNothing);
    });

    testWidgets('Deve numerar o dia 1 e os dias de 5 em 5', (tester) async {
      await montar(tester);

      for (final dia in ['1', '5', '10', '15', '20', '25', '30']) {
        expect(find.text(dia), findsOneWidget, reason: 'dia $dia');
      }
      expect(find.text('2'), findsNothing);
      expect(find.text('31'), findsNothing);
    });

    testWidgets('Deve descrever o gráfico em uma frase para o leitor de tela', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester);

      expect(
        find.bySemanticsLabel('Gráfico da água de novembro.'),
        findsOneWidget,
      );
      semantica.dispose();
    });
  });
}
