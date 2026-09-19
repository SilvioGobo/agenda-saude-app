import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:agenda_saude_app/domain/models/acompanhante.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/data/repositories/acompanhante_repository.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';

void main() {
  group('AcompanhanteRepository Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AcompanhanteRepository repository;


    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = AcompanhanteRepository(firestore: fakeFirestore);
    });

    Future<void> salvarPacienteDeTeste(String id, String nome) async {
      await PacienteRepository(firestore: fakeFirestore).salvarPaciente(
        Paciente(
          id: id,
          nome: nome,
          email: '$id@email.com',
          perfil: 'Paciente',
          possuiDiabetes: false,
          possuiCardiopatia: false,
          codigoVinculo: 'COD$id',
        ),
      );
    }

    test('Deve salvar e buscar um acompanhante no banco simulado', () async {

      final acompanhante = Acompanhante(
        id: 'cuidador_123',
        nome: 'Silvio Gobo',
        email: 'silvio@email.com',
        perfil: 'Acompanhante',
        pacientesVinculadosIds: [],
      );

      await repository.salvarAcompanhante(acompanhante);

      final resultado = await repository.getAcompanhante('cuidador_123');

      expect(resultado, isNotNull);
      expect(resultado!.nome, 'Silvio Gobo');
      expect(resultado.email, 'silvio@email.com');
    });

    test('Deve adicionar o ID do paciente na lista de vínculos do acompanhante', () async {

      await fakeFirestore.collection('usuarios').doc('cuidador_123').set({
        'nome': 'Silvio Gobo',
        'email': 'silvio@email.com',
        'perfil': 'Acompanhante',
        'pacientesVinculadosIds': [],
      });
      await salvarPacienteDeTeste('paciente_idoso_999', 'José Silva');

      await repository.vincularPaciente('cuidador_123', 'paciente_idoso_999');

      final resultado = await repository.getAcompanhante('cuidador_123');

      expect(resultado!.pacientesVinculadosIds.contains('paciente_idoso_999'), true);
    });

    test('Deve gravar o vínculo nos dois lados (acompanhante e paciente)', () async {
      await fakeFirestore.collection('usuarios').doc('cuidador_123').set({
        'nome': 'Silvio Gobo',
        'email': 'silvio@email.com',
        'perfil': 'Acompanhante',
        'pacientesVinculadosIds': [],
      });
      await salvarPacienteDeTeste('paciente_01', 'José Silva');

      await repository.vincularPaciente('cuidador_123', 'paciente_01');

      final paciente = await PacienteRepository(firestore: fakeFirestore)
          .getPaciente('paciente_01');
      expect(paciente!.acompanhantesVinculadosIds, ['cuidador_123']);
    });

    test('Não deve duplicar o vínculo ao vincular o mesmo paciente duas vezes', () async {
      await fakeFirestore.collection('usuarios').doc('cuidador_123').set({
        'nome': 'Silvio Gobo',
        'email': 'silvio@email.com',
        'perfil': 'Acompanhante',
        'pacientesVinculadosIds': [],
      });
      await salvarPacienteDeTeste('paciente_01', 'José Silva');

      await repository.vincularPaciente('cuidador_123', 'paciente_01');
      await repository.vincularPaciente('cuidador_123', 'paciente_01');

      final acompanhante = await repository.getAcompanhante('cuidador_123');
      expect(acompanhante!.pacientesVinculadosIds, ['paciente_01']);
    });

    test('Deve remover o vínculo dos dois lados ao desvincular', () async {
      await fakeFirestore.collection('usuarios').doc('cuidador_123').set({
        'nome': 'Silvio Gobo',
        'email': 'silvio@email.com',
        'perfil': 'Acompanhante',
        'pacientesVinculadosIds': [],
      });
      await salvarPacienteDeTeste('paciente_01', 'José Silva');
      await salvarPacienteDeTeste('paciente_02', 'Maria Souza');
      await repository.vincularPaciente('cuidador_123', 'paciente_01');
      await repository.vincularPaciente('cuidador_123', 'paciente_02');

      await repository.desvincularPaciente('cuidador_123', 'paciente_01');

      final acompanhante = await repository.getAcompanhante('cuidador_123');
      expect(acompanhante!.pacientesVinculadosIds, ['paciente_02']);

      final pacienteRepository = PacienteRepository(firestore: fakeFirestore);
      final paciente01 = await pacienteRepository.getPaciente('paciente_01');
      final paciente02 = await pacienteRepository.getPaciente('paciente_02');
      expect(paciente01!.acompanhantesVinculadosIds, isEmpty);
      expect(paciente02!.acompanhantesVinculadosIds, ['cuidador_123']);
    });

    test('Deve listar os pacientes vinculados na ordem da lista do acompanhante', () async {
      await salvarPacienteDeTeste('paciente_01', 'José Silva');
      await salvarPacienteDeTeste('paciente_02', 'Maria Souza');
      final acompanhante = Acompanhante(
        id: 'cuidador_123',
        nome: 'Silvio Gobo',
        email: 'silvio@email.com',
        perfil: 'Acompanhante',
        pacientesVinculadosIds: ['paciente_02', 'paciente_01'],
      );

      final pacientes = await repository.listarPacientesVinculados(acompanhante);

      expect(pacientes.map((p) => p.nome).toList(), ['Maria Souza', 'José Silva']);
    });

    test('Deve ignorar ids de pacientes que não existem mais ao listar', () async {
      await salvarPacienteDeTeste('paciente_01', 'José Silva');
      final acompanhante = Acompanhante(
        id: 'cuidador_123',
        nome: 'Silvio Gobo',
        email: 'silvio@email.com',
        perfil: 'Acompanhante',
        pacientesVinculadosIds: ['paciente_01', 'paciente_apagado'],
      );

      final pacientes = await repository.listarPacientesVinculados(acompanhante);

      expect(pacientes.length, 1);
      expect(pacientes.first.id, 'paciente_01');
    });

    test('Deve retornar lista vazia quando o acompanhante não tem vínculos', () async {
      final acompanhante = Acompanhante(
        id: 'cuidador_123',
        nome: 'Silvio Gobo',
        email: 'silvio@email.com',
        perfil: 'Acompanhante',
        pacientesVinculadosIds: [],
      );

      final pacientes = await repository.listarPacientesVinculados(acompanhante);

      expect(pacientes, isEmpty);
    });
  });
}
