import 'package:cloud_firestore/cloud_firestore.dart';
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
        'tipoDiabetes': 'Tipo 2',
        'possuiCardiopatia': false,
        'codigoVinculo': '12345',
        'triagemConcluida': true,
      };

      final paciente = Paciente.fromJson(mapJson, 'id-123');

      expect(paciente.id, 'id-123');
      expect(paciente.nome, 'João Silva');
      expect(paciente.possuiDiabetes, true);
      expect(paciente.tipoDiabetes, 'Tipo 2');
      expect(paciente.triagemConcluida, true);
    });

    test('Deve converter os campos de saúde da triagem a partir do JSON do Firebase', () {
      final mapJson = {
        'nome': 'João Silva',
        'email': 'joao@email.com',
        'perfil': 'Paciente',
        'possuiDiabetes': true,
        'tipoDiabetes': 'Tipo 1',
        'usaInsulina': true,
        'tipoInsulina': 'NPH',
        'possuiCardiopatia': true,
        'tipoCardiopatia': 'Hipertensão',
        'usaMarcapasso': false,
        'codigoVinculo': '12345',
        'triagemConcluida': true,
        'dataNascimento': Timestamp.fromDate(DateTime(1960, 5, 10)),
        'sexoBiologico': 'Masculino',
        'alturaCm': 175.0,
        'pesoKg': 80.0,
        'nivelAtividadeFisica': 'Moderado',
        'alergias': 'Dipirona',
        'medicamentosEmUso': 'Losartana',
      };

      final paciente = Paciente.fromJson(mapJson, 'id-123');

      expect(paciente.usaInsulina, true);
      expect(paciente.tipoInsulina, 'NPH');
      expect(paciente.tipoCardiopatia, 'Hipertensão');
      expect(paciente.usaMarcapasso, false);
      expect(paciente.dataNascimento, DateTime(1960, 5, 10));
      expect(paciente.sexoBiologico, 'Masculino');
      expect(paciente.alturaCm, 175.0);
      expect(paciente.pesoKg, 80.0);
      expect(paciente.nivelAtividadeFisica, 'Moderado');
      expect(paciente.alergias, 'Dipirona');
      expect(paciente.medicamentosEmUso, 'Losartana');
    });

    test('Deve usar valores padrão quando os campos da triagem não existem no JSON', () {
      final mapJson = {
        'nome': 'João Silva',
        'email': 'joao@email.com',
        'perfil': 'Paciente',
        'possuiDiabetes': false,
        'possuiCardiopatia': false,
        'codigoVinculo': '12345',
      };

      final paciente = Paciente.fromJson(mapJson, 'id-123');

      expect(paciente.tipoDiabetes, isNull);
      expect(paciente.triagemConcluida, false);
      expect(paciente.dataNascimento, isNull);
      expect(paciente.alturaCm, isNull);
    });

    test('Deve converter Objeto Paciente para JSON corretamente', () {
      final paciente = Paciente(
        id: 'id-123',
        nome: 'João Silva',
        email: 'joao@email.com',
        perfil: 'Paciente',
        possuiDiabetes: true,
        tipoDiabetes: 'Tipo 1',
        usaInsulina: true,
        tipoInsulina: 'NPH',
        possuiCardiopatia: false,
        codigoVinculo: '12345',
        triagemConcluida: true,
        dataNascimento: DateTime(1960, 5, 10),
        sexoBiologico: 'Masculino',
        alturaCm: 175.0,
        pesoKg: 80.0,
        nivelAtividadeFisica: 'Moderado',
      );

      final json = paciente.toJson();

      expect(json['nome'], 'João Silva');
      expect(json['possuiDiabetes'], true);
      expect(json['tipoDiabetes'], 'Tipo 1');
      expect(json['usaInsulina'], true);
      expect(json['tipoInsulina'], 'NPH');
      expect(json['alturaCm'], 175.0);
      expect(json['pesoKg'], 80.0);
      expect(json['nivelAtividadeFisica'], 'Moderado');
      expect(json['triagemConcluida'], true);
      expect(json.containsKey('id'), false);
    });
  });
}
