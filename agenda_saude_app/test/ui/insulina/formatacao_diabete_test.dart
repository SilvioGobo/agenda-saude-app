import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/constants/faixas_glicemia.dart';
import 'package:agenda_saude_app/ui/insulina/formatacao_diabete.dart';

void main() {
  group('Formatação de glicemia e insulina Testes', () {
    String visivel(String texto) => semMarcasDeQuebra(texto);

    test('Deve mostrar a glicemia inteira em mg/dL', () {
      expect(visivel(formatarGlicemia(112.4)), '112 mg/dL');
    });

    test('Deve manter número e unidade na mesma linha', () {
      // Sem espaco comum nem barra "solta" que deixem a linha quebrar no meio.
      expect(formatarGlicemia(60).contains(' '), isFalse);
      expect(formatarGlicemia(60).contains('/\u2060'), isTrue);
      expect(formatarDose(6).contains(' '), isFalse);
    });

    test('Deve mostrar a dose com vírgula e no singular quando for 1', () {
      expect(visivel(formatarDose(6)), '6 unidades');
      expect(visivel(formatarDose(6.5)), '6,5 unidades');
      expect(visivel(formatarDose(1)), '1 unidade');
    });

    test('Deve descrever a insulina com o tipo', () {
      expect(
        visivel(descreverInsulina('Rápida', 6)),
        'Insulina rápida: 6 unidades',
      );
      expect(visivel(descreverInsulina(null, 6)), 'Insulina: 6 unidades');
    });

    test('Deve descrever cada faixa da glicemia', () {
      expect(descreverClassificacao(ClassificacaoGlicemia.muitoBaixa), 'Muito baixa');
      expect(descreverClassificacao(ClassificacaoGlicemia.naFaixa), 'Na faixa');
      expect(descreverClassificacao(ClassificacaoGlicemia.muitoAlta), 'Muito alta');
    });
  });
}
