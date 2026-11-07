import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/auth_repository.dart';
import 'package:agenda_saude_app/ui/auth/recuperar_senha_viewmodel.dart';

// Anota os e-mails pedidos e deixa o teste escolher se o envio demora ou falha.
class _AuthRepositoryFalso extends AuthRepository {
  final emailsPedidos = <String>[];
  Future<void>? espera;
  Object? erro;

  @override
  Future<void> enviarEmailRedefinicaoSenha({required String email}) async {
    emailsPedidos.add(email);
    await espera;
    final falha = erro;
    if (falha != null) throw falha;
  }
}

void main() {
  group('RecuperarSenhaViewModel Testes', () {
    late _AuthRepositoryFalso auth;
    late RecuperarSenhaViewModel viewModel;

    setUp(() {
      auth = _AuthRepositoryFalso();
      viewModel = RecuperarSenhaViewModel(authRepository: auth);
    });

    test('Deve exigir o e-mail', () async {
      final sucesso = await viewModel.enviar('   ');

      expect(sucesso, false);
      expect(viewModel.mensagemErro, 'Digite o e-mail da sua conta.');
      expect(auth.emailsPedidos, isEmpty);
    });

    test('Deve rejeitar e-mail com formato inválido', () async {
      final sucesso = await viewModel.enviar('maria@email');

      expect(sucesso, false);
      expect(viewModel.mensagemErro, 'Informe um e-mail válido.');
      expect(auth.emailsPedidos, isEmpty);
    });

    test('Deve pedir o e-mail de redefinição sem os espaços das pontas', () async {
      final sucesso = await viewModel.enviar('  maria@email.com ');

      expect(sucesso, true);
      expect(auth.emailsPedidos, ['maria@email.com']);
      expect(viewModel.emailEnviado, 'maria@email.com');
      expect(viewModel.mensagemErro, isNull);
      expect(viewModel.carregando, false);
    });

    test('Deve ficar carregando até o Firebase responder', () async {
      final resposta = Completer<void>();
      auth.espera = resposta.future;

      final envio = viewModel.enviar('maria@email.com');
      expect(viewModel.carregando, true);
      expect(viewModel.emailEnviado, isNull);

      resposta.complete();
      await envio;
      expect(viewModel.carregando, false);
      expect(viewModel.emailEnviado, 'maria@email.com');
    });

    test('Deve tratar e-mail sem conta como enviado, sem revelar se ele existe',
        () async {
      auth.erro = FirebaseAuthException(code: 'user-not-found');

      final sucesso = await viewModel.enviar('ninguem@email.com');

      expect(sucesso, true);
      expect(viewModel.emailEnviado, 'ninguem@email.com');
      expect(viewModel.mensagemErro, isNull);
    });

    test('Deve traduzir o e-mail inválido apontado pelo Firebase', () async {
      auth.erro = FirebaseAuthException(code: 'invalid-email');

      final sucesso = await viewModel.enviar('maria@email.com');

      expect(sucesso, false);
      expect(viewModel.mensagemErro, 'O e-mail informado não é válido.');
      expect(viewModel.emailEnviado, isNull);
      expect(viewModel.carregando, false);
    });

    test('Deve avisar quando está sem internet', () async {
      auth.erro = FirebaseAuthException(code: 'network-request-failed');

      await viewModel.enviar('maria@email.com');

      expect(
        viewModel.mensagemErro,
        'Sem conexão com a internet. Verifique sua rede.',
      );
    });

    test('Deve avisar do excesso de pedidos', () async {
      auth.erro = FirebaseAuthException(code: 'too-many-requests');

      await viewModel.enviar('maria@email.com');

      expect(viewModel.mensagemErro, contains('Aguarde alguns minutos'));
    });

    test('Deve dar uma mensagem genérica para um erro inesperado', () async {
      auth.erro = Exception('falha qualquer');

      final sucesso = await viewModel.enviar('maria@email.com');

      expect(sucesso, false);
      expect(
        viewModel.mensagemErro,
        'Não foi possível enviar o e-mail. Tente novamente.',
      );
      expect(viewModel.carregando, false);
    });

    test('Deve limpar o erro da tentativa anterior ao tentar de novo', () async {
      await viewModel.enviar('maria@email');
      expect(viewModel.mensagemErro, isNotNull);

      final sucesso = await viewModel.enviar('maria@email.com');

      expect(sucesso, true);
      expect(viewModel.mensagemErro, isNull);
    });
  });
}
