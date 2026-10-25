import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agenda_saude_app/domain/metas/metas_personalizadas.dart';
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
      expect(paciente.acompanhantesVinculadosIds, isEmpty);
    });

    test('Deve converter a lista de acompanhantes vinculados a partir do JSON', () {
      final mapJson = {
        'nome': 'João Silva',
        'email': 'joao@email.com',
        'perfil': 'Paciente',
        'possuiDiabetes': false,
        'possuiCardiopatia': false,
        'codigoVinculo': '12345',
        'acompanhantesVinculadosIds': ['cuidador_1', 'cuidador_2'],
      };

      final paciente = Paciente.fromJson(mapJson, 'id-123');

      expect(paciente.acompanhantesVinculadosIds, ['cuidador_1', 'cuidador_2']);
      expect(paciente.toJson()['acompanhantesVinculadosIds'], ['cuidador_1', 'cuidador_2']);
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

    test('Deve guardar e ler as metas e a restrição de líquido pelo JSON', () {
      final paciente = Paciente(
        id: 'id-123',
        nome: 'João Silva',
        email: 'joao@email.com',
        perfil: 'Paciente',
        possuiDiabetes: false,
        possuiCardiopatia: true,
        codigoVinculo: '12345',
        limiteLiquidoMl: 1500,
        metas: const MetasPersonalizadas(
          imc: 24.7,
          classificacaoImc: ClassificacaoImc.adequado,
          hidratacaoMl: 1500,
          sonoMinHoras: 7,
          sonoMaxHoras: 8,
          passos: 6000,
          exercicioMinutosSemana: 150,
          calorias: 1800,
          carboidratosG: 225,
          proteinasG: 90,
          gordurasG: 60,
          fibrasG: 25,
          gorduraSaturadaMaxG: 14,
          acucarLivreMaxG: 45,
          sodioMaxMg: 2000,
        ),
      );

      final lido = Paciente.fromJson(paciente.toJson(), 'id-123');

      expect(lido.limiteLiquidoMl, 1500);
      expect(lido.metas, isNotNull);
      expect(lido.metas!.hidratacaoMl, 1500);
      expect(lido.metas!.calorias, 1800);
      expect(lido.metas!.gorduraSaturadaMaxG, 14);
    });

    test('Deve ler como sem metas um paciente antigo, sem esses campos', () {
      final paciente = Paciente.fromJson({
        'nome': 'João Silva',
        'perfil': 'Paciente',
        'codigoVinculo': '12345',
      }, 'id-123');

      expect(paciente.metas, isNull);
      expect(paciente.limiteLiquidoMl, isNull);
    });

    test('copyWith deve trocar peso, atividade e metas e manter o resto', () {
      final paciente = Paciente(
        id: 'id-123',
        nome: 'João Silva',
        email: 'joao@email.com',
        perfil: 'Paciente',
        possuiDiabetes: true,
        possuiCardiopatia: false,
        codigoVinculo: '12345',
        acompanhantesVinculadosIds: const ['acomp-1'],
        triagemConcluida: true,
        sexoBiologico: 'Masculino',
        alturaCm: 175,
        pesoKg: 80,
        nivelAtividadeFisica: 'Leve',
        limiteLiquidoMl: 1500,
      );

      final novo = paciente.copyWith(pesoKg: 75, nivelAtividadeFisica: 'Intenso');
      final igual = paciente.copyWith();

      expect(novo.pesoKg, 75);
      expect(novo.nivelAtividadeFisica, 'Intenso');
      expect(novo.id, 'id-123');
      expect(novo.possuiDiabetes, true);
      expect(novo.acompanhantesVinculadosIds, ['acomp-1']);
      expect(novo.alturaCm, 175);
      expect(novo.limiteLiquidoMl, 1500);
      expect(igual.pesoKg, 80);
      expect(igual.nivelAtividadeFisica, 'Leve');
    });
  });
}
