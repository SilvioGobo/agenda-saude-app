import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/remedios_repository.dart';

import '../../helpers/catalogo_de_teste.dart';

void main() {
  group('RemediosRepository Testes', () {
    test('Deve carregar o catálogo do arquivo do app', () async {
      final catalogo = await remediosRepositoryDeTeste().carregar();

      expect(catalogo.remedios.length, 6663);
      expect(catalogo.buscar('novalgina').first.nome, 'Novalgina');
    });

    test('Deve ler o arquivo uma vez só e reaproveitar o catálogo', () async {
      var leituras = 0;
      final repositorio = RemediosRepository(
        lerTexto: () async {
          leituras++;
          return '[{"nome":"Teste","substancias":["Testina"]}]';
        },
      );

      final primeiro = await repositorio.carregar();
      final segundo = await repositorio.carregar();

      expect(leituras, 1);
      expect(identical(primeiro, segundo), isTrue);
      expect(primeiro.remedios.single.substancias, ['Testina']);
    });

    test('Deve tentar de novo depois de uma falha na leitura', () async {
      var tentativas = 0;
      final repositorio = RemediosRepository(
        lerTexto: () async {
          tentativas++;
          if (tentativas == 1) throw Exception('arquivo indisponivel');
          return '[{"nome":"Teste"}]';
        },
      );

      await expectLater(repositorio.carregar(), throwsException);
      final catalogo = await repositorio.carregar();

      expect(tentativas, 2);
      expect(catalogo.remedios.single.substancias, isEmpty);
    });
  });
}
