import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/models/limites_alerta.dart';

void main() {
  group('LimitesAlerta Testes', () {
    test('Deve aceitar os valores dentro das faixas e longe o bastante um do outro', () {
      expect(LimitesAlerta.saoValidos(60, 100), isTrue);
      expect(LimitesAlerta.saoValidos(40, 150), isTrue);
      expect(LimitesAlerta.saoValidos(90, 110), isTrue);
      expect(LimitesAlerta.saoValidos(60, 80), isTrue);
    });

    test('Deve recusar valores fora das faixas ou perto demais um do outro', () {
      expect(LimitesAlerta.saoValidos(35, 100), isFalse);
      expect(LimitesAlerta.saoValidos(95, 130), isFalse);
      expect(LimitesAlerta.saoValidos(50, 75), isFalse);
      expect(LimitesAlerta.saoValidos(60, 155), isFalse);
      expect(LimitesAlerta.saoValidos(70, 85), isFalse);
    });

    test('Deve converter para JSON e de volta, com o Timestamp do Firestore', () {
      final quando = DateTime(2026, 11, 8, 14, 30);
      const sem = LimitesAlerta(bpmMinimo: 50, bpmMaximo: 110);
      final limites = LimitesAlerta(
        bpmMinimo: 50,
        bpmMaximo: 110,
        atualizadoPor: 'cuidador_01',
        atualizadoEm: quando,
      );

      expect(limites.toJson(), {
        'bpmMinimo': 50,
        'bpmMaximo': 110,
        'atualizadoPor': 'cuidador_01',
        'atualizadoEm': quando,
      });
      expect(sem.toJson().containsKey('atualizadoEm'), isFalse);

      final lido = LimitesAlerta.fromJson({
        'bpmMinimo': 50,
        'bpmMaximo': 110.0,
        'atualizadoPor': 'cuidador_01',
        'atualizadoEm': Timestamp.fromDate(quando),
      });
      expect(lido, limites);
    });

    test('Deve ler como sem limites o campo ausente, incompleto ou fora das faixas', () {
      expect(LimitesAlerta.fromJson(null), isNull);
      expect(LimitesAlerta.fromJson('60-100'), isNull);
      expect(LimitesAlerta.fromJson({'bpmMinimo': 50}), isNull);
      expect(LimitesAlerta.fromJson({'bpmMinimo': '50', 'bpmMaximo': 110}), isNull);
      expect(LimitesAlerta.fromJson({'bpmMinimo': 20, 'bpmMaximo': 110}), isNull);
      expect(
        LimitesAlerta.fromJson({'bpmMinimo': 50, 'bpmMaximo': 110}),
        const LimitesAlerta(bpmMinimo: 50, bpmMaximo: 110),
      );
    });
  });
}
