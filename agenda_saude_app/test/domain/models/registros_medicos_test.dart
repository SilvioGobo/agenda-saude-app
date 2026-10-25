import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agenda_saude_app/domain/models/registro_agua.dart';
import 'package:agenda_saude_app/domain/models/registro_diabete.dart';

void main() {
  group('Testes dos Modelos de Registos Médicos', () {

    test('Deve converter RegistroAgua a partir de um JSON do Firebase', () {
      final agora = DateTime.now();
      final json = {
        'tipo': 'agua',
        'pacienteId': 'paciente_123',
        'dataHora': Timestamp.fromDate(agora), // O Firebase devolve Timestamp
        'quantidadeML': 500,
      };

      final registro = RegistroAgua.fromJson(json, 'doc_001');

      expect(registro.id, 'doc_001');
      expect(registro.pacienteId, 'paciente_123');
      expect(registro.quantidadeML, 500);
      expect(registro.dataHora.year, agora.year);
    });

    test('Deve converter RegistroDiabete para JSON corretamente', () {
      final registro = RegistroDiabete(
        id: 'doc_002',
        pacienteId: 'paciente_123',
        dataHora: DateTime(2026, 5, 28, 8, 0),
        nivelGlicose: 110.5,
        momento: 'Jejum',
        doseInsulina: 10.0,
        tipoInsulina: 'Rápida',
      );

      final json = registro.toJson();

      expect(json['tipo'], 'diabete');
      expect(json['nivelGlicose'], 110.5);
      expect(json['momento'], 'Jejum');
      // O ID não deve ir no corpo do JSON
      expect(json.containsKey('id'), false);
    });

    test('Deve converter RegistroDiabete só de glicemia, sem insulina', () {
      final json = {
        'tipo': 'diabete',
        'pacienteId': 'paciente_123',
        'dataHora': Timestamp.fromDate(DateTime(2026, 10, 25, 7, 0)),
        'nivelGlicose': 98,
        'momento': 'Ao acordar',
        'doseInsulina': null,
        'tipoInsulina': null,
      };

      final registro = RegistroDiabete.fromJson(json, 'doc_003');

      expect(registro.nivelGlicose, 98.0);
      expect(registro.temGlicemia, isTrue);
      expect(registro.doseInsulina, isNull);
      expect(registro.temInsulina, isFalse);
      expect(registro.tipoInsulina, isNull);
    });

    test('Deve converter RegistroDiabete só de insulina, sem glicemia', () {
      final registro = RegistroDiabete(
        id: '',
        pacienteId: 'paciente_123',
        dataHora: DateTime(2026, 10, 25, 22, 0),
        momento: 'Insulina lenta (22h)',
        doseInsulina: 14,
        tipoInsulina: 'Lenta',
      );

      final json = registro.toJson();
      final convertido = RegistroDiabete.fromJson({
        ...json,
        'dataHora': Timestamp.fromDate(registro.dataHora),
      }, 'doc_004');

      expect(json['nivelGlicose'], isNull);
      expect(convertido.temGlicemia, isFalse);
      expect(convertido.doseInsulina, 14.0);
      expect(convertido.tipoInsulina, 'Lenta');
    });

  });
}