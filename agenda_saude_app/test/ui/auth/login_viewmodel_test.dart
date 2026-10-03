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

// Simula um aparelho onde alguem ja entrou antes (sessao salva do Firebase Auth).
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

    test('Deve publicar o código de vínculo de uma conta antiga de Paciente ao logar', () async {
      // Conta criada antes do modulo de vinculo: tem o codigo no proprio doc,
      // mas nenhuma entrada em codigos_vinculo.
      await fakeFirestore.collection('usuarios').doc('uid_paciente').set({
        'nome': 'Maria Souza',
        'email': 'maria@email.com',
        'perfil': 'Paciente',
        'possuiDiabetes': false,
        'possuiCardiopatia': false,
        'codigoVinculo': 'QWE789',
        'triagemConcluida': true,
      });
      final viewModel = criarViewModel('uid_paciente');

      await viewModel.entrar(email: 'maria@email.com', senha: '123456');

      final encontrado = await PacienteRepository(firestore: fakeFirestore)
          .buscarPorCodigoVinculo('QWE789');
      expect(encontrado, isNotNull);
      expect(encontrado!.pacienteId, 'uid_paciente');
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

  group('LoginViewModel Sessão Salva Testes', () {
    late FakeFirebaseFirestore fakeFirestore;

    LoginViewModel criarViewModel(AuthRepository authRepository) {
      return LoginViewModel(
        authRepository: authRepository,
        pacienteRepository: PacienteRepository(firestore: fakeFirestore),
        acompanhanteRepository: AcompanhanteRepository(firestore: fakeFirestore),
        firestore: fakeFirestore,
      );
    }

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    test('Não deve restaurar nada quando ninguém entrou no aparelho', () async {
      final viewModel = criarViewModel(_AuthRepositoryComSessao(null));

      final restaurou = await viewModel.restaurarSessao();

      expect(restaurou, false);
      expect(viewModel.pacienteLogado, isNull);
      expect(viewModel.acompanhanteLogado, isNull);
      expect(viewModel.mensagemErro, isNull);
    });

    test('Deve restaurar a sessão salva de um Paciente sem pedir a senha', () async {
      await fakeFirestore.collection('usuarios').doc('uid_paciente').set({
        'nome': 'Maria Souza',
        'email': 'maria@email.com',
        'perfil': 'Paciente',
        'possuiDiabetes': false,
        'possuiCardiopatia': true,
        'codigoVinculo': 'ABC123',
        'triagemConcluida': true,
      });
      final auth = _AuthRepositoryComSessao('uid_paciente');
      final viewModel = criarViewModel(auth);

      final restaurou = await viewModel.restaurarSessao();

      expect(restaurou, true);
      expect(viewModel.pacienteLogado!.nome, 'Maria Souza');
      expect(viewModel.pacienteLogado!.triagemConcluida, true);
      expect(auth.saiu, false);
    });

    test('Deve restaurar a sessão salva de um Acompanhante', () async {
      await fakeFirestore.collection('usuarios').doc('uid_acompanhante').set({
        'nome': 'Carlos Souza',
        'email': 'carlos@email.com',
        'perfil': 'Acompanhante',
        'pacientesVinculadosIds': [],
      });
      final viewModel =
          criarViewModel(_AuthRepositoryComSessao('uid_acompanhante'));

      final restaurou = await viewModel.restaurarSessao();

      expect(restaurou, true);
      expect(viewModel.acompanhanteLogado!.nome, 'Carlos Souza');
      expect(viewModel.pacienteLogado, isNull);
    });

    test('Deve encerrar a sessão salva de uma conta sem perfil no Firestore', () async {
      // Cadastro que criou a conta no Auth mas falhou ao gravar o perfil.
      final auth = _AuthRepositoryComSessao('uid_sem_perfil');
      final viewModel = criarViewModel(auth);

      final restaurou = await viewModel.restaurarSessao();

      expect(restaurou, false);
      expect(auth.saiu, true);
      expect(viewModel.pacienteLogado, isNull);
      expect(viewModel.acompanhanteLogado, isNull);
    });
  });
}
