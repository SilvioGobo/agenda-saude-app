import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/services/telefone_service.dart';

void main() {
  group('TelefoneService Testes', () {
    test('Deve deixar só os dígitos do número para o discador', () {
      expect(numeroParaDiscar('(67) 99999-0000'), '67999990000');
      expect(numeroParaDiscar(' 192 '), '192');
      expect(numeroParaDiscar('67 3411.2233'), '6734112233');
    });

    test('Deve manter o "+" do código do país', () {
      expect(numeroParaDiscar('+55 (67) 99999-0000'), '+5567999990000');
    });

    test('Deve devolver vazio quando não há dígitos', () {
      expect(numeroParaDiscar(''), '');
      expect(numeroParaDiscar('sem telefone'), '');
    });

    test('Deve formatar celular e fixo com DDD para mostrar na tela', () {
      expect(formatarTelefone('67999990000'), '(67) 99999-0000');
      expect(formatarTelefone('6734112233'), '(67) 3411-2233');
      expect(formatarTelefone('(67) 99999-0000'), '(67) 99999-0000');
      // Formato desconhecido fica como veio.
      expect(formatarTelefone(' 192 '), '192');
    });

    test('Não deve tentar discar um número vazio', () async {
      expect(await TelefoneServiceImpl().ligar('  '), isFalse);
    });
  });

  group('normalizarTelefone Testes', () {
    test('Deve guardar só os dígitos de celular e fixo com DDD', () {
      expect(normalizarTelefone('(67) 99999-0000'), '67999990000');
      expect(normalizarTelefone('67 3411-2233'), '6734112233');
      expect(normalizarTelefone('67999990000'), '67999990000');
      expect(normalizarTelefone('  (67) 99999-0000  '), '67999990000');
    });

    test('Deve tirar o código do país quando sobra um número completo', () {
      expect(normalizarTelefone('+55 (67) 99999-0000'), '67999990000');
      expect(normalizarTelefone('5567999990000'), '67999990000');
      expect(normalizarTelefone('+55 67 3411-2233'), '6734112233');
    });

    test('Deve manter o DDD 55 quando o código do país não foi digitado', () {
      expect(normalizarTelefone('55999990000'), '55999990000');
      expect(normalizarTelefone('5534112233'), '5534112233');
    });

    test('Deve rejeitar número sem DDD', () {
      expect(normalizarTelefone('99999-0000'), isNull);
      expect(normalizarTelefone('3411-2233'), isNull);
    });

    test('Deve rejeitar celular que não começa com 9 e fixo fora de 2 a 5', () {
      expect(normalizarTelefone('67899990000'), isNull);
      expect(normalizarTelefone('6761112233'), isNull);
    });

    test('Deve rejeitar DDD que não existe', () {
      expect(normalizarTelefone('00999990000'), isNull);
      expect(normalizarTelefone('10999990000'), isNull);
      expect(normalizarTelefone('20999990000'), isNull);
    });

    test('Deve rejeitar o que não é telefone', () {
      expect(normalizarTelefone(''), isNull);
      expect(normalizarTelefone('   '), isNull);
      expect(normalizarTelefone('sem telefone'), isNull);
      expect(normalizarTelefone('192'), isNull);
    });

    test('Deve rejeitar número com dígitos sobrando', () {
      expect(normalizarTelefone('679999900001'), isNull);
      expect(normalizarTelefone('55679999900001'), isNull);
    });
  });
}
