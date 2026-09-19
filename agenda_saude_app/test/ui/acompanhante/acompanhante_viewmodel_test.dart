import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/acompanhante_repository.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/domain/models/acompanhante.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/acompanhante/acompanhante_viewmodel.dart';

void main() {
  group('AcompanhanteViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AcompanhanteRepository acompanhanteRepository;
    late PacienteRepository pacienteRepository;
    late Acompanhante acompanhante;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      acompanhanteRepository = AcompanhanteRepository(firestore: fakeFirestore);
      pacienteRepository = PacienteRepository(firestore: fakeFirestore);

      acompanhante = Acompanhante(
        id: 'cuidador_01',
        nome: 'Carlos Souza',
        email: 'carlos@email.com',
        perfil: 'Acompanhante',
        pacientesVinculadosIds: [],
      );
      await acompanhanteRepository.salvarAcompanhante(acompanhante);

      for (final (id, nome) in [('paciente_01', 'José Silva'), ('paciente_02', 'Maria Souza')]) {
        await pacienteRepository.salvarPaciente(Paciente(
          id: id,
          nome: nome,
          email: '$id@email.com',
          perfil: 'Paciente',
          possuiDiabetes: false,
          possuiCardiopatia: false,
          codigoVinculo: 'COD$id',
        ));
      }
    });

    AcompanhanteViewModel criarViewModel() {
      return AcompanhanteViewModel(
        acompanhante: acompanhante,
        acompanhanteRepository: acompanhanteRepository,
      );
    }

    test('Deve exibir o primeiro nome do acompanhante', () {
      expect(criarViewModel().primeiroNome, 'Carlos');
    });

    test('Deve começar sem pacientes e carregar lista vazia quando não há vínculos', () async {
      final viewModel = criarViewModel();

      await viewModel.carregarPacientes();

      expect(viewModel.pacientesVinculados, isEmpty);
      expect(viewModel.carregando, false);
      expect(viewModel.mensagemErro, isNull);
    });

    test('Deve recarregar a lista de ids do banco antes de buscar os pacientes', () async {
      // O vinculo e gravado depois de o ViewModel ja existir (ex.: ao voltar
      // da tela de vincular), entao a lista em memoria esta desatualizada.
      final viewModel = criarViewModel();
      await acompanhanteRepository.vincularPaciente('cuidador_01', 'paciente_01');
      await acompanhanteRepository.vincularPaciente('cuidador_01', 'paciente_02');

      await viewModel.carregarPacientes();

      expect(viewModel.acompanhante.pacientesVinculadosIds, ['paciente_01', 'paciente_02']);
      expect(
        viewModel.pacientesVinculados.map((p) => p.nome).toList(),
        ['José Silva', 'Maria Souza'],
      );
    });

    test('Deve desvincular um paciente e removê-lo da lista sem recarregar', () async {
      await acompanhanteRepository.vincularPaciente('cuidador_01', 'paciente_01');
      await acompanhanteRepository.vincularPaciente('cuidador_01', 'paciente_02');
      final viewModel = criarViewModel();
      await viewModel.carregarPacientes();
      final jose = viewModel.pacientesVinculados.first;

      final sucesso = await viewModel.desvincular(jose);

      expect(sucesso, true);
      expect(viewModel.pacientesVinculados.map((p) => p.id).toList(), ['paciente_02']);
      expect(viewModel.acompanhante.pacientesVinculadosIds, ['paciente_02']);

      final salvo = await acompanhanteRepository.getAcompanhante('cuidador_01');
      expect(salvo!.pacientesVinculadosIds, ['paciente_02']);
      final paciente = await pacienteRepository.getPaciente('paciente_01');
      expect(paciente!.acompanhantesVinculadosIds, isEmpty);
    });
  });
}
