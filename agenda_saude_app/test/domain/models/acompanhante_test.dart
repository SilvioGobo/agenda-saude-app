import 'package:flutter_test/flutter_test.dart';
import 'package:agenda_saude_app/domain/models/acompanhante.dart';

void main() {
  group('Acompanhante Model Testes', () {
    test('Deve criar um Acompanhante a partir de um JSON do Firebase', () {
      // 1. Preparação (Arrange)
      final jsonFirebase = {
        'nome': 'Silvio Gobo',
        'email': 'silvio@email.com',
        'perfil': 'Acompanhante',
        'pacientesVinculadosIds': ['paciente123', 'paciente456']
      };

      // 2. Ação (Act)
      final acompanhante = Acompanhante.fromJson(jsonFirebase, 'acompanhante789');

      // 3. Verificação (Assert)
      expect(acompanhante.id, 'acompanhante789');
      expect(acompanhante.nome, 'Silvio Gobo');
      expect(acompanhante.pacientesVinculadosIds.length, 2);
      expect(acompanhante.pacientesVinculadosIds.first, 'paciente123');
    });
  });
}