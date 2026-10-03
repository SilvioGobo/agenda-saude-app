import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/models/alerta.dart';

void main() {
  group('Alerta Testes', () {
    test('Deve converter para JSON com tipo e BPM da leitura', () {
      final dataHora = DateTime(2026, 9, 19, 14, 0);
      final alerta = Alerta(
        id: 'alerta_01',
        pacienteId: 'paciente_01',
        tipo: Alerta.tipoAtencao,
        mensagem: 'Batimentos acima da zona de segurança (118 BPM).',
        bpm: 118,
        dataHora: dataHora,
      );

      final json = alerta.toJson();

      expect(json['pacienteId'], 'paciente_01');
      expect(json['tipo'], 'atencao');
      expect(json['bpm'], 118);
      expect(json['dataHora'], dataHora);
      expect(json['lido'], false);
      expect(alerta.ehEmergencia, false);
    });

    test('Deve ler do Firestore um alerta de emergência', () {
      final alerta = Alerta.fromJson({
        'pacienteId': 'paciente_01',
        'tipo': 'emergencia',
        'mensagem': 'Batimentos fora da zona de segurança há 6 minutos.',
        'bpm': 125,
        'dataHora': Timestamp.fromDate(DateTime(2026, 9, 19, 14, 0)),
        'lido': true,
      }, 'alerta_02');

      expect(alerta.id, 'alerta_02');
      expect(alerta.ehEmergencia, true);
      expect(alerta.bpm, 125);
      expect(alerta.dataHora, DateTime(2026, 9, 19, 14, 0));
      expect(alerta.lido, true);
    });

    test('Deve tratar alerta antigo sem tipo como emergência', () {
      // Antes do aviso de "Atenção" so existiam alertas de BPM prolongado.
      final alerta = Alerta.fromJson({
        'pacienteId': 'paciente_01',
        'mensagem': 'Batimentos fora da zona de segurança há 5 minutos.',
        'dataHora': Timestamp.fromDate(DateTime(2026, 9, 19, 14, 0)),
      }, 'alerta_03');

      expect(alerta.tipo, Alerta.tipoEmergencia);
      expect(alerta.bpm, isNull);
      expect(alerta.lido, false);
    });
  });
}
