import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/metas/metas_personalizadas.dart';
import 'package:agenda_saude_app/ui/metas/formato_metas.dart';

void main() {
  group('Formato das metas Testes', () {
    test('Deve separar o milhar com ponto', () {
      expect(formatarMilhar(0), '0');
      expect(formatarMilhar(250), '250');
      expect(formatarMilhar(1000), '1.000');
      expect(formatarMilhar(2750), '2.750');
      expect(formatarMilhar(12500), '12.500');
      expect(formatarMilhar(1234567), '1.234.567');
      expect(formatarMilhar(-1500), '-1.500');
    });

    test('Deve usar vírgula como separador decimal', () {
      expect(formatarDecimal(24.7), '24,7');
      expect(formatarDecimal(1.5), '1,5');
      expect(formatarDecimal(30), '30,0');
    });

    test('Deve ter um rótulo em português para cada classificação de IMC', () {
      expect(
        rotuloClassificacaoImc(ClassificacaoImc.baixoPeso),
        'Abaixo do peso',
      );
      expect(
        rotuloClassificacaoImc(ClassificacaoImc.adequado),
        'Peso adequado',
      );
      expect(rotuloClassificacaoImc(ClassificacaoImc.sobrepeso), 'Sobrepeso');
      expect(rotuloClassificacaoImc(ClassificacaoImc.obesidade), 'Obesidade');
    });
  });
}
