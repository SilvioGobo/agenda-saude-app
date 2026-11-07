import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/data/repositories/acompanhante_repository.dart';
import 'package:agenda_saude_app/data/repositories/auth_repository.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/ui/auth/auth_view.dart';
import 'package:agenda_saude_app/ui/auth/auth_viewmodel.dart';

class _AuthRepositoryFalso extends AuthRepository {
  int chamadas = 0;

  @override
  Future<String> cadastrar({required String email, required String senha}) async {
    chamadas++;
    return 'uid_falso';
  }
}

void main() {
  group('AuthView Testes (telefone)', () {
    late _AuthRepositoryFalso authRepository;

    Future<void> abrirCadastro(WidgetTester tester) async {
      final fakeFirestore = FakeFirebaseFirestore();
      authRepository = _AuthRepositoryFalso();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => AuthViewModel(
              authRepository: authRepository,
              pacienteRepository: PacienteRepository(firestore: fakeFirestore),
              acompanhanteRepository:
                  AcompanhanteRepository(firestore: fakeFirestore),
            ),
            child: const AuthView(),
          ),
        ),
      );
    }

    Finder campo(String rotulo) => find.widgetWithText(TextField, rotulo);

    testWidgets('Deve mostrar o campo de telefone como opcional', (
      tester,
    ) async {
      await abrirCadastro(tester);

      expect(find.text('Telefone (opcional)'), findsOneWidget);
      expect(
        find.text('Com DDD. Usado para ligações em caso de emergência.'),
        findsOneWidget,
      );
    });

    testWidgets('A explicação do telefone acompanha o perfil escolhido', (
      tester,
    ) async {
      await abrirCadastro(tester);

      await tester.tap(find.text('Sou Paciente'));
      await tester.pump();
      expect(
        find.text('Com DDD. Seu acompanhante poderá ligar para você.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Sou Acompanhante'));
      await tester.pump();
      expect(
        find.text('Com DDD. O paciente poderá ligar para você.'),
        findsOneWidget,
      );
    });

    testWidgets('Não deve deixar digitar letras no telefone', (tester) async {
      await abrirCadastro(tester);

      await tester.enterText(
        campo('Telefone (opcional)'),
        'ab(67) 9x9999-0000',
      );

      final controller =
          tester.widget<TextField>(campo('Telefone (opcional)')).controller!;
      expect(controller.text, '(67) 99999-0000');
    });

    testWidgets('Deve avisar do telefone inválido e não criar a conta', (
      tester,
    ) async {
      await abrirCadastro(tester);

      await tester.tap(find.text('Sou Paciente'));
      await tester.enterText(campo('Nome completo'), 'Maria Souza');
      await tester.enterText(campo('E-mail'), 'maria@email.com');
      await tester.enterText(campo('Telefone (opcional)'), '99999-0000');
      await tester.enterText(campo('Senha'), 'Teste123456');

      await tester.ensureVisible(find.text('Cadastrar'));
      await tester.tap(find.text('Cadastrar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Informe o telefone com DDD'), findsOneWidget);
      expect(authRepository.chamadas, 0);
    });
  });
}
