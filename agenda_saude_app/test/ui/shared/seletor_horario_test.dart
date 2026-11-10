import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/theme/app_theme.dart';
import 'package:agenda_saude_app/ui/shared/seletor_horario.dart';

import 'escolher_horario.dart';

void main() {
  group('mostrarSeletorDeHorario Testes', () {
    // Abre o seletor por um botao, num celular configurado em 12 horas (AM/PM),
    // e devolve a lista com o que ele respondeu.
    Future<List<String?>> abrir(
      WidgetTester tester, {
      String inicial = '08:00',
      double escalaTexto = 1,
      Size tamanho = const Size(800, 600),
    }) async {
      tester.view.physicalSize = tamanho;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final respostas = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              alwaysUse24HourFormat: false,
              textScaler: TextScaler.linear(escalaTexto),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => respostas.add(
                  await mostrarSeletorDeHorario(context, inicial: inicial),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      return respostas;
    }

    testWidgets('Deve abrir no horário inicial, em 24 horas, com os textos em português', (
      tester,
    ) async {
      await abrir(tester, inicial: '20:30');

      expect(find.text('ESCOLHA O HORÁRIO'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      // O celular esta em 12 horas, mas o seletor nao mostra AM/PM.
      expect(find.text('AM'), findsNothing);
      expect(find.text('PM'), findsNothing);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('Deve devolver o horário escolhido em HH:MM', (tester) async {
      final respostas = await abrir(tester);

      await escolherNoSeletorDeHorario(tester, hora: 7, minuto: 5);

      expect(respostas, ['07:05']);
      expect(find.byType(TimePickerDialog), findsNothing);
    });

    testWidgets('Deve devolver o horário inicial quando a pessoa só toca em OK', (
      tester,
    ) async {
      final respostas = await abrir(tester, inicial: '21:30');

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(respostas, ['21:30']);
    });

    testWidgets('Deve devolver null ao cancelar', (tester) async {
      final respostas = await abrir(tester);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(respostas, [null]);
    });

    testWidgets('Com um horário inicial que não existe, deve abrir nas 08:00', (
      tester,
    ) async {
      final respostas = await abrir(tester, inicial: '25:99');

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(respostas, ['08:00']);
    });

    testWidgets('Deve mostrar só o relógio, sem o modo de digitar', (
      tester,
    ) async {
      await abrir(tester);

      expect(
        find.byKey(const ValueKey<String>('time-picker-dial')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.keyboard_outlined), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Deve escolher as horas da tarde e da noite no anel de dentro', (
      tester,
    ) async {
      final respostas = await abrir(tester);

      await escolherNoSeletorDeHorario(tester, hora: 20, minuto: 30);

      expect(respostas, ['20:30']);
    });

    testWidgets('Não estoura com a fonte do celular em 200%', (tester) async {
      // Celular pequeno (360x640) com a fonte no maximo: qualquer overflow
      // vira erro e reprova o teste.
      final respostas = await abrir(
        tester,
        escalaTexto: 2,
        tamanho: const Size(360, 640),
      );
      expect(tester.takeException(), isNull);

      await escolherNoSeletorDeHorario(tester, hora: 22, minuto: 0);

      expect(tester.takeException(), isNull);
      expect(respostas, ['22:00']);
    });
  });
}
