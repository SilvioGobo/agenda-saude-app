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

  });
}