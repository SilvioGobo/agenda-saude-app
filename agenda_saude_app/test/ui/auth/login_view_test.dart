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

void main() {
  testWidgets('Tela de login mostra os campos e o link de cadastro', (
    tester,
  ) async {
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

    expect(find.text('Entrar'), findsWidgets);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Não tem conta? Cadastre-se'), findsOneWidget);
  });
}
