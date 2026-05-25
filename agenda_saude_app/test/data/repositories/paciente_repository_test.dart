import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart'; // Ajuste se necessário
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart'; // Ajuste se necessário

void main() {
  group('PacienteRepository Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late PacienteRepository repository;

    // Roda antes de cada teste para garantir um banco limpo
    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = PacienteRepository(firestore: fakeFirestore);
    });

    test('Deve salvar e buscar um paciente no banco simulado', () async {
      // 1. Preparação (Arrange)
      final paciente = Paciente(
        id: 'paciente_001',
        nome: 'João da Silva',
        email: 'joao@email.com',
        perfil: 'Paciente',
        possuiDiabetes: true,
        possuiCardiopatia: false,
        codigoVinculo: 'ABC12',
      );

      // 2. Ação (Act) - Salvar no banco falso
      await repository.salvarPaciente(paciente);

      // 3. Ação (Act) - Buscar do banco falso
      final resultado = await repository.getPaciente('paciente_001');

      // 4. Verificação (Assert)
      expect(resultado, isNotNull);
      expect(resultado!.nome, 'João da Silva');
      expect(resultado.possuiDiabetes, true);
      expect(resultado.codigoVinculo, 'ABC12');
    });

    test('Deve retornar null ao buscar um paciente inexistente', () async {
      // Tenta buscar um ID que não salvamos
      final resultado = await repository.getPaciente('id_invalido');

      expect(resultado, isNull);
    });
  });
}