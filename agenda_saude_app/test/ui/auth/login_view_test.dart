import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/data/repositories/acompanhante_repository.dart';
import 'package:agenda_saude_app/data/repositories/auth_repository.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/ui/auth/login_view.dart';
import 'package:agenda_saude_app/ui/auth/login_viewmodel.dart';

class _AuthRepositoryFalso extends AuthRepository {
  @override
  Future<String> entrar({required String email, required String senha}) async {
    return 'uid_falso';
  }
}

Future<void> abrirLogin(WidgetTester tester) async {
  final fakeFirestore = FakeFirebaseFirestore();

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider(
        create: (_) => LoginViewModel(
          authRepository: _AuthRepositoryFalso(),
          pacienteRepository: PacienteRepository(firestore: fakeFirestore),
          acompanhanteRepository:
              AcompanhanteRepository(firestore: fakeFirestore),
          firestore: fakeFirestore,
        ),
        child: const LoginView(),
      ),
    ),
  );
}

void main() {
  testWidgets('Tela de login mostra os campos e o link de cadastro', (
    tester,
  ) async {
    await abrirLogin(tester);

    expect(find.text('Entrar'), findsWidgets);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Esqueci minha senha'), findsOneWidget);
    expect(find.text('Não tem conta? Cadastre-se'), findsOneWidget);
  });

  testWidgets('Esqueci minha senha abre a recuperação com o e-mail já digitado', (
    tester,
  ) async {
    await abrirLogin(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'E-mail'),
      'maria@email.com',
    );
    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();

    expect(find.text('Recuperar senha'), findsOneWidget);
    final campoEmail =
        tester.widget<TextField>(find.widgetWithText(TextField, 'E-mail'));
    expect(campoEmail.controller!.text, 'maria@email.com');
  });

  testWidgets('Voltar da recuperação de senha devolve ao login', (
    tester,
  ) async {
    await abrirLogin(tester);

    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('Recuperar senha'), findsNothing);
    expect(find.text('Esqueci minha senha'), findsOneWidget);
  });
}
