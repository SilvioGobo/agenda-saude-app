import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/alimentos_repository.dart';

import '../../helpers/catalogo_de_teste.dart';

void main() {
  group('AlimentosRepository Testes', () {
    test('Deve carregar o catálogo do arquivo do app', () async {
      final catalogo = await alimentosRepositoryDeTeste().carregar();

      expect(catalogo.alimentos.length, 593);
      expect(catalogo.porId(idArrozCozido)!.nome, 'Arroz, tipo 1, cozido');
    });

    test('Deve ler o arquivo uma vez só e reaproveitar o catálogo', () async {
      var leituras = 0;
      final repositorio = AlimentosRepository(
        lerTexto: () async {
          leituras++;
          return '[{"id":1,"nome":"Teste","kcal":10}]';
        },
      );

      final primeiro = await repositorio.carregar();
      final segundo = await repositorio.carregar();

      expect(leituras, 1);
      expect(identical(primeiro, segundo), isTrue);
      expect(primeiro.alimentos.single.nome, 'Teste');
    });

    test('Deve tentar de novo depois de uma falha na leitura', () async {
      var tentativas = 0;
      final repositorio = AlimentosRepository(
        lerTexto: () async {
          tentativas++;
          if (tentativas == 1) throw Exception('arquivo indisponivel');
          return '[{"id":1,"nome":"Teste","kcal":10}]';
        },
      );

      await expectLater(repositorio.carregar(), throwsException);
      final catalogo = await repositorio.carregar();

      expect(tentativas, 2);
      expect(catalogo.alimentos.length, 1);
    });

    test('Deve falhar quando o arquivo não é um catálogo válido', () async {
      final repositorio = AlimentosRepository(
        lerTexto: () async => 'nao e json',
      );

      await expectLater(
        repositorio.carregar(),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
