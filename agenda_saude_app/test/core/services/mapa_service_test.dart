import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/services/mapa_service.dart';

void main() {
  group('montarEndereco Testes', () {
    test('Deve montar o endereço completo no formato brasileiro', () {
      expect(
        montarEndereco(
          rua: 'Rua das Flores',
          numero: '120',
          bairro: 'Centro',
          cidade: 'Dourados',
        ),
        'Rua das Flores, 120 - Centro, Dourados',
      );
    });

    test('Deve pular as partes que vierem vazias', () {
      expect(
        montarEndereco(rua: 'Rua das Flores', numero: ' ', cidade: 'Dourados'),
        'Rua das Flores - Dourados',
      );
      expect(
        montarEndereco(bairro: 'Centro', cidade: 'Dourados'),
        'Centro, Dourados',
      );
    });

    test('Deve retornar null quando não há nenhuma parte', () {
      expect(montarEndereco(), isNull);
      expect(montarEndereco(rua: '', bairro: '  '), isNull);
    });
  });
}
