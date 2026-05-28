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

    test('Deve salvar e buscar um paciente no banco simulado', () async {

      final paciente = Paciente(
        id: 'paciente_001',
        nome: 'João da Silva',
        email: 'joao@email.com',
        perfil: 'Paciente',
        possuiDiabetes: true,
        possuiCardiopatia: false,
        codigoVinculo: 'ABC12',
      );


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
  });
}