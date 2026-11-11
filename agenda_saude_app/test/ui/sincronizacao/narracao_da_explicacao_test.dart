import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/ui/sincronizacao/narracao_da_explicacao.dart';

int palavras(String texto) => texto.split(RegExp(r'\s+')).length;

void main() {
  group('narrarExplicacaoBatimentos Testes', () {
    test('Deve contar o caminho, o que fazer e onde fica o Saúde Connect', () {
      final texto = narrarExplicacaoBatimentos();

      expect(texto, startsWith('O Agenda Saúde não se liga direto no relógio.'));
      expect(texto, contains('ligue a opção Saúde Connect'));
      expect(texto, contains('procure por Saúde Connect.'));
      // "Aplicativo" por extenso: a voz le "app" mal.
      expect(texto, isNot(contains(' app ')));
    });

    test('Deve caber em 15 a 40 segundos de fala', () {
      final texto = narrarExplicacaoBatimentos();

      expect(palavras(texto), inInclusiveRange(50, 95), reason: texto);
    });
  });
}
