import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/constants/zona_seguranca_cardiaca.dart';
import 'package:agenda_saude_app/domain/models/limites_alerta.dart';

void main() {
  group('ZonaSegurancaCardiaca Testes', () {
    const limites = LimitesAlerta(bpmMinimo: 50, bpmMaximo: 120);

    test('Deve usar 60 a 100 e, para o cardiopata, 60 a 90 sem limites do paciente', () {
      expect(ZonaSegurancaCardiaca.bpmMinimo(possuiCardiopatia: false), 60);
      expect(ZonaSegurancaCardiaca.bpmMaximo(possuiCardiopatia: false), 100);
      expect(ZonaSegurancaCardiaca.bpmMinimo(possuiCardiopatia: true), 60);
      expect(ZonaSegurancaCardiaca.bpmMaximo(possuiCardiopatia: true), 90);
    });

    test('Deve trocar a zona padrão pelos limites que o acompanhante definiu', () {
      for (final cardiopata in [false, true]) {
        expect(
          ZonaSegurancaCardiaca.bpmMinimo(
            possuiCardiopatia: cardiopata,
            limites: limites,
          ),
          50,
        );
        expect(
          ZonaSegurancaCardiaca.bpmMaximo(
            possuiCardiopatia: cardiopata,
            limites: limites,
          ),
          120,
        );
      }
    });

    test('Deve dizer se o BPM está dentro ou acima da zona do paciente', () {
      expect(
        ZonaSegurancaCardiaca.estaDentroDaZona(110, possuiCardiopatia: false),
        isFalse,
      );
      expect(
        ZonaSegurancaCardiaca.estaDentroDaZona(
          110,
          possuiCardiopatia: false,
          limites: limites,
        ),
        isTrue,
      );
      expect(
        ZonaSegurancaCardiaca.estaDentroDaZona(
          55,
          possuiCardiopatia: true,
          limites: limites,
        ),
        isTrue,
      );
      expect(
        ZonaSegurancaCardiaca.estaAcimaDaZona(
          110,
          possuiCardiopatia: false,
          limites: limites,
        ),
        isFalse,
      );
      expect(
        ZonaSegurancaCardiaca.estaAcimaDaZona(
          121,
          possuiCardiopatia: false,
          limites: limites,
        ),
        isTrue,
      );
    });
  });
}
