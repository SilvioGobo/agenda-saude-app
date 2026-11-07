import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/services/notification_service.dart';

void main() {
  group('idDaNotificacaoDoAlerta Testes', () {
    test('Deve dar sempre o mesmo id para o mesmo alerta', () {
      // Valor fixo: a escuta do app e o push (outro isolate) precisam chegar
      // ao mesmo numero. "abc" da 96354, como o hashCode de texto do Java.
      expect(idDaNotificacaoDoAlerta('abc'), 96354);
      expect(
        idDaNotificacaoDoAlerta('Kq3vX9pLmZ2aB7cD1eFg'),
        idDaNotificacaoDoAlerta('Kq3vX9pLmZ2aB7cD1eFg'),
      );
    });

    test('Deve dar ids diferentes para alertas diferentes', () {
      expect(
        idDaNotificacaoDoAlerta('Kq3vX9pLmZ2aB7cD1eFg'),
        isNot(idDaNotificacaoDoAlerta('Kq3vX9pLmZ2aB7cD1eFh')),
      );
    });

    test('Deve dar um id positivo de 31 bits, como o Android aceita', () {
      for (final alertaId in ['', 'a', 'Kq3vX9pLmZ2aB7cD1eFg', 'z' * 200]) {
        final id = idDaNotificacaoDoAlerta(alertaId);
        expect(id, greaterThanOrEqualTo(0));
        expect(id, lessThanOrEqualTo(0x7fffffff));
      }
    });
  });
}
