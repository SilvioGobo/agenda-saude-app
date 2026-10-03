import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/acompanhante_repository.dart';
import 'package:agenda_saude_app/data/repositories/auth_repository.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/ui/auth/botao_sair.dart';
import 'package:agenda_saude_app/ui/auth/login_viewmodel.dart';

class _AuthRepositoryFalso extends AuthRepository {
  bool saiu = false;

  @override
  Future<void> sair() async => saiu = true;
}

void main() {
  group('BotaoSair Testes', () {
    late _AuthRepositoryFalso auth;

    Future<void> montarPainel(WidgetTester tester) async {
      final fakeFirestore = FakeFirebaseFirestore();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Painel'),
              actions: [
                BotaoSair(
                  authRepository: auth,
                  criarLoginViewModel: () => LoginViewModel(
                    authRepository: auth,
                    pacienteRepository:
                        PacienteRepository(firestore: fakeFirestore),
                    acompanhanteRepository:
                        AcompanhanteRepository(firestore: fakeFirestore),
                    firestore: fakeFirestore,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Finder botaoDoDialogo(String rotulo) => find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(rotulo),
        );

    setUp(() {
      auth = _AuthRepositoryFalso();
    });

    testWidgets('Deve pedir confirmação e continuar logado ao cancelar', (
      tester,
    ) async {
      await montarPainel(tester);

      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
      expect(find.text('Sair da conta?'), findsOneWidget);

      await tester.tap(botaoDoDialogo('Cancelar'));
      await tester.pumpAndSettle();

      expect(auth.saiu, false);
      expect(find.text('Painel'), findsOneWidget);
    });

    testWidgets('Deve sair da conta e voltar para o login ao confirmar', (
      tester,
    ) async {
      await montarPainel(tester);

      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
      await tester.tap(botaoDoDialogo('Sair'));
      await tester.pumpAndSettle();

      expect(auth.saiu, true);
      expect(find.text('Painel'), findsNothing);
      expect(find.text('Bem-vindo'), findsOneWidget);
    });
  });
}
