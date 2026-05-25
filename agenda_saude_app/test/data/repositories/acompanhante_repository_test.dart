import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:agenda_saude_app/domain/models/acompanhante.dart';
import 'package:agenda_saude_app/data/repositories/acompanhante_repository.dart';

void main() {
  group('AcompanhanteRepository Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AcompanhanteRepository repository;

    // Roda antes de cada teste para limpar o ambiente
    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = AcompanhanteRepository(firestore: fakeFirestore);
    });

    test('Deve salvar e buscar um acompanhante no banco simulado', () async {
      // 1. Criar objeto de teste
      final acompanhante = Acompanhante(
        id: 'cuidador_123',
        nome: 'Silvio Gobo',
        email: 'silvio@email.com',
        perfil: 'Acompanhante',
        pacientesVinculadosIds: [],
      );

      // 2. Executar a ação de salvar
      await repository.salvarAcompanhante(acompanhante);

      // 3. Buscar do banco simulado
      final resultado = await repository.getAcompanhante('cuidador_123');

      // 4. Validações
      expect(resultado, isNotNull);
      expect(resultado!.nome, 'Silvio Gobo');
      expect(resultado.email, 'silvio@email.com');
    });

    test('Deve adicionar o ID do paciente na lista de vínculos do acompanhante', () async {
      // Criando o acompanhante base no banco simulado
      await fakeFirestore.collection('usuarios').doc('cuidador_123').set({
        'nome': 'Silvio Gobo',
        'email': 'silvio@email.com',
        'perfil': 'Acompanhante',
        'pacientesVinculadosIds': [],
      });

      // Executa o vínculo
      await repository.vincularPaciente('cuidador_123', 'paciente_idoso_999');

      // Recupera para ver se mudou
      final resultado = await repository.getAcompanhante('cuidador_123');

      expect(resultado!.pacientesVinculadosIds.contains('paciente_idoso_999'), true);
    });
  });
}