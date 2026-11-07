import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/auth_repository.dart';

// FirebaseAuth falso que so anota o que o repository pediu: o de verdade
// precisa do Firebase inicializado e mandaria um e-mail de verdade.
class _FirebaseAuthFalso extends Fake implements FirebaseAuth {
  final chamadas = <String>[];
  FirebaseAuthException? erroAoEnviar;

  @override
  Future<void> setLanguageCode(String? languageCode) async {
    chamadas.add('idioma:$languageCode');
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    chamadas.add('email:$email');
    final erro = erroAoEnviar;
    if (erro != null) throw erro;
  }
}

void main() {
  group('AuthRepository Testes', () {
    test('Deve pedir ao Firebase o e-mail de redefinição, em português', () async {
      final auth = _FirebaseAuthFalso();

      await AuthRepository(auth: auth)
          .enviarEmailRedefinicaoSenha(email: 'maria@email.com');

      // O idioma vem antes: e ele que escolhe o idioma do texto do e-mail.
      expect(auth.chamadas, ['idioma:pt-BR', 'email:maria@email.com']);
    });

    test('Deve repassar o erro do Firebase para quem chamou', () async {
      final auth = _FirebaseAuthFalso()
        ..erroAoEnviar = FirebaseAuthException(code: 'invalid-email');

      expect(
        AuthRepository(auth: auth)
            .enviarEmailRedefinicaoSenha(email: 'maria@email'),
        throwsA(
          isA<FirebaseAuthException>()
              .having((e) => e.code, 'code', 'invalid-email'),
        ),
      );
    });
  });
}
