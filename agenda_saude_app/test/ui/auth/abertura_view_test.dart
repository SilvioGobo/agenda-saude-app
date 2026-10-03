import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/data/repositories/acompanhante_repository.dart';
import 'package:agenda_saude_app/data/repositories/auth_repository.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/ui/auth/abertura_view.dart';
import 'package:agenda_saude_app/ui/auth/login_viewmodel.dart';

class _AuthRepositoryComSessao extends AuthRepository {
  final String? uidSessao;
  bool saiu = false;

  _AuthRepositoryComSessao(this.uidSessao);

  @override
  String? get uidUsuarioAtual => saiu ? null : uidSessao;

  @override
  Future<void> sair() async => saiu = true;
}

void main() {
  group('AberturaView Testes', () {
    Future<void> montarAbertura(
      WidgetTester tester,
      AuthRepository authRepository,
    ) async {
      final fakeFirestore = FakeFirebaseFirestore();
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => LoginViewModel(
              authRepository: authRepository,
              pacienteRepository: PacienteRepository(firestore: fakeFirestore),
              acompanhanteRepository:
                  AcompanhanteRepository(firestore: fakeFirestore),
              firestore: fakeFirestore,
            ),
            child: const AberturaView(),
          ),
        ),
      );
    }

    testWidgets('Deve mostrar o login quando ninguém entrou no aparelho', (
      tester,
    ) async {
      await montarAbertura(tester, _AuthRepositoryComSessao(null));
      await tester.pumpAndSettle();

      expect(find.text('Bem-vindo'), findsOneWidget);
      expect(find.text('Não tem conta? Cadastre-se'), findsOneWidget);
    });

    testWidgets('Deve mostrar a logo enquanto confere a sessão e cair no login se a conta não tiver perfil', (
      tester,
    ) async {
      final auth = _AuthRepositoryComSessao('uid_sem_perfil');
      await montarAbertura(tester, auth);

      expect(find.text('Agenda Saúde'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Bem-vindo'), findsNothing);

      await tester.pumpAndSettle();

      expect(find.text('Bem-vindo'), findsOneWidget);
      expect(auth.saiu, true);
    });
  });
}
