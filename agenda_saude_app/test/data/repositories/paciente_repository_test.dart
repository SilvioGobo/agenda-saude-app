import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
void main() {
  group('PacienteRepository Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late PacienteRepository repository;


    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = PacienteRepository(firestore: fakeFirestore);
    });

    Paciente criarPaciente({String codigo = 'ABC12'}) {
      return Paciente(
        id: 'paciente_001',
        nome: 'João da Silva',
        email: 'joao@email.com',
        perfil: 'Paciente',
        possuiDiabetes: true,
        possuiCardiopatia: false,
        codigoVinculo: codigo,
      );
    }

    test('Deve salvar e buscar um paciente no banco simulado', () async {

      final paciente = criarPaciente();


      await repository.salvarPaciente(paciente);


      final resultado = await repository.getPaciente('paciente_001');


      expect(resultado, isNotNull);
      expect(resultado!.nome, 'João da Silva');
      expect(resultado.possuiDiabetes, true);
      expect(resultado.codigoVinculo, 'ABC12');
    });

    test('Deve retornar null ao buscar um paciente inexistente', () async {

      final resultado = await repository.getPaciente('id_invalido');

      expect(resultado, isNull);
    });

    test('Deve publicar o código de vínculo ao salvar o paciente', () async {
      await repository.salvarPaciente(criarPaciente(codigo: 'ABC123'));

      final doc =
          await fakeFirestore.collection('codigos_vinculo').doc('ABC123').get();

      expect(doc.exists, true);
      expect(doc.data()!['pacienteId'], 'paciente_001');
      expect(doc.data()!['nomePaciente'], 'João da Silva');
    });

    test('Não deve publicar código quando o paciente não tem código', () async {
      await repository.salvarPaciente(criarPaciente(codigo: ''));

      final codigos = await fakeFirestore.collection('codigos_vinculo').get();

      expect(codigos.docs, isEmpty);
    });

    test('Deve encontrar o paciente pelo código de vínculo', () async {
      await repository.salvarPaciente(criarPaciente(codigo: 'ABC123'));

      final resultado = await repository.buscarPorCodigoVinculo('ABC123');

      expect(resultado, isNotNull);
      expect(resultado!.codigo, 'ABC123');
      expect(resultado.pacienteId, 'paciente_001');
      expect(resultado.nomePaciente, 'João da Silva');
    });

    test('Deve normalizar o código digitado (minúsculas e espaços) antes de buscar', () async {
      await repository.salvarPaciente(criarPaciente(codigo: 'ABC123'));

      final resultado = await repository.buscarPorCodigoVinculo(' abc 123 ');

      expect(resultado, isNotNull);
      expect(resultado!.pacienteId, 'paciente_001');
    });

    test('Deve retornar null para um código inexistente ou vazio', () async {
      expect(await repository.buscarPorCodigoVinculo('ZZZ999'), isNull);
      expect(await repository.buscarPorCodigoVinculo('   '), isNull);
    });

    test('Deve publicar o código de uma conta antiga que ainda não estava em codigos_vinculo', () async {
      // Conta criada antes do modulo de vinculo: doc do paciente existe, mas
      // sem a entrada de consulta.
      await fakeFirestore
          .collection('usuarios')
          .doc('paciente_001')
          .set(criarPaciente(codigo: 'QWE789').toJson());
      final paciente = (await repository.getPaciente('paciente_001'))!;

      await repository.publicarCodigoVinculo(paciente);

      final resultado = await repository.buscarPorCodigoVinculo('QWE789');
      expect(resultado, isNotNull);
      expect(resultado!.pacienteId, 'paciente_001');
    });
  });
}
