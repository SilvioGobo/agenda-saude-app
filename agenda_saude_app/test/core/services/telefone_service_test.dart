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
}
