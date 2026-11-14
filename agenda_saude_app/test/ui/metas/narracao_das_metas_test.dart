import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/metas/metas_personalizadas.dart';
import 'package:agenda_saude_app/ui/metas/narracao_das_metas.dart';

int palavras(String texto) => texto.split(RegExp(r'\s+')).length;

void main() {
  group('narrarMetas Testes', () {
    // Idosa de 70 anos, 60 kg, sedentaria.
    const metas = MetasPersonalizadas(
      imc: 25,
      classificacaoImc: ClassificacaoImc.adequado,
      hidratacaoMl: 1750,
      sonoMinHoras: 7,
      sonoMaxHoras: 8,
      passos: 4000,
      exercicioMinutosSemana: 150,
      calorias: 1270,
      carboidratosG: 160,
      proteinasG: 60,
      gordurasG: 40,
      fibrasG: 25,
      gorduraSaturadaMaxG: 14,
      acucarLivreMaxG: 32,
      sodioMaxMg: 2000,
    );

    test('Deve ler as metas do dia a dia, sem siglas', () {
      final texto = narrarMetas(metas: metas);

      expect(texto, contains('Beber 7 copos de água.'));
      expect(texto, contains('Andar 4000 passos.'));
      expect(texto, contains('Comer cerca de 1270 calorias.'));
      expect(texto, contains('Dormir de 7 a 8 horas por noite.'));
      expect(texto, contains('150 minutos de exercício por semana.'));
      expect(texto, isNot(contains('kcal')));
      expect(texto, isNot(contains('IMC')));
    });

    test('Deve dizer que são sugestões e para onde ir para mudar', () {
      final texto = narrarMetas(metas: metas);

      expect(texto, contains('São sugestões'));
      expect(texto, contains('Personalizar rotina, no menu.'));
      // O peso muda em "Meus dados", o nome no alto do menu.
      expect(texto, contains('Para atualizar o seu peso, toque no seu nome'));
      expect(texto, isNot(contains('Atualizar meu peso')));
    });

    test('Deve lembrar do limite de água do médico quando há um', () {
      expect(
        narrarMetas(metas: metas, limiteLiquidoMl: 1500),
        contains('limite de água que o seu médico definiu'),
      );
      expect(narrarMetas(metas: metas), isNot(contains('limite de água')));
    });

    test('Na primeira vez, sem menu ainda, deve mandar seguir pelo botão de baixo', () {
      final texto = narrarMetas(metas: metas, primeiraVez: true);

      expect(texto, contains('Aceitar e continuar'));
      expect(texto, isNot(contains('menu')));
    });

    test('Sem metas calculadas, deve dizer isso em poucas palavras', () {
      final texto = narrarMetas(metas: null);

      expect(texto, startsWith('Ainda não foi possível calcular suas metas.'));
      expect(palavras(texto), lessThan(20), reason: texto);
    });

    test('Deve caber em 15 a 40 segundos de fala', () {
      for (final texto in [
        narrarMetas(metas: metas),
        narrarMetas(metas: metas, limiteLiquidoMl: 1500),
        narrarMetas(metas: metas, primeiraVez: true),
      ]) {
        expect(palavras(texto), inInclusiveRange(50, 95), reason: texto);
      }
    });
  });
}
