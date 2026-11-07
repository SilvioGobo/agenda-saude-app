import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/ui/rotina/formato_exercicio.dart';

void main() {
  group('formato_exercicio Testes', () {
    test('Deve escrever a duração em horas e minutos', () {
      expect(formatarMinutos(30), '30 min');
      expect(formatarMinutos(60), '1 h');
      expect(formatarMinutos(90), '1 h 30 min');
      expect(formatarMinutos(135), '2 h 15 min');
      expect(formatarMinutos(5), '5 min');
    });

    test('Deve falar a duração por extenso para o leitor de tela', () {
      expect(falarMinutos(30), '30 minutos');
      expect(falarMinutos(60), '1 hora');
      expect(falarMinutos(90), '1 hora e 30 minutos');
      expect(falarMinutos(121), '2 horas e 1 minuto');
    });

    test('Deve explicar cada intensidade pelo teste da conversa', () {
      expect(descricaoDaIntensidade('Leve'), 'Dá para conversar e até cantar.');
      expect(descricaoDaIntensidade('Moderada'),
          'Dá para conversar, mas não para cantar.');
      expect(descricaoDaIntensidade('Intensa'), 'Só dá para falar frases curtas.');
    });

    test('Deve devolver vazio para uma intensidade que não é das três', () {
      expect(descricaoDaIntensidade('Qualquer'), '');
      expect(descricaoDaIntensidade(''), '');
    });
  });
}
