import 'package:flutter_test/flutter_test.dart';
import 'package:agenda_saude_app/domain/metas/metas_personalizadas.dart';

MetasPersonalizadas criarMetas() {
  return const MetasPersonalizadas(
    imc: 24.7,
    classificacaoImc: ClassificacaoImc.adequado,
    hidratacaoMl: 2000,
    sonoMinHoras: 7,
    sonoMaxHoras: 8,
    passos: 6000,
    exercicioMinutosSemana: 150,
    calorias: 1800,
    carboidratosG: 225,
    proteinasG: 90,
    gordurasG: 60,
    fibrasG: 25,
    gorduraSaturadaMaxG: 20,
    acucarLivreMaxG: 45,
    sodioMaxMg: 2000,
  );
}

void main() {
  group('MetasPersonalizadas Testes', () {
    test('Deve converter para JSON e voltar sem perder nenhum campo', () {
      final original = criarMetas().comAjustes(passos: 5000);

      final copia = MetasPersonalizadas.fromJson(original.toJson());

      expect(copia.imc, 24.7);
      expect(copia.classificacaoImc, ClassificacaoImc.adequado);
      expect(copia.hidratacaoMl, 2000);
      expect(copia.sonoMinHoras, 7);
      expect(copia.sonoMaxHoras, 8);
      expect(copia.passos, 5000);
      expect(copia.exercicioMinutosSemana, 150);
      expect(copia.calorias, 1800);
      expect(copia.carboidratosG, 225);
      expect(copia.proteinasG, 90);
      expect(copia.gordurasG, 60);
      expect(copia.fibrasG, 25);
      expect(copia.gorduraSaturadaMaxG, 20);
      expect(copia.acucarLivreMaxG, 45);
      expect(copia.sodioMaxMg, 2000);
      expect(copia.ajustadaManualmente, true);
    });

    test('Deve usar valores seguros quando o JSON vier incompleto', () {
      final metas = MetasPersonalizadas.fromJson({
        'classificacaoImc': 'desconhecida',
      });

      expect(metas.classificacaoImc, ClassificacaoImc.adequado);
      expect(metas.hidratacaoMl, 2000);
      expect(metas.ajustadaManualmente, false);
    });

    test('Deve contar a hidratacao em copos de 250 ml', () {
      expect(criarMetas().hidratacaoCopos, 8);
    });

    test('Deve ajustar so as metas da rotina e marcar como ajustada', () {
      final original = criarMetas();
      expect(original.ajustadaManualmente, false);

      final ajustada = original.comAjustes(
        hidratacaoMl: 1500,
        exercicioMinutosSemana: 90,
      );

      expect(ajustada.hidratacaoMl, 1500);
      expect(ajustada.exercicioMinutosSemana, 90);
      expect(ajustada.passos, 6000); // nao informado: continua igual
      expect(ajustada.calorias, 1800); // metas nutricionais nao mudam
      expect(ajustada.sodioMaxMg, 2000);
      expect(ajustada.ajustadaManualmente, true);
    });
  });
}
