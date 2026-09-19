import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/acompanhante_repository.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/domain/models/acompanhante.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/acompanhante/vincular_paciente_viewmodel.dart';

void main() {
  group('VincularPacienteViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late PacienteRepository pacienteRepository;
    late AcompanhanteRepository acompanhanteRepository;
    late Acompanhante acompanhante;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      pacienteRepository = PacienteRepository(firestore: fakeFirestore);
      acompanhanteRepository = AcompanhanteRepository(firestore: fakeFirestore);

      acompanhante = Acompanhante(
        id: 'cuidador_01',
        nome: 'Carlos Souza',
        email: 'carlos@email.com',
        perfil: 'Acompanhante',
        pacientesVinculadosIds: [],
      );
      await acompanhanteRepository.salvarAcompanhante(acompanhante);

      await pacienteRepository.salvarPaciente(Paciente(
        id: 'paciente_01',
        nome: 'José Silva',
        email: 'jose@email.com',
        perfil: 'Paciente',
        possuiDiabetes: false,
        possuiCardiopatia: false,
        codigoVinculo: 'ABC123',
      ));
    });

    VincularPacienteViewModel criarViewModel({Acompanhante? acompanhanteAtual}) {
      return VincularPacienteViewModel(
        acompanhante: acompanhanteAtual ?? acompanhante,
        pacienteRepository: pacienteRepository,
        acompanhanteRepository: acompanhanteRepository,
      );
    }

    test('Deve rejeitar código com tamanho diferente de 6 sem consultar o banco', () async {
      final viewModel = criarViewModel();

      final encontrou = await viewModel.buscarPaciente('ABC');

      expect(encontrou, false);
      expect(viewModel.mensagemErro, contains('6 caracteres'));
      expect(viewModel.pacienteEncontrado, isNull);
    });

    test('Deve encontrar o paciente pelo código e guardar o nome para confirmação', () async {
      final viewModel = criarViewModel();

      final encontrou = await viewModel.buscarPaciente('abc123');

      expect(encontrou, true);
      expect(viewModel.mensagemErro, isNull);
      expect(viewModel.pacienteEncontrado, isNotNull);
      expect(viewModel.pacienteEncontrado!.pacienteId, 'paciente_01');
      expect(viewModel.pacienteEncontrado!.nomePaciente, 'José Silva');
      expect(viewModel.vinculoConcluido, false);
    });

    test('Deve informar quando o código não existe', () async {
      final viewModel = criarViewModel();

      final encontrou = await viewModel.buscarPaciente('ZZZ999');

      expect(encontrou, false);
      expect(viewModel.mensagemErro, 'Código não encontrado. Confira com o paciente.');
      expect(viewModel.pacienteEncontrado, isNull);
    });

    test('Deve avisar quando o paciente já está vinculado ao acompanhante', () async {
      final jaVinculado = Acompanhante(
        id: acompanhante.id,
        nome: acompanhante.nome,
        email: acompanhante.email,
        perfil: acompanhante.perfil,
        pacientesVinculadosIds: ['paciente_01'],
      );
      final viewModel = criarViewModel(acompanhanteAtual: jaVinculado);

      final encontrou = await viewModel.buscarPaciente('ABC123');

      expect(encontrou, false);
      expect(viewModel.mensagemErro, 'Este paciente já está vinculado à sua conta.');
      expect(viewModel.pacienteEncontrado, isNull);
    });

    test('Deve gravar o vínculo nos dois lados ao confirmar', () async {
      final viewModel = criarViewModel();
      await viewModel.buscarPaciente('ABC123');

      final sucesso = await viewModel.confirmarVinculo();

      expect(sucesso, true);
      expect(viewModel.vinculoConcluido, true);
      expect(viewModel.carregando, false);

      final acompanhanteSalvo =
          await acompanhanteRepository.getAcompanhante('cuidador_01');
      expect(acompanhanteSalvo!.pacientesVinculadosIds, ['paciente_01']);

      final pacienteSalvo = await pacienteRepository.getPaciente('paciente_01');
      expect(pacienteSalvo!.acompanhantesVinculadosIds, ['cuidador_01']);
    });

    test('Não deve confirmar sem ter buscado um paciente antes', () async {
      final viewModel = criarViewModel();

      final sucesso = await viewModel.confirmarVinculo();

      expect(sucesso, false);
      expect(viewModel.vinculoConcluido, false);
    });

    test('Deve voltar para a etapa de digitar o código ao descartar o paciente encontrado', () async {
      final viewModel = criarViewModel();
      await viewModel.buscarPaciente('ABC123');

      viewModel.digitarOutroCodigo();

      expect(viewModel.pacienteEncontrado, isNull);
      expect(viewModel.mensagemErro, isNull);
    });
  });
}
