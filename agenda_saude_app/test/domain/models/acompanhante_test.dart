import 'package:flutter_test/flutter_test.dart';
import 'package:agenda_saude_app/domain/models/acompanhante.dart';

void main() {
  group('Acompanhante Model Testes', () {
    test('Deve criar um Acompanhante a partir de um JSON do Firebase', () {

      final jsonFirebase = {
        'nome': 'Silvio Gobo',
        'email': 'silvio@email.com',
        'perfil': 'Acompanhante',
        'pacientesVinculadosIds': ['paciente123', 'paciente456']
      };


      final acompanhante = Acompanhante.fromJson(jsonFirebase, 'acompanhante789');


      expect(acompanhante.id, 'acompanhante789');
      expect(acompanhante.nome, 'Silvio Gobo');
      expect(acompanhante.pacientesVinculadosIds.length, 2);
      expect(acompanhante.pacientesVinculadosIds.first, 'paciente123');
      // Conta sem o campo: sem telefone para ligar.
      expect(acompanhante.telefone, isNull);
      expect(acompanhante.temTelefone, isFalse);
    });

    test('Deve guardar e ler o telefone pelo JSON', () {
      final acompanhante = Acompanhante(
        id: 'acompanhante789',
        nome: 'Silvio Gobo',
        email: 'silvio@email.com',
        perfil: 'Acompanhante',
        telefone: '67988887777',
        pacientesVinculadosIds: const [],
      );

      final json = acompanhante.toJson();
      expect(json['telefone'], '67988887777');

      final lido = Acompanhante.fromJson(json, 'acompanhante789');
      expect(lido.telefone, '67988887777');
      expect(lido.temTelefone, isTrue);
    });
  });
}
