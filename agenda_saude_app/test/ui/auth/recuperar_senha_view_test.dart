import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/theme/app_theme.dart';
import 'package:agenda_saude_app/data/repositories/auth_repository.dart';
import 'package:agenda_saude_app/ui/auth/recuperar_senha_view.dart';

// Anota os e-mails pedidos e deixa o teste escolher se o envio falha.
class _AuthRepositoryFalso extends AuthRepository {
  final emailsPedidos = <String>[];
  Object? erro;

  @override
  Future<void> enviarEmailRedefinicaoSenha({required String email}) async {
    emailsPedidos.add(email);
    final falha = erro;
    if (falha != null) throw falha;
  }
}

void main() {
  group('RecuperarSenhaView Testes', () {
    late _AuthRepositoryFalso auth;

    // Tela alta por padrao: depois do envio a confirmacao empurra os botoes
    // para baixo e o toque precisa alcança-los sem rolar.
    Future<void> abrir(
      WidgetTester tester, {
      String emailInicial = '',
      double escalaTexto = 1,
      Size tamanho = const Size(800, 1400),
    }) async {
      tester.view.physicalSize = tamanho;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      auth = _AuthRepositoryFalso();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          // Simula a opcao "tamanho da fonte" do celular.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escalaTexto)),
            child: child!,
          ),
          home: RecuperarSenhaView.comProviders(
            emailInicial: emailInicial,
            authRepository: auth,
          ),
        ),
      );
    }

    Finder campoEmail() => find.widgetWithText(TextField, 'E-mail');

    Future<void> enviar(WidgetTester tester, String email) async {
      await tester.enterText(campoEmail(), email);
      await tester.tap(find.text('Enviar e-mail'));
      await tester.pumpAndSettle();
    }

    testWidgets('Deve explicar o que vai acontecer e pedir o e-mail', (
      tester,
    ) async {
      await abrir(tester);

      expect(find.text('Recuperar senha'), findsOneWidget);
      expect(find.textContaining('Vamos enviar um link'), findsOneWidget);
      expect(campoEmail(), findsOneWidget);
      expect(find.text('Enviar e-mail'), findsOneWidget);
      expect(find.text('Voltar para o login'), findsOneWidget);
      // O "Voltar" rotulado da barra superior (NF004).
      expect(find.text('Voltar'), findsOneWidget);
    });

    testWidgets('Deve mostrar o e-mail que veio do login, sem espaços sobrando', (
      tester,
    ) async {
      await abrir(tester, emailInicial: ' maria@email.com ');

      final controller = tester.widget<TextField>(campoEmail()).controller!;
      expect(controller.text, 'maria@email.com');
    });

    testWidgets('Deve pedir o e-mail quando o campo está vazio', (tester) async {
      await abrir(tester);

      await tester.tap(find.text('Enviar e-mail'));
      await tester.pump();

      expect(find.text('Digite o e-mail da sua conta.'), findsOneWidget);
      expect(auth.emailsPedidos, isEmpty);
    });

    testWidgets('Deve enviar o pedido e confirmar na tela', (tester) async {
      await abrir(tester);

      await enviar(tester, 'maria@email.com');

      expect(auth.emailsPedidos, ['maria@email.com']);
      expect(find.text('E-MAIL ENVIADO'), findsOneWidget);
      expect(
        find.textContaining('Pedido enviado para maria@email.com'),
        findsOneWidget,
      );
      // O botão principal passa a ser o de voltar; o reenvio fica em segundo.
      expect(find.text('Enviar e-mail'), findsNothing);
      expect(find.text('Voltar para o login'), findsOneWidget);
      expect(find.text('Não chegou? Enviar de novo'), findsOneWidget);
    });

    testWidgets('Deve mostrar o erro e deixar tentar de novo quando falha', (
      tester,
    ) async {
      await abrir(tester);
      auth.erro = FirebaseAuthException(code: 'network-request-failed');

      await enviar(tester, 'maria@email.com');

      expect(
        find.text('Sem conexão com a internet. Verifique sua rede.'),
        findsOneWidget,
      );
      expect(find.text('E-MAIL ENVIADO'), findsNothing);
      expect(find.text('Enviar e-mail'), findsOneWidget);
    });

    testWidgets('Deve reenviar o pedido pelo "Enviar de novo"', (tester) async {
      await abrir(tester);
      await enviar(tester, 'maria@email.com');

      await tester.tap(find.text('Não chegou? Enviar de novo'));
      await tester.pumpAndSettle();

      expect(auth.emailsPedidos, ['maria@email.com', 'maria@email.com']);
      expect(find.text('E-MAIL ENVIADO'), findsOneWidget);
    });

    testWidgets('Voltar e "Voltar para o login" fecham a tela', (tester) async {
      auth = _AuthRepositoryFalso();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecuperarSenhaView.comProviders(
                        authRepository: auth,
                      ),
                    ),
                  ),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Recuperar senha'), findsOneWidget);
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();
      expect(find.text('Recuperar senha'), findsNothing);

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voltar para o login'));
      await tester.pumpAndSettle();
      expect(find.text('Recuperar senha'), findsNothing);
    });

    testWidgets('Não estoura com a fonte do celular em 200%', (tester) async {
      // Celular pequeno (360x640) com a fonte no máximo: qualquer overflow
      // vira erro e reprova o teste. O e-mail vem do login, como no uso real:
      // com a fonte tão grande o título já ocupa a primeira tela e a pessoa
      // rola para chegar ao botão.
      await abrir(
        tester,
        emailInicial: 'maria@email.com',
        escalaTexto: 2,
        tamanho: const Size(360, 640),
      );

      await tester.scrollUntilVisible(
        find.text('Enviar e-mail'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // Construído não é o mesmo que visível: a lista monta um pouco além da tela.
      await tester.ensureVisible(find.text('Enviar e-mail'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar e-mail'));
      await tester.pumpAndSettle();

      expect(find.text('E-MAIL ENVIADO'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
