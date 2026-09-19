import 'package:flutter_test/flutter_test.dart';
import 'package:agenda_saude_app/domain/models/codigo_vinculo.dart';

void main() {
  group('CodigoVinculo Model Testes', () {
    test('Deve converter JSON para Objeto CodigoVinculo usando o id do doc como código', () {
      final mapJson = {
        'pacienteId': 'paciente_01',
        'nomePaciente': 'José Silva',
      };

      final codigo = CodigoVinculo.fromJson(mapJson, 'ABC123');

      expect(codigo.codigo, 'ABC123');
      expect(codigo.pacienteId, 'paciente_01');
      expect(codigo.nomePaciente, 'José Silva');
    });

    test('Deve usar valores padrão quando os campos não existem no JSON', () {
      final codigo = CodigoVinculo.fromJson({}, 'ABC123');

      expect(codigo.pacienteId, '');
      expect(codigo.nomePaciente, '');
    });

    test('Deve converter Objeto CodigoVinculo para JSON sem repetir o código', () {
      final codigo = CodigoVinculo(
        codigo: 'ABC123',
        pacienteId: 'paciente_01',
        nomePaciente: 'José Silva',
      );

      final json = codigo.toJson();

      expect(json['pacienteId'], 'paciente_01');
      expect(json['nomePaciente'], 'José Silva');
      expect(json.containsKey('codigo'), false);
    });
  });
}
