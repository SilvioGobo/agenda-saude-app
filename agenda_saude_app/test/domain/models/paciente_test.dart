import 'package:flutter_test/flutter_test.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart'; // ajuste o import

void main() {
  group('Paciente Model Test', () {
    test('Deve converter JSON para Objeto Paciente corretamente', () {

      final mapJson = {
        'nome': 'João Silva',
        'email': 'joao@email.com',
        'perfil': 'Paciente',
        'possuiDiabetes': true,
        'possuiCardiopatia': false,
        'codigoVinculo': '12345'
      };

      final paciente = Paciente.fromJson(mapJson, 'id-123');

      expect(paciente.id, 'id-123');
      expect(paciente.nome, 'João Silva');
      expect(paciente.possuiDiabetes, true);
    });

    test('Deve converter Objeto Paciente para JSON corretamente', () {
      final paciente = Paciente(
        id: 'id-123',
        nome: 'João Silva',
        email: 'joao@email.com',
        perfil: 'Paciente',
        possuiDiabetes: true,
        possuiCardiopatia: false,
        codigoVinculo: '12345',
      );

      final json = paciente.toJson();

      expect(json['nome'], 'João Silva');
      expect(json['possuiDiabetes'], true);
      expect(json.containsKey('id'), false);
    });
  });
}