import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/alergias/alergias.dart';
import 'package:agenda_saude_app/domain/busca/palavras.dart';

void main() {
  group('Palavras da busca Testes', () {
    test('Deve separar sem acento, sem maiúsculas e sem pontuação', () {
      expect(separarPalavras('Pé-de-moleque, AMENDOIM'), [
        'pe',
        'de',
        'moleque',
        'amendoim',
      ]);
      expect(separarPalavras('  '), isEmpty);
    });

    test('Deve achar um trecho só em sequência', () {
      final palavras = separarPalavras('Leite, de vaca, integral');

      expect(contemSequencia(palavras, ['leite', 'de', 'vaca']), isTrue);
      expect(contemSequencia(palavras, ['vaca', 'integral']), isTrue);
      expect(contemSequencia(palavras, ['leite', 'vaca']), isFalse);
      expect(contemSequencia(palavras, []), isFalse);
    });
  });

  group('nomeDaAlergiaAlimentar Testes', () {
    test('Deve tirar o preparo e ficar com o alimento', () {
      expect(
        nomeDaAlergiaAlimentar('Camarão, Rio Grande, grande, cozido'),
        'Camarão',
      );
      expect(nomeDaAlergiaAlimentar('Amendoim, torrado, salgado'), 'Amendoim');
      expect(nomeDaAlergiaAlimentar('Paçoca, amendoim'), 'Paçoca');
    });

    test('Deve manter o "de que é" quando a segunda parte diz', () {
      expect(
        nomeDaAlergiaAlimentar('Leite, de vaca, integral'),
        'Leite de vaca',
      );
      expect(nomeDaAlergiaAlimentar('Farinha, de trigo'), 'Farinha de trigo');
      expect(
        nomeDaAlergiaAlimentar('Ovo, de galinha, inteiro, cozido/10minutos'),
        'Ovo de galinha',
      );
    });
  });

  group('alergiaNoAlimento Testes', () {
    test('Deve avisar em todo preparo e onde o alimento aparece no nome', () {
      const alergias = ['Amendoim'];

      expect(alergiaNoAlimento('Amendoim, grão, cru', alergias), 'Amendoim');
      expect(alergiaNoAlimento('Paçoca, amendoim', alergias), 'Amendoim');
      expect(
        alergiaNoAlimento('Pé-de-moleque, amendoim', alergias),
        'Amendoim',
      );
      expect(alergiaNoAlimento('Castanha-de-caju, torrada', alergias), isNull);
    });

    test('Deve comparar o nome inteiro da alergia, sem acento', () {
      const alergias = ['Leite de vaca', 'Camarão'];

      expect(
        alergiaNoAlimento('Leite, de vaca, desnatado, UHT', alergias),
        'Leite de vaca',
      );
      expect(alergiaNoAlimento('Leite, de coco', alergias), isNull);
      expect(alergiaNoAlimento('CAMARAO, frito', alergias), 'Camarão');
      expect(alergiaNoAlimento('Arroz, tipo 1, cozido', alergias), isNull);
      expect(alergiaNoAlimento('Arroz, tipo 1, cozido', const []), isNull);
    });
  });

  group('alergiaNoRemedio Testes', () {
    test('Deve comparar com os princípios ativos do remédio', () {
      expect(
        alergiaNoRemedio(
          nome: 'Dorflex',
          substancias: const ['Cafeína', 'Dipirona', 'Orfenadrina'],
          alergias: const ['Amoxicilina', 'Dipirona'],
        ),
        'Dipirona',
      );
      expect(
        alergiaNoRemedio(
          nome: 'Losartana potássica',
          substancias: const ['Losartana'],
          alergias: const ['Dipirona'],
        ),
        isNull,
      );
    });

    test('Sem princípio ativo, deve comparar com o nome digitado', () {
      expect(
        alergiaNoRemedio(nome: 'dipirona 1 g', alergias: const ['Dipirona']),
        'Dipirona',
      );
      expect(
        alergiaNoRemedio(nome: 'Novalgina', alergias: const ['Dipirona']),
        isNull,
      );
    });
  });

  group('comAlergia Testes', () {
    test('Deve juntar sem repetir, ignorando acento e maiúsculas', () {
      var lista = comAlergia(const [], ' Camarão ');
      lista = comAlergia(lista, 'camarao');
      lista = comAlergia(lista, 'Amendoim');
      lista = comAlergia(lista, '   ');

      expect(lista, ['Camarão', 'Amendoim']);
    });
  });
}
