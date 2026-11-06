import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/acompanhante_repository.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/domain/models/acompanhante.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/paciente/falar_com_acompanhante_viewmodel.dart';

class _AcompanhanteRepositoryComFalha extends AcompanhanteRepository {
  _AcompanhanteRepositoryComFalha() : super(firestore: FakeFirebaseFirestore());

  @override
  Future<List<Acompanhante>> listarAcompanhantesDoPaciente(
    String pacienteId,
  ) async {
    throw Exception('sem internet');
  }
}

void main() {
  group('FalarComAcompanhanteViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AcompanhanteRepository acompanhanteRepository;

    final paciente = Paciente(
      id: 'paciente_01',
      nome: 'José Silva',
      email: 'jose@email.com',
      perfil: 'Paciente',
      possuiDiabetes: false,
      possuiCardiopatia: false,
      codigoVinculo: 'ABC123',
    );

    Future<void> vincular(String id, String nome, {String? telefone}) async {
      await acompanhanteRepository.salvarAcompanhante(Acompanhante(
        id: id,
        nome: nome,
        email: '$id@email.com',
        perfil: 'Acompanhante',
        telefone: telefone,
        pacientesVinculadosIds: [],
      ));
      await acompanhanteRepository.vincularPaciente(id, paciente.id);
    }

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      acompanhanteRepository = AcompanhanteRepository(firestore: fakeFirestore);
      await PacienteRepository(firestore: fakeFirestore).salvarPaciente(paciente);
    });

    test('Deve começar carregando e trazer os acompanhantes, quem tem telefone primeiro', () async {
      await vincular('cuidador_01', 'Ana Lima');
      await vincular('cuidador_02', 'Carlos Souza', telefone: '67999990000');
      final viewModel = FalarComAcompanhanteViewModel(
        paciente: paciente,
        acompanhanteRepository: acompanhanteRepository,
      );
      expect(viewModel.carregando, isTrue);

      await viewModel.carregar();

      expect(viewModel.carregando, isFalse);
      expect(viewModel.erroAoCarregar, isFalse);
      expect(viewModel.acompanhantes.map((a) => a.nome), ['Carlos Souza', 'Ana Lima']);
    });

    test('Deve ficar com a lista vazia quando o paciente não tem acompanhante', () async {
      final viewModel = FalarComAcompanhanteViewModel(
        paciente: paciente,
        acompanhanteRepository: acompanhanteRepository,
      );

      await viewModel.carregar();

      expect(viewModel.acompanhantes, isEmpty);
      expect(viewModel.erroAoCarregar, isFalse);
    });

    test('Deve indicar erro quando não consegue carregar', () async {
      final viewModel = FalarComAcompanhanteViewModel(
        paciente: paciente,
        acompanhanteRepository: _AcompanhanteRepositoryComFalha(),
      );

      await viewModel.carregar();

      expect(viewModel.carregando, isFalse);
      expect(viewModel.erroAoCarregar, isTrue);
    });
  });
}
