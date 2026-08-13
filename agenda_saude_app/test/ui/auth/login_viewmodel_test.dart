import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/acompanhante_repository.dart';
import 'package:agenda_saude_app/data/repositories/auth_repository.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/ui/auth/login_viewmodel.dart';

// Substitui a autenticacao real por um UID fixo, para testar o
// LoginViewModel sem depender do Firebase de verdade.
class _AuthRepositoryFalso extends AuthRepository {
  final String uidRetornado;

  _AuthRepositoryFalso(this.uidRetornado);

  @override
  Future<String> entrar({required String email, required String senha}) async {
    return uidRetornado;
  }
}

void main() {
  group('LoginViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;

    LoginViewModel criarViewModel(String uidRetornado) {
      return LoginViewModel(
        authRepository: _AuthRepositoryFalso(uidRetornado),
        pacienteRepository: PacienteRepository(firestore: fakeFirestore),
        acompanhanteRepository: AcompanhanteRepository(firestore: fakeFirestore),
        firestore: fakeFirestore,
      );
    }

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    test('Deve exigir e-mail e senha preenchidos', () async {
      final viewModel = criarViewModel('uid_1');

      final sucesso = await viewModel.entrar(email: '', senha: '');

      expect(sucesso, false);
      expect(viewModel.mensagemErro, isNotNull);
    });

    test('Deve logar um Paciente que já concluiu a triagem', () async {
      await fakeFirestore.collection('usuarios').doc('uid_paciente').set({
        'nome': 'Maria Souza',
        'email': 'maria@email.com',
        'perfil': 'Paciente',
        'possuiDiabetes': true,
        'tipoDiabetes': 'Tipo 2',
        'possuiCardiopatia': false,
        'codigoVinculo': 'ABC123',
        'triagemConcluida': true,
      });

      final viewModel = criarViewModel('uid_paciente');

      final sucesso = await viewModel.entrar(
        email: 'maria@email.com',
        senha: '123456',
      );

      expect(sucesso, true);
      expect(viewModel.pacienteLogado, isNotNull);
      expect(viewModel.pacienteLogado!.nome, 'Maria Souza');
      expect(viewModel.pacienteLogado!.triagemConcluida, true);
      expect(viewModel.acompanhanteLogado, isNull);
    });

    test('Deve logar um Acompanhante e carregar seus dados', () async {
      await fakeFirestore.collection('usuarios').doc('uid_acompanhante').set({
        'nome': 'Carlos Souza',
        'email': 'carlos@email.com',
        'perfil': 'Acompanhante',
        'pacientesVinculadosIds': [],
      });

      final viewModel = criarViewModel('uid_acompanhante');

      final sucesso = await viewModel.entrar(
        email: 'carlos@email.com',
        senha: '123456',
      );

      expect(sucesso, true);
      expect(viewModel.acompanhanteLogado, isNotNull);
      expect(viewModel.acompanhanteLogado!.nome, 'Carlos Souza');
      expect(viewModel.pacienteLogado, isNull);
    });

    test('Deve retornar erro quando o documento do usuário não existe', () async {
      final viewModel = criarViewModel('uid_inexistente');

      final sucesso = await viewModel.entrar(
        email: 'x@x.com',
        senha: '123456',
      );

      expect(sucesso, false);
      expect(viewModel.mensagemErro, isNotNull);
    });
  });
}
