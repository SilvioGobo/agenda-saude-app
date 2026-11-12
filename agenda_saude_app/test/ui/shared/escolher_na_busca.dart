import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Com uma tela de busca aberta (alimento, remedio ou alergia), faz o que a
// pessoa faz: digita [consulta] no campo e toca em [opcao] na lista.
Future<void> escolherNaBusca(
  WidgetTester tester,
  String consulta,
  String opcao,
) async {
  await tester.enterText(find.byType(TextField).last, consulta);
  await tester.pumpAndSettle();
  final alvo = find.text(opcao).last;
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}
