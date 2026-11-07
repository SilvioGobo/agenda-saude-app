import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/ui/lembretes/formato_lembretes.dart';

void main() {
  group('falarHorario Testes', () {
    test('Deve falar só as horas quando os minutos são zero', () {
      expect(falarHorario('08:00'), '8 horas');
      expect(falarHorario('22:00'), '22 horas');
    });

    test('Deve falar a hora no singular', () {
      expect(falarHorario('01:00'), '1 hora');
    });

    test('Deve falar as horas e os minutos', () {
      expect(falarHorario('08:30'), '8 horas e 30 minutos');
      expect(falarHorario('11:01'), '11 horas e 1 minuto');
    });
  });
}
