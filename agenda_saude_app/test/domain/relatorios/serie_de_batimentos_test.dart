import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/models/batimento_cardiaco.dart';
import 'package:agenda_saude_app/domain/relatorios/serie_de_batimentos.dart';

BatimentoCardiaco _leitura(int bpm, DateTime timestamp) {
  return BatimentoCardiaco(
    id: '',
    pacienteId: 'p1',
    bpm: bpm,
    timestamp: timestamp,
  );
}

void main() {
  group('SerieDeBatimentos Testes', () {
    final inicio = DateTime(2026, 11, 5);
    final fim = DateTime(2026, 11, 6);

    SerieDeBatimentos serieDe(
      List<BatimentoCardiaco> leituras, {
      int intervaloMinutos = 10,
    }) {
      return SerieDeBatimentos.de(
        leituras,
        inicio: inicio,
        fim: fim,
        intervaloMinutos: intervaloMinutos,
      );
    }

    group('agrupar as leituras', () {
      test('Deve ficar vazia sem leituras', () {
        final serie = serieDe(const []);

        expect(serie.vazia, isTrue);
        expect(serie.pontos, isEmpty);
        expect(serie.minimo, isNull);
        expect(serie.maximo, isNull);
        expect(serie.trechos(), isEmpty);
      });

      test('Deve resumir as leituras de um intervalo em um ponto', () {
        final serie = serieDe([
          _leitura(60, DateTime(2026, 11, 5, 8, 1)),
          _leitura(70, DateTime(2026, 11, 5, 8, 4)),
          _leitura(80, DateTime(2026, 11, 5, 8, 9)),
        ]);

        expect(serie.pontos, hasLength(1));
        final ponto = serie.pontos.single;
        expect(ponto.inicio, DateTime(2026, 11, 5, 8, 0));
        expect(ponto.fim, DateTime(2026, 11, 5, 8, 10));
        expect(ponto.media, 70);
        expect(ponto.minimo, 60);
        expect(ponto.maximo, 80);
        expect(ponto.leituras, 3);
      });

      test('Deve separar os intervalos, em ordem de horário', () {
        // Chegam do mais novo para o mais antigo, como a consulta devolve.
        final serie = serieDe([
          _leitura(90, DateTime(2026, 11, 5, 9, 15)),
          _leitura(70, DateTime(2026, 11, 5, 8, 5)),
          _leitura(80, DateTime(2026, 11, 5, 8, 25)),
        ]);

        expect(serie.pontos.map((p) => p.inicio), [
          DateTime(2026, 11, 5, 8, 0),
          DateTime(2026, 11, 5, 8, 20),
          DateTime(2026, 11, 5, 9, 10),
        ]);
        expect(serie.pontos.map((p) => p.media), [70, 80, 90]);
      });

      test('Deve contar a leitura que cai exatamente na virada de um intervalo no seguinte', () {
        final serie = serieDe([
          _leitura(70, DateTime(2026, 11, 5, 8, 9, 59)),
          _leitura(80, DateTime(2026, 11, 5, 8, 10)),
        ]);

        expect(serie.pontos, hasLength(2));
        expect(serie.pontos.first.leituras, 1);
        expect(serie.pontos.last.inicio, DateTime(2026, 11, 5, 8, 10));
      });

      test('Deve incluir a leitura da meia-noite de início', () {
        final serie = serieDe([_leitura(65, inicio)]);

        expect(serie.pontos.single.inicio, inicio);
      });

      test('Deve ignorar o que está fora do dia', () {
        final serie = serieDe([
          _leitura(50, DateTime(2026, 11, 4, 23, 59)),
          _leitura(70, DateTime(2026, 11, 5, 12)),
          // A meia-noite do dia seguinte ja e do outro dia.
          _leitura(90, fim),
          _leitura(95, DateTime(2026, 11, 6, 3)),
        ]);

        expect(serie.pontos, hasLength(1));
        expect(serie.pontos.single.media, 70);
      });

      test('Deve lembrar o tamanho do intervalo, de 10 minutos por padrão', () {
        expect(serieDe(const []).intervaloMinutos, 10);
        expect(serieDe(const [], intervaloMinutos: 30).intervaloMinutos, 30);
      });

      test('Deve usar o tamanho de intervalo pedido', () {
        final leituras = [
          _leitura(60, DateTime(2026, 11, 5, 8, 5)),
          _leitura(80, DateTime(2026, 11, 5, 8, 25)),
        ];

        final de30 = serieDe(leituras, intervaloMinutos: 30);

        expect(de30.pontos, hasLength(1));
        expect(de30.pontos.single.media, 70);
        expect(de30.pontos.single.fim, DateTime(2026, 11, 5, 8, 30));
      });

      test('Deve cortar o último intervalo no fim do dia', () {
        // 7 minutos nao divide 24 horas: o ultimo intervalo passaria da meia-noite.
        final serie = serieDe(
          [_leitura(70, DateTime(2026, 11, 5, 23, 58))],
          intervaloMinutos: 7,
        );

        expect(serie.pontos.single.fim, fim);
      });

      test('Deve reduzir um dia de leituras a cada 30 segundos a no máximo 144 pontos', () {
        final leituras = [
          for (var i = 0; i < 2880; i++)
            _leitura(60 + i % 40, inicio.add(Duration(seconds: 30 * i))),
        ];

        final serie = serieDe(leituras);

        expect(serie.pontos.length, lessThanOrEqualTo(144));
        expect(serie.pontos.length, 144);
        // Nenhuma leitura se perde na conta.
        expect(serie.pontos.fold<int>(0, (soma, p) => soma + p.leituras), 2880);
      });
    });

    group('ponto', () {
      test('Deve ter o meio do intervalo como posição no gráfico', () {
        final serie = serieDe([_leitura(70, DateTime(2026, 11, 5, 8, 3))]);

        expect(serie.pontos.single.meio, DateTime(2026, 11, 5, 8, 5));
      });

      test('Deve manter a subida rápida no maior valor, mesmo com a média baixa', () {
        final serie = serieDe([
          for (var i = 0; i < 9; i++) _leitura(70, DateTime(2026, 11, 5, 8, 0, i * 30)),
          _leitura(130, DateTime(2026, 11, 5, 8, 9)),
        ]);

        final ponto = serie.pontos.single;
        expect(ponto.media, lessThan(80));
        expect(ponto.maximo, 130);
      });
    });

    group('extremos do dia', () {
      test('Deve dar o menor e o maior BPM de todas as leituras', () {
        final serie = serieDe([
          _leitura(58, DateTime(2026, 11, 5, 3)),
          _leitura(72, DateTime(2026, 11, 5, 12)),
          _leitura(121, DateTime(2026, 11, 5, 18)),
        ]);

        expect(serie.minimo, 58);
        expect(serie.maximo, 121);
      });
    });

    group('trechos', () {
      test('Deve ligar em um só trecho os pontos próximos', () {
        final serie = serieDe([
          _leitura(70, DateTime(2026, 11, 5, 8, 5)),
          _leitura(72, DateTime(2026, 11, 5, 8, 35)),
          _leitura(74, DateTime(2026, 11, 5, 9, 5)),
        ]);

        expect(serie.trechos(), hasLength(1));
        expect(serie.trechos().single, hasLength(3));
      });

      test('Deve cortar o trecho quando passa mais de uma hora sem leitura', () {
        // O relogio ficou fora do pulso das 9h as 12h.
        final serie = serieDe([
          _leitura(70, DateTime(2026, 11, 5, 8, 5)),
          _leitura(72, DateTime(2026, 11, 5, 8, 55)),
          _leitura(80, DateTime(2026, 11, 5, 12, 5)),
          _leitura(82, DateTime(2026, 11, 5, 12, 15)),
        ]);

        final trechos = serie.trechos();
        expect(trechos, hasLength(2));
        expect(trechos.first, hasLength(2));
        expect(trechos.last, hasLength(2));
      });

      test('Deve manter ligado o buraco de exatamente uma hora', () {
        // Do fim do 1o intervalo (8:10) ao inicio do 2o (9:10): 1 hora.
        final serie = serieDe([
          _leitura(70, DateTime(2026, 11, 5, 8, 5)),
          _leitura(72, DateTime(2026, 11, 5, 9, 15)),
        ]);

        expect(serie.trechos(), hasLength(1));
      });

      test('Deve deixar um ponto isolado como trecho de um ponto só', () {
        final serie = serieDe([
          _leitura(70, DateTime(2026, 11, 5, 3)),
          _leitura(90, DateTime(2026, 11, 5, 18)),
        ]);

        expect(serie.trechos().map((t) => t.length), [1, 1]);
      });

      test('Deve usar a lacuna pedida', () {
        final serie = serieDe([
          _leitura(70, DateTime(2026, 11, 5, 8, 5)),
          _leitura(72, DateTime(2026, 11, 5, 8, 55)),
        ]);

        expect(serie.trechos(lacunaMinutos: 20), hasLength(2));
        expect(serie.trechos(lacunaMinutos: 60), hasLength(1));
      });
    });
  });
}
