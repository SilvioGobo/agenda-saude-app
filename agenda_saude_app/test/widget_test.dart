import 'package:flutter_test/flutter_test.dart';
import 'package:agenda_saude_app/main.dart';

void main() {
  testWidgets('Verifica a tela inicial do Firebase', (WidgetTester tester) async {
    await tester.pumpWidget(const AgendaSaudeApp());
    expect(find.text('Firebase Inicializado com Sucesso! 🚀'), findsOneWidget);
  });
}