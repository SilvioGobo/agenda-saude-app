import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/medicacao/horario_medicacao.dart';

void main() {
  group('normalizarHorario Testes', () {
    test('Deve aceitar o horário só com números, com ou sem o zero da frente', () {
      expect(normalizarHorario('0800'), '08:00');
      expect(normalizarHorario('800'), '08:00');
      expect(normalizarHorario('1230'), '12:30');
      expect(normalizarHorario('2005'), '20:05');
      expect(normalizarHorario('0000'), '00:00');
    });

    test('Deve aceitar o horário com dois-pontos, "h" ou ponto', () {
      expect(normalizarHorario('08:00'), '08:00');
      expect(normalizarHorario('8:00'), '08:00');
      expect(normalizarHorario('8h30'), '08:30');
      expect(normalizarHorario('8H30'), '08:30');
      expect(normalizarHorario('20.15'), '20:15');
    });

    test('Deve aceitar só a hora, como hora cheia', () {
      expect(normalizarHorario('8'), '08:00');
      expect(normalizarHorario('20'), '20:00');
      expect(normalizarHorario('0'), '00:00');
    });

    test('Deve ignorar os espaços das pontas', () {
      expect(normalizarHorario('  0800 '), '08:00');
    });

    test('Deve recusar hora ou minuto que não existe', () {
      expect(normalizarHorario('2400'), isNull);
      expect(normalizarHorario('24'), isNull);
      expect(normalizarHorario('0860'), isNull);
      expect(normalizarHorario('8:75'), isNull);
      expect(normalizarHorario('99'), isNull);
    });

    test('Deve recusar o que não é um horário', () {
      expect(normalizarHorario(''), isNull);
      expect(normalizarHorario('   '), isNull);
      expect(normalizarHorario('manhã'), isNull);
      expect(normalizarHorario('08:0'), isNull);
      expect(normalizarHorario('12345'), isNull);
      expect(normalizarHorario('-8'), isNull);
    });
  });

  group('formatarHorario Testes', () {
    test('Deve escrever hora e minuto com dois dígitos cada', () {
      expect(formatarHorario(8, 5), '08:05');
      expect(formatarHorario(0, 0), '00:00');
      expect(formatarHorario(20, 30), '20:30');
      expect(formatarHorario(23, 59), '23:59');
    });
  });
}
