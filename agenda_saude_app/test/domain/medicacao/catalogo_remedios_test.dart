import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/alergias/alergias.dart';
import 'package:agenda_saude_app/domain/medicacao/catalogo_remedios.dart';
import 'package:agenda_saude_app/domain/medicacao/remedio.dart';

import '../../helpers/catalogo_de_teste.dart';

void main() {
  group('Remedio Testes', () {
    test('Deve ler o remédio do JSON do catálogo', () {
      final remedio = Remedio.fromJson({
        'nome': 'Dorflex',
        'substancias': ['Cafeína', 'Dipirona', 'Orfenadrina'],
      });

      expect(remedio.nome, 'Dorflex');
      expect(remedio.substancias, ['Cafeína', 'Dipirona', 'Orfenadrina']);
      expect(remedio.descricaoSubstancias, 'Cafeína, dipirona, orfenadrina');
      expect(Remedio.fromJson({}).nome, '');
      expect(const Remedio(nome: 'X').descricaoSubstancias, '');
    });
  });

  group('CatalogoRemedios Testes', () {
    late CatalogoRemedios catalogo;

    setUpAll(() async {
      catalogo = await remediosRepositoryDeTeste().carregar();
    });

    test('Deve ter os remédios da Anvisa, cada nome uma vez só', () {
      final nomes = catalogo.remedios.map((remedio) => remedio.nome).toList();

      expect(nomes.length, 6663);
      expect(nomes.toSet().length, nomes.length);
    });

    test(
      'Deve achar pelo nome da caixa, sem acento, com o princípio ativo sem o sal',
      () {
        final achados = catalogo.buscar('losartana potassica');

        expect(achados.first.nome, 'Losartana potássica');
        expect(achados.first.substancias, ['Losartana']);
        expect(catalogo.buscar('novalgina').first.substancias, ['Dipirona']);
        expect(catalogo.buscar('glifage').first.substancias, ['Metformina']);
      },
    );

    test(
      'Deve achar também pelo princípio ativo, depois dos que têm no nome',
      () {
        final nomes = catalogo
            .buscar('metformina', limite: 200)
            .map((remedio) => remedio.nome)
            .toList();

        expect(nomes.first, 'Cloridrato de metformina');
        expect(nomes, contains('Glifage'));
        expect(
          nomes.indexOf('Glifage'),
          greaterThan(nomes.indexOf('Cloridrato de metformina')),
        );
      },
    );

    test('Deve respeitar o limite e devolver vazio para busca vazia', () {
      expect(catalogo.buscar('a', limite: 5), hasLength(5));
      expect(catalogo.buscar('   '), isEmpty);
      expect(catalogo.buscar('xyzxyz'), isEmpty);
    });

    test(
      'Na alergia, deve achar o princípio ativo pelo nome dele ou pela marca',
      () {
        final pelaSubstancia = catalogo.buscarSubstancias('dipiro');
        expect(pelaSubstancia.first.nome, 'Dipirona');
        expect(pelaSubstancia.first.remedio, isNull);

        final pelaMarca = catalogo.buscarSubstancias('novalgina');
        expect(pelaMarca.first.nome, 'Dipirona');
        expect(pelaMarca.first.remedio, 'Novalgina');
      },
    );

    test('A alergia a dipirona deve pegar os remédios que têm dipirona', () {
      String? alergiaDe(String nome) {
        final remedio = catalogo.buscar(nome).first;
        return alergiaNoRemedio(
          nome: remedio.nome,
          substancias: remedio.substancias,
          alergias: const ['Dipirona'],
        );
      }

      expect(alergiaDe('novalgina'), 'Dipirona');
      expect(alergiaDe('dorflex'), 'Dipirona');
      expect(alergiaDe('anador'), 'Dipirona');
      expect(alergiaDe('tylenol'), isNull);
    });
  });

  group('CatalogoRemedios pequeno Testes', () {
    test('Na alergia, não deve repetir o princípio ativo de várias marcas', () {
      final achados = catalogoDeRemediosPequeno().buscarSubstancias('d');

      expect(
        achados.where((achado) => achado.nome == 'Dipirona'),
        hasLength(1),
      );
    });
  });
}
