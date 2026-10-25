import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/models/localizacao.dart';

void main() {
  group('Localizacao Testes', () {
    test('Deve converter para JSON com coordenadas, precisão e horário', () {
      final dataHora = DateTime(2026, 10, 25, 14, 0);
      final localizacao = Localizacao(
        pacienteId: 'paciente_01',
        ativo: true,
        latitude: -22.2210,
        longitude: -54.8056,
        precisaoMetros: 12.5,
        dataHora: dataHora,
      );

      final json = localizacao.toJson();

      expect(json['pacienteId'], 'paciente_01');
      expect(json['ativo'], true);
      expect(json['latitude'], -22.2210);
      expect(json['longitude'], -54.8056);
      expect(json['precisaoMetros'], 12.5);
      expect(json['dataHora'], dataHora);
      expect(localizacao.temPosicao, true);
    });

    test('Deve ler do Firestore uma localização com posição', () {
      final localizacao = Localizacao.fromJson({
        'pacienteId': 'paciente_01',
        'ativo': true,
        'latitude': -22.2210,
        'longitude': -54.8056,
        // o Firestore devolve inteiro quando o numero nao tem casas decimais
        'precisaoMetros': 15,
        'dataHora': Timestamp.fromDate(DateTime(2026, 10, 25, 14, 0)),
      }, 'paciente_01');

      expect(localizacao.pacienteId, 'paciente_01');
      expect(localizacao.ativo, true);
      expect(localizacao.latitude, -22.2210);
      expect(localizacao.precisaoMetros, 15.0);
      expect(localizacao.dataHora, DateTime(2026, 10, 25, 14, 0));
      expect(localizacao.temPosicao, true);
    });

    test('Deve ler compartilhamento desligado sem posição', () {
      final localizacao = Localizacao.fromJson({
        'pacienteId': 'paciente_01',
        'ativo': false,
      }, 'paciente_01');

      expect(localizacao.ativo, false);
      expect(localizacao.latitude, isNull);
      expect(localizacao.dataHora, isNull);
      expect(localizacao.temPosicao, false);
    });

    test('Deve usar o id do documento e valores padrão quando faltam campos', () {
      final localizacao = Localizacao.fromJson({}, 'paciente_02');

      expect(localizacao.pacienteId, 'paciente_02');
      expect(localizacao.ativo, false);
      expect(localizacao.temPosicao, false);
    });
  });
}
