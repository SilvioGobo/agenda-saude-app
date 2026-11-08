import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agenda_saude_app/core/constants/momentos_glicemia.dart';
import 'package:agenda_saude_app/data/repositories/preferencias_repository.dart';
import 'package:agenda_saude_app/domain/acessibilidade/configuracao_narrador.dart';

void main() {
  group('PreferenciasRepository Testes', () {
    late PreferenciasRepository repositorio;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repositorio = PreferenciasRepository();
    });

    test('Deve vir com os lembretes ligados', () async {
      expect(await repositorio.lembretesLigados('p1'), isTrue);
    });

    test('Deve guardar que os lembretes foram desligados', () async {
      await repositorio.salvarLembretesLigados('p1', false);

      expect(await repositorio.lembretesLigados('p1'), isFalse);
    });

    test('Deve guardar a escolha de cada paciente à parte', () async {
      await repositorio.salvarLembretesLigados('p1', false);

      expect(await repositorio.lembretesLigados('p2'), isTrue);
    });

    test('Deve continuar desligado depois de reabrir o armazenamento', () async {
      await repositorio.salvarLembretesLigados('p1', false);

      // Um repositório novo lê o que o anterior gravou.
      expect(await PreferenciasRepository().lembretesLigados('p1'), isFalse);
    });

    test('Não deve ter horário escolhido de início', () async {
      expect(await repositorio.horariosDosMomentos('p1'), isEmpty);
    });

    test('Deve guardar o horário escolhido para um momento', () async {
      await repositorio.salvarHorarioDoMomento(
        'p1',
        MomentoGlicemia.aoAcordar.nome,
        '06:30',
      );

      expect(await repositorio.horariosDosMomentos('p1'), {
        MomentoGlicemia.aoAcordar.nome: '06:30',
      });
    });

    test('Deve voltar ao padrão quando o horário escolhido é apagado', () async {
      await repositorio.salvarHorarioDoMomento(
        'p1',
        MomentoGlicemia.aoAcordar.nome,
        '06:30',
      );

      await repositorio.salvarHorarioDoMomento(
        'p1',
        MomentoGlicemia.aoAcordar.nome,
        null,
      );

      expect(await repositorio.horariosDosMomentos('p1'), isEmpty);
    });

    test('Deve guardar os horários de cada paciente à parte', () async {
      await repositorio.salvarHorarioDoMomento(
        'p1',
        MomentoGlicemia.antesDoJantar.nome,
        '19:00',
      );

      expect(await repositorio.horariosDosMomentos('p2'), isEmpty);
    });

    group('narrador', () {
      test('Deve vir desligado, na velocidade normal', () async {
        final configuracao = await repositorio.narrador();

        expect(configuracao.ligado, isFalse);
        expect(configuracao.velocidade, VelocidadeNarracao.normal);
      });

      test('Deve guardar que o narrador foi ligado', () async {
        await repositorio.salvarNarradorLigado(true);

        expect((await repositorio.narrador()).ligado, isTrue);
      });

      test('Deve guardar a velocidade escolhida', () async {
        await repositorio.salvarVelocidadeDoNarrador(VelocidadeNarracao.devagar);

        expect(
          (await repositorio.narrador()).velocidade,
          VelocidadeNarracao.devagar,
        );
      });

      test('Deve guardar a ligação e a velocidade sem uma apagar a outra', () async {
        await repositorio.salvarNarradorLigado(true);
        await repositorio.salvarVelocidadeDoNarrador(VelocidadeNarracao.rapido);
        await repositorio.salvarNarradorLigado(false);

        final configuracao = await repositorio.narrador();
        expect(configuracao.ligado, isFalse);
        expect(configuracao.velocidade, VelocidadeNarracao.rapido);
      });

      test('Deve valer para qualquer paciente que usar o aparelho', () async {
        // O narrador e do aparelho: nao tem id de paciente.
        await repositorio.salvarNarradorLigado(true);

        final outroRepositorio = PreferenciasRepository();
        expect((await outroRepositorio.narrador()).ligado, isTrue);
      });

      test('Deve voltar à velocidade normal se o valor guardado for desconhecido', () async {
        SharedPreferences.setMockInitialValues({
          'narrador.ligado': true,
          'narrador.velocidade': 'ultrarrapido',
        });

        final configuracao = await PreferenciasRepository().narrador();

        expect(configuracao.ligado, isTrue);
        expect(configuracao.velocidade, VelocidadeNarracao.normal);
      });
    });

    test('Deve ignorar um valor salvo que não é um horário válido', () async {
      SharedPreferences.setMockInitialValues({
        'lembretes.horario.p1.Ao acordar': 'abc',
        'lembretes.horario.p1.Antes do almoço': '12:15',
      });

      expect(await PreferenciasRepository().horariosDosMomentos('p1'), {
        MomentoGlicemia.antesDoAlmoco.nome: '12:15',
      });
    });
  });
}
