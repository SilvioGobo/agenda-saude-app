import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/acompanhante_repository.dart';
import 'package:agenda_saude_app/data/repositories/auth_repository.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/ui/auth/auth_viewmodel.dart';

// Substitui a chamada real ao Firebase Auth por um UID previsível,
// para testar o AuthViewModel sem depender do Firebase de verdade.
class _AuthRepositoryFalso extends AuthRepository {
  int chamadas = 0;

  @override
  Future<String> cadastrar({required String email, required String senha}) async {
    chamadas++;
    return 'uid_falso_$chamadas';
  }
}

void main() {
  group('AuthViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AuthViewModel viewModel;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      viewModel = AuthViewModel(
        authRepository: _AuthRepositoryFalso(),
        pacienteRepository: PacienteRepository(firestore: fakeFirestore),
        acompanhanteRepository: AcompanhanteRepository(firestore: fakeFirestore),
      );
    });

    test('Deve exigir a seleção de perfil antes de cadastrar', () async {
      final sucesso = await viewModel.cadastrar(
        nome: 'Maria Souza',
        email: 'maria@email.com',
        senha: '123456',
      );

      expect(sucesso, false);
      expect(viewModel.mensagemErro, isNotNull);
    });

    test('Deve exigir nome, e-mail e senha preenchidos', () async {
      viewModel.selecionarPerfil('Paciente');

      final sucesso = await viewModel.cadastrar(
        nome: '',
        email: 'maria@email.com',
        senha: '123456',
      );

      expect(sucesso, false);
      expect(viewModel.mensagemErro, isNotNull);
    });

    test('Deve rejeitar e-mail com formato inválido', () async {
      viewModel.selecionarPerfil('Paciente');

      final sucesso = await viewModel.cadastrar(
        nome: 'Maria Souza',
        email: 'mariaemail.com',
        senha: '123456',
      );

      expect(sucesso, false);
      expect(viewModel.mensagemErro, isNotNull);
    });

    test('Deve rejeitar senha fraca (caractere repetido)', () async {
      viewModel.selecionarPerfil('Paciente');

      final sucesso = await viewModel.cadastrar(
        nome: 'Maria Souza',
        email: 'maria@email.com',
        senha: '111111',
      );

      expect(sucesso, false);
      expect(viewModel.mensagemErro, isNotNull);
    });

    test('Deve rejeitar senha fraca (menos de 6 caracteres)', () async {
      viewModel.selecionarPerfil('Paciente');

      final sucesso = await viewModel.cadastrar(
        nome: 'Maria Souza',
        email: 'maria@email.com',
        senha: 'abc12',
      );

      expect(sucesso, false);
      expect(viewModel.mensagemErro, isNotNull);
    });

    test('Deve aceitar senha de força média', () async {
      viewModel.selecionarPerfil('Paciente');

      final sucesso = await viewModel.cadastrar(
        nome: 'Maria Souza',
        email: 'maria@email.com',
        senha: '123456',
      );

      expect(sucesso, true);
    });

    test('Deve cadastrar um Paciente e salvar no banco simulado', () async {
      viewModel.selecionarPerfil('Paciente');

      final sucesso = await viewModel.cadastrar(
        nome: 'Maria Souza',
        email: 'maria@email.com',
        senha: '123456',
      );

      expect(sucesso, true);
      expect(viewModel.carregando, false);
      expect(viewModel.mensagemErro, isNull);

      final paciente = await PacienteRepository(firestore: fakeFirestore)
          .getPaciente('uid_falso_1');

      expect(paciente, isNotNull);
      expect(paciente!.nome, 'Maria Souza');
      expect(paciente.email, 'maria@email.com');
      expect(paciente.possuiDiabetes, false);
      expect(paciente.possuiCardiopatia, false);
      expect(paciente.codigoVinculo.length, 6);
      expect(paciente.triagemConcluida, false);

      expect(viewModel.pacienteCriado, isNotNull);
      expect(viewModel.pacienteCriado!.id, 'uid_falso_1');
    });

    test('Deve cadastrar um Acompanhante e salvar no banco simulado', () async {
      viewModel.selecionarPerfil('Acompanhante');

      final sucesso = await viewModel.cadastrar(
        nome: 'Carlos Souza',
        email: 'carlos@email.com',
        senha: '123456',
      );

      expect(sucesso, true);

      final acompanhante = await AcompanhanteRepository(firestore: fakeFirestore)
          .getAcompanhante('uid_falso_1');

      expect(acompanhante, isNotNull);
      expect(acompanhante!.nome, 'Carlos Souza');
      expect(acompanhante.pacientesVinculadosIds, isEmpty);
    });
  });

  group('calcularForcaSenha Testes', () {
    test('Deve classificar senha vazia', () {
      expect(calcularForcaSenha(''), ForcaSenha.vazia);
    });

    test('Deve classificar senha curta como fraca', () {
      expect(calcularForcaSenha('abc12'), ForcaSenha.fraca);
    });

    test('Deve classificar caractere repetido como fraca mesmo com 6+ caracteres', () {
      expect(calcularForcaSenha('aaaaaa'), ForcaSenha.fraca);
    });

    test('Deve classificar senha só numérica de 6 caracteres como média', () {
      expect(calcularForcaSenha('123456'), ForcaSenha.media);
    });

    test('Deve classificar senha longa com letras e números como forte', () {
      expect(calcularForcaSenha('Teste123456'), ForcaSenha.forte);
    });
  });

  group('emailValido Testes', () {
    test('Deve aceitar e-mail em formato válido', () {
      expect(emailValido('maria@email.com'), true);
    });

    test('Deve rejeitar e-mail sem @', () {
      expect(emailValido('mariaemail.com'), false);
    });

    test('Deve rejeitar e-mail sem domínio', () {
      expect(emailValido('maria@email'), false);
    });
  });
}
