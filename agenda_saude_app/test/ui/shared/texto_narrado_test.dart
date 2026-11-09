import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/ui/shared/texto_narrado.dart';

void main() {
  group('texto_narrado Testes', () {
    group('montarTextoNarrado', () {
      test('Deve juntar as frases separadas por espaço, cada uma com ponto', () {
        expect(
          montarTextoNarrado(['Sua rotina de hoje', 'Falta registrar o sono']),
          'Sua rotina de hoje. Falta registrar o sono.',
        );
      });

      test('Não deve repetir a pontuação que a frase já tem', () {
        expect(
          montarTextoNarrado(['Atenção!', 'Tudo certo?', 'Ok.']),
          'Atenção! Tudo certo? Ok.',
        );
      });

      test('Deve ignorar frases vazias, só com espaços ou nulas', () {
        expect(
          montarTextoNarrado(['Olá', null, '', '   ', 'Tudo bem']),
          'Olá. Tudo bem.',
        );
      });

      test('Deve devolver texto vazio quando não há frases', () {
        expect(montarTextoNarrado([]), '');
        expect(montarTextoNarrado([null, '  ']), '');
      });

      test('Deve tirar os espaços das pontas de cada frase', () {
        expect(montarTextoNarrado(['  Olá  ', ' mundo ']), 'Olá. mundo.');
      });
    });

    group('contar', () {
      test('Deve usar o singular só para um', () {
        expect(contar(1, 'copo', 'copos'), '1 copo');
      });

      test('Deve usar o plural para zero e para vários', () {
        expect(contar(0, 'copo', 'copos'), '0 copos');
        expect(contar(3, 'copo', 'copos'), '3 copos');
      });
    });

    group('falarDose', () {
      test('Deve trocar a abreviatura colada ao número pela unidade por extenso', () {
        expect(falarDose('Losartana 50mg'), 'Losartana 50 miligramas');
        expect(falarDose('Losartana 50 mg'), 'Losartana 50 miligramas');
      });

      test('Deve usar o singular para um', () {
        expect(falarDose('Vitamina 1 mg'), 'Vitamina 1 miligrama');
        expect(falarDose('Xarope 1ml'), 'Xarope 1 mililitro');
      });

      test('Deve entender microgramas, mililitros e gramas', () {
        expect(falarDose('Levotiroxina 75 mcg'), 'Levotiroxina 75 microgramas');
        expect(falarDose('Xarope 5 ml'), 'Xarope 5 mililitros');
        expect(falarDose('Sachê 2 g'), 'Sachê 2 gramas');
      });

      test('Deve aceitar número com vírgula', () {
        expect(falarDose('Remédio 0,5 mg'), 'Remédio 0,5 miligramas');
      });

      test('Não deve mexer em palavras que só começam com a sigla', () {
        expect(falarDose('10 gotas'), '10 gotas');
        expect(falarDose('1 comprimido'), '1 comprimido');
        expect(falarDose('Magnésio'), 'Magnésio');
      });

      test('Deve deixar sem mudança o que não tem unidade', () {
        expect(falarDose('Losartana'), 'Losartana');
        expect(falarDose(''), '');
      });
    });

    group('falarHoraDe', () {
      test('Deve falar a hora cheia sem os minutos', () {
        expect(falarHoraDe(DateTime(2026, 11, 7, 14, 0)), '14 horas');
      });

      test('Deve falar horas e minutos por extenso', () {
        expect(
          falarHoraDe(DateTime(2026, 11, 7, 14, 5)),
          '14 horas e 5 minutos',
        );
      });

      test('Deve falar "1 hora" no singular', () {
        expect(falarHoraDe(DateTime(2026, 11, 7, 1, 30)), '1 hora e 30 minutos');
      });
    });

    group('falarQuando', () {
      final agora = DateTime(2026, 11, 7, 15, 0);

      test('Deve dizer "agora mesmo" para menos de um minuto', () {
        expect(
          falarQuando(DateTime(2026, 11, 7, 14, 59, 30), agora),
          'agora mesmo',
        );
      });

      test('Deve dizer "agora mesmo" se o relógio do aparelho estiver adiantado', () {
        expect(falarQuando(DateTime(2026, 11, 7, 15, 3), agora), 'agora mesmo');
      });

      test('Deve falar os minutos, no singular e no plural', () {
        expect(falarQuando(DateTime(2026, 11, 7, 14, 59), agora), 'há 1 minuto');
        expect(falarQuando(DateTime(2026, 11, 7, 14, 55), agora), 'há 5 minutos');
      });

      test('Deve falar "hoje" com a hora por extenso', () {
        expect(
          falarQuando(DateTime(2026, 11, 7, 9, 10), agora),
          'hoje, às 9 horas e 10 minutos',
        );
      });

      test('Deve falar "ontem" com a hora por extenso', () {
        expect(
          falarQuando(DateTime(2026, 11, 6, 21, 0), agora),
          'ontem, às 21 horas',
        );
      });

      test('Deve falar o dia e o mês quando faz mais de um dia', () {
        expect(
          falarQuando(DateTime(2026, 9, 18, 21, 5), agora),
          'em 18 de setembro, às 21 horas e 5 minutos',
        );
      });

      test('Deve chamar de "ontem" o que passou da meia-noite, mesmo com menos de 24 horas', () {
        expect(
          falarQuando(DateTime(2026, 11, 6, 23, 30), DateTime(2026, 11, 7, 1, 0)),
          'ontem, às 23 horas e 30 minutos',
        );
      });
    });
  });
}
