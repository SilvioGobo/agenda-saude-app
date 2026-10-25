import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/alimentos/alimento.dart';
import 'package:agenda_saude_app/domain/alimentos/catalogo_alimentos.dart';
import 'package:agenda_saude_app/domain/alimentos/nutrientes.dart';

import '../../helpers/catalogo_de_teste.dart';

void main() {
  group('Nutrientes Testes', () {
    test('Deve somar todos os campos', () {
      const a = Nutrientes(
        kcal: 100,
        proteinaG: 10,
        gorduraG: 5,
        carboidratoG: 20,
        fibraG: 2,
        sodioMg: 300,
      );
      const b = Nutrientes(
        kcal: 50,
        proteinaG: 1,
        gorduraG: 1,
        carboidratoG: 8,
      );

      final soma = a + b;

      expect(soma.kcal, 150);
      expect(soma.proteinaG, 11);
      expect(soma.gorduraG, 6);
      expect(soma.carboidratoG, 28);
      expect(soma.fibraG, 2);
      expect(soma.sodioMg, 300);
    });

    test('Deve somar uma lista e dar zero quando ela está vazia', () {
      expect(Nutrientes.somar(const []).kcal, 0);
      expect(
        Nutrientes.somar(const [
          Nutrientes(kcal: 10),
          Nutrientes(kcal: 20),
          Nutrientes(kcal: 30),
        ]).kcal,
        60,
      );
    });
  });

  group('Alimento Testes', () {
    const arroz = Alimento(
      id: 3,
      nome: 'Arroz, tipo 1, cozido',
      grupo: 'Cereais e derivados',
      kcal: 128,
      proteinaG: 2.5,
      gorduraG: 0.2,
      carboidratoG: 28.1,
      fibraG: 1.6,
      sodioMg: 1,
    );

    test(
      'Deve calcular os nutrientes proporcionais à quantidade em gramas',
      () {
        final cento = arroz.paraGramas(100);
        final duzentos = arroz.paraGramas(200);
        final cinquenta = arroz.paraGramas(50);

        expect(cento.kcal, 128);
        expect(duzentos.kcal, 256);
        expect(duzentos.carboidratoG, closeTo(56.2, 0.001));
        expect(cinquenta.proteinaG, closeTo(1.25, 0.001));
        expect(cinquenta.sodioMg, closeTo(0.5, 0.001));
        expect(arroz.paraGramas(0).kcal, 0);
      },
    );

    test('Deve ler o alimento do JSON do catálogo', () {
      final alimento = Alimento.fromJson({
        'id': 3,
        'nome': 'Arroz, tipo 1, cozido',
        'grupo': 'Cereais e derivados',
        'kcal': 128,
        'proteinaG': 2.5,
        'gorduraG': 0.2,
        'carboidratoG': 28.1,
        'fibraG': 1.6,
        'sodioMg': 1,
      });

      expect(alimento.id, 3);
      expect(alimento.nome, 'Arroz, tipo 1, cozido');
      expect(alimento.grupo, 'Cereais e derivados');
      expect(alimento.kcal, 128);
      expect(alimento.carboidratoG, 28.1);
      expect(alimento.sodioMg, 1);
    });

    test(
      'Deve aceitar números inteiros onde o JSON traz decimais e campos faltando',
      () {
        final alimento = Alimento.fromJson({
          'id': 260,
          'nome': 'Azeite',
          'kcal': 884,
          'gorduraG': 100,
        });

        expect(alimento.gorduraG, 100.0);
        expect(alimento.proteinaG, 0);
        expect(alimento.fibraG, 0);
        expect(alimento.grupo, isNull);
      },
    );
  });

  group('CatalogoAlimentos Testes', () {
    late CatalogoAlimentos catalogo;

    setUpAll(() async {
      catalogo = await catalogoDeTeste();
    });

    List<String> nomes(String consulta, {int limite = 40}) =>
        catalogo.buscar(consulta, limite: limite).map((a) => a.nome).toList();

    test('Deve ter os 593 alimentos da TACO com ids únicos', () {
      expect(catalogo.alimentos.length, 593);
      expect(catalogo.alimentos.map((a) => a.id).toSet().length, 593);
    });

    test('Deve conter alimentos comuns com os valores da TACO', () {
      final arroz = catalogo.porId(idArrozCozido)!;
      expect(arroz.nome, 'Arroz, tipo 1, cozido');
      expect(arroz.kcal, 128);
      expect(arroz.proteinaG, 2.5);
      expect(arroz.gorduraG, 0.2);
      expect(arroz.carboidratoG, 28.1);

      final pao = catalogo.porId(idPaoFrances)!;
      expect(pao.nome, 'Pão, trigo, francês');
      expect(pao.sodioMg, 648);

      expect(catalogo.porId(idFeijaoCarioca)!.kcal, 76);
      expect(catalogo.porId(idBananaPrata)!.carboidratoG, 26.0);
      expect(catalogo.porId(idFrangoGrelhado)!.proteinaG, 32.0);
    });

    test('Deve devolver null para um id que não existe', () {
      expect(catalogo.porId(99999), isNull);
    });

    test(
      'Deve ficar sem os alimentos que a TACO marca como em reavaliação',
      () {
        expect(
          nomes('leite de vaca integral'),
          isNot(contains('Leite, de vaca, integral')),
        );
        expect(nomes('coco verde'), isNot(contains('Coco, verde, cru')));
      },
    );

    test('Deve achar o alimento ignorando maiúsculas, acentos e pontuação', () {
      expect(
        nomes('FEIJAO carioca cozido'),
        contains('Feijão, carioca, cozido'),
      );
      expect(nomes('pao frances'), contains('Pão, trigo, francês'));
      expect(nomes('maca'), contains('Maçã, Argentina, com casca, crua'));
    });

    test('Deve achar pelo começo das palavras, em qualquer ordem', () {
      expect(nomes('arr coz'), contains('Arroz, tipo 1, cozido'));
      expect(nomes('cozido arroz'), contains('Arroz, tipo 1, cozido'));
      expect(nomes('arr tipo 1'), contains('Arroz, tipo 1, cru'));
    });

    test(
      'Deve mostrar primeiro os alimentos que começam pela palavra digitada',
      () {
        final resultado = nomes('arroz', limite: 100);

        expect(resultado.first, startsWith('Arroz'));
        final primeiroQueNaoComeca = resultado.indexWhere(
          (nome) => !nome.toLowerCase().startsWith('arroz'),
        );
        final ultimoQueComeca = resultado.lastIndexWhere(
          (nome) => nome.toLowerCase().startsWith('arroz'),
        );
        if (primeiroQueNaoComeca >= 0) {
          expect(ultimoQueComeca, lessThan(primeiroQueNaoComeca));
        }
      },
    );

    test('Deve respeitar o limite de resultados', () {
      expect(catalogo.buscar('a', limite: 5).length, 5);
      expect(catalogo.buscar('a').length, 40);
    });

    test('Deve devolver lista vazia para busca vazia ou sem resultado', () {
      expect(catalogo.buscar(''), isEmpty);
      expect(catalogo.buscar('   '), isEmpty);
      expect(catalogo.buscar('...'), isEmpty);
      expect(catalogo.buscar('xyzxyz'), isEmpty);
    });

    test('Não deve achar quando uma das palavras não existe no nome', () {
      expect(nomes('arroz pizza'), isEmpty);
    });
  });
}
