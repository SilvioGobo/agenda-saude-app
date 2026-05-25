import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
// Ajuste o import para o seu main.dart
import 'package:agenda_saude_app/main.dart' as app;

void main() {
  // Configura o ambiente de teste no emulador
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Teste de inicialização e interface inicial', (WidgetTester tester) async {
    // 1. Inicia o aplicativo
    app.main();

    // 2. Espera as animações terminarem de carregar a tela
    await tester.pumpAndSettle();

    // 3. Verifica se a mensagem de sucesso do Firebase (que criamos no passo anterior) está na tela
    expect(find.text('Firebase Inicializado com Sucesso! 🚀'), findsOneWidget);

    // Obs: Quando criarmos a tela de Login, mudaremos este teste para preencher
    // e-mail, senha e clicar no botão "Entrar" automaticamente!
  });
}