import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/ui/paciente/codigo_vinculo_view.dart';

void main() {
  group('CodigoVinculoView Testes', () {
    testWidgets('Deve mostrar o código e copiá-lo ao tocar no botão', (tester) async {
      // Captura o que o app manda para a area de transferencia do sistema.
      final copiados = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (chamada) async {
          if (chamada.method == 'Clipboard.setData') {
            copiados.add((chamada.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(
        const MaterialApp(home: CodigoVinculoView(codigo: 'ABC123')),
      );

      expect(find.text('Meu código de vínculo'), findsOneWidget);
      expect(find.text('ABC123'), findsOneWidget);
      expect(find.bySemanticsLabel('Código: A B C 1 2 3'), findsOneWidget);

      await tester.tap(find.text('Copiar código'));
      await tester.pumpAndSettle();

      expect(copiados, ['ABC123']);
      expect(find.text('Código copiado.'), findsOneWidget);
    });

    testWidgets('Deve avisar quando o código não está disponível', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: CodigoVinculoView(codigo: '')),
      );

      expect(find.text('Indisponível'), findsOneWidget);
      expect(find.text('Copiar código'), findsNothing);
    });
  });
}
