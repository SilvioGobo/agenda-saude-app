import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/acessibilidade/configuracao_narrador.dart';

void main() {
  group('VelocidadeNarracao Testes', () {
    test('Deve ter três velocidades, da mais lenta à mais rápida', () {
      expect(VelocidadeNarracao.values, [
        VelocidadeNarracao.devagar,
        VelocidadeNarracao.normal,
        VelocidadeNarracao.rapido,
      ]);
      final taxas = VelocidadeNarracao.values.map((v) => v.taxa).toList();
      expect(taxas, [...taxas]..sort());
    });

    test('Deve usar a taxa 0,5 na velocidade normal', () {
      expect(VelocidadeNarracao.normal.taxa, 0.5);
    });

    test('Deve ter taxas que o plugin de voz aceita (de 0 a 1)', () {
      for (final velocidade in VelocidadeNarracao.values) {
        expect(velocidade.taxa, inInclusiveRange(0.0, 1.0));
      }
    });

    test('Deve ter um rótulo em português para cada velocidade', () {
      expect(VelocidadeNarracao.values.map((v) => v.rotulo), [
        'Devagar',
        'Normal',
        'Rápido',
      ]);
    });

    test('Deve achar a velocidade pelo nome guardado', () {
      expect(VelocidadeNarracao.porNome('devagar'), VelocidadeNarracao.devagar);
      expect(VelocidadeNarracao.porNome('rapido'), VelocidadeNarracao.rapido);
    });

    test('Deve voltar ao normal com um nome desconhecido ou ausente', () {
      expect(VelocidadeNarracao.porNome('ultrarrapido'), VelocidadeNarracao.normal);
      expect(VelocidadeNarracao.porNome(null), VelocidadeNarracao.normal);
    });
  });

  group('ConfiguracaoNarrador Testes', () {
    test('Deve vir desligado, na velocidade normal', () {
      const configuracao = ConfiguracaoNarrador();

      expect(configuracao.ligado, isFalse);
      expect(configuracao.velocidade, VelocidadeNarracao.normal);
    });

    test('Deve copiar mudando só o que foi pedido', () {
      const configuracao = ConfiguracaoNarrador();

      final ligada = configuracao.copyWith(ligado: true);
      expect(ligada.ligado, isTrue);
      expect(ligada.velocidade, VelocidadeNarracao.normal);

      final lenta = ligada.copyWith(velocidade: VelocidadeNarracao.devagar);
      expect(lenta.ligado, isTrue);
      expect(lenta.velocidade, VelocidadeNarracao.devagar);
    });
  });
}
