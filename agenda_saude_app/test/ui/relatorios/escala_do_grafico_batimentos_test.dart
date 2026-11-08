import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/ui/relatorios/escala_do_grafico_batimentos.dart';

void main() {
  group('EscalaDoGraficoBatimentos Testes', () {
    final inicio = DateTime(2026, 11, 5);
    final fim = DateTime(2026, 11, 6);

    EscalaDoGraficoBatimentos escala({
      double largura = 240,
      double altura = 100,
      int bpmMinimo = 40,
      int bpmMaximo = 140,
    }) {
      return EscalaDoGraficoBatimentos(
        inicio: inicio,
        fim: fim,
        largura: largura,
        altura: altura,
        bpmMinimo: bpmMinimo,
        bpmMaximo: bpmMaximo,
      );
    }

    group('horizontal', () {
      test('Deve pôr a meia-noite de início na borda esquerda e a do fim na direita', () {
        expect(escala().x(inicio), 0);
        expect(escala().x(fim), 240);
      });

      test('Deve pôr o meio-dia no meio e as seis e as dezoito nos quartos', () {
        final e = escala();

        expect(e.x(DateTime(2026, 11, 5, 12)), 120);
        expect(e.x(DateTime(2026, 11, 5, 6)), 60);
        expect(e.x(DateTime(2026, 11, 5, 18)), 180);
      });

      test('Deve crescer em proporção ao horário', () {
        final e = escala(largura: 1440);

        // Uma unidade por minuto.
        expect(e.x(DateTime(2026, 11, 5, 8, 30)), 510);
      });

      test('Deve prender na borda um horário fora do dia', () {
        final e = escala();

        expect(e.x(DateTime(2026, 11, 4, 23)), 0);
        expect(e.x(DateTime(2026, 11, 6, 5)), 240);
      });

      test('Não deve quebrar com um dia sem duração', () {
        final e = EscalaDoGraficoBatimentos(
          inicio: inicio,
          fim: inicio,
          largura: 240,
          altura: 100,
          bpmMinimo: 40,
          bpmMaximo: 140,
        );

        expect(e.x(inicio), 0);
      });
    });

    group('vertical', () {
      test('Deve pôr o BPM mínimo da escala na base e o máximo no topo', () {
        final e = escala();

        expect(e.y(40), 100);
        expect(e.y(140), 0);
      });

      test('Deve pôr o BPM do meio da escala no meio', () {
        expect(escala().y(90), 50);
      });

      test('Deve subir quando o BPM sobe', () {
        final e = escala();

        expect(e.y(100), lessThan(e.y(60)));
      });

      test('Deve prender na borda um BPM fora da escala', () {
        final e = escala();

        expect(e.y(20), 100);
        expect(e.y(200), 0);
      });

      test('Deve aceitar a média, que não é inteira', () {
        expect(escala().y(72.5), closeTo(67.5, 0.0001));
      });

      test('Não deve quebrar com uma escala sem altura de BPM', () {
        final e = escala(bpmMinimo: 60, bpmMaximo: 60);

        expect(e.y(60), 100);
      });
    });

    group('numeros do eixo', () {
      test('Deve escrever todos os números quando cabem um embaixo do outro', () {
        expect(
          EscalaDoGraficoBatimentos.saltoDosNumeros(
            alturaDoNumero: 19,
            espacoEntreMarcas: 33,
          ),
          1,
        );
      });

      test('Deve pular números quando a fonte grande os faria se encostar', () {
        expect(
          EscalaDoGraficoBatimentos.saltoDosNumeros(
            alturaDoNumero: 38,
            espacoEntreMarcas: 34,
          ),
          2,
        );
        expect(
          EscalaDoGraficoBatimentos.saltoDosNumeros(
            alturaDoNumero: 80,
            espacoEntreMarcas: 34,
          ),
          3,
        );
      });

      test('Deve deixar um respiro entre os números, mesmo no limite', () {
        // Altura igual ao espaco: encostariam, entao pula.
        expect(
          EscalaDoGraficoBatimentos.saltoDosNumeros(
            alturaDoNumero: 30,
            espacoEntreMarcas: 30,
          ),
          2,
        );
      });

      test('Não deve quebrar sem espaço entre as marcas', () {
        expect(
          EscalaDoGraficoBatimentos.saltoDosNumeros(
            alturaDoNumero: 19,
            espacoEntreMarcas: 0,
          ),
          1,
        );
      });

      test('Deve numerar todas as marcas com salto 1', () {
        expect(
          EscalaDoGraficoBatimentos.marcasComNumero(
            marcas: [40, 60, 80, 100, 120, 140],
            zonaMinima: 60,
            salto: 1,
          ),
          [40, 60, 80, 100, 120, 140],
        );
      });

      test('Deve manter os limites da zona numerados ao pular de duas em duas', () {
        expect(
          EscalaDoGraficoBatimentos.marcasComNumero(
            marcas: [40, 60, 80, 100, 120, 140],
            zonaMinima: 60,
            salto: 2,
          ),
          [60, 100, 140],
        );
      });

      test('Deve partir da zona também quando ela não é a primeira marca', () {
        expect(
          EscalaDoGraficoBatimentos.marcasComNumero(
            marcas: [20, 40, 60, 80, 100],
            zonaMinima: 60,
            salto: 2,
          ),
          [20, 60, 100],
        );
      });

      test('Deve numerar a marca da zona mesmo com salto maior que o eixo', () {
        expect(
          EscalaDoGraficoBatimentos.marcasComNumero(
            marcas: [40, 60, 80],
            zonaMinima: 60,
            salto: 5,
          ),
          [60],
        );
      });

      test('Deve escrever as horas de 6 em 6 quando cabem', () {
        expect(
          EscalaDoGraficoBatimentos.horasComNumero(
            larguraDoMaiorRotulo: 30,
            espacoEntreHoras: 60,
          ),
          [0, 6, 12, 18, 24],
        );
      });

      test('Deve escrever só 0h, 12h e 24h quando as horas se encostariam', () {
        expect(
          EscalaDoGraficoBatimentos.horasComNumero(
            larguraDoMaiorRotulo: 44,
            espacoEntreHoras: 47,
          ),
          [0, 12, 24],
        );
      });
    });

    group('eixoVertical', () {
      test('Deve caber a zona de segurança padrão, com folga, em múltiplos de 20', () {
        final eixo = EscalaDoGraficoBatimentos.eixoVertical(
          menorBpm: 62,
          maiorBpm: 98,
          zonaMinima: 60,
          zonaMaxima: 100,
        );

        expect(eixo.minimo, 40);
        expect(eixo.maximo, 120);
        expect(eixo.marcas, [40, 60, 80, 100, 120]);
      });

      test('Deve abrir para cima quando uma leitura passa da zona', () {
        final eixo = EscalaDoGraficoBatimentos.eixoVertical(
          menorBpm: 70,
          maiorBpm: 131,
          zonaMinima: 60,
          zonaMaxima: 100,
        );

        expect(eixo.maximo, 160);
        expect(eixo.maximo, greaterThanOrEqualTo(131 + 10));
      });

      test('Deve abrir para baixo quando uma leitura cai da zona', () {
        final eixo = EscalaDoGraficoBatimentos.eixoVertical(
          menorBpm: 38,
          maiorBpm: 80,
          zonaMinima: 60,
          zonaMaxima: 100,
        );

        expect(eixo.minimo, 20);
      });

      test('Não deve descer abaixo de zero', () {
        final eixo = EscalaDoGraficoBatimentos.eixoVertical(
          menorBpm: 5,
          maiorBpm: 80,
          zonaMinima: 60,
          zonaMaxima: 100,
        );

        expect(eixo.minimo, 0);
      });

      test('Deve usar a zona estreita do cardiopata (60 a 90)', () {
        final eixo = EscalaDoGraficoBatimentos.eixoVertical(
          menorBpm: 70,
          maiorBpm: 80,
          zonaMinima: 60,
          zonaMaxima: 90,
        );

        expect(eixo.minimo, 40);
        expect(eixo.maximo, 100);
        expect(eixo.marcas, containsAll([60, 80]));
      });

      test('Deve incluir sempre os limites da zona dentro do eixo', () {
        for (final menor in [30, 58, 62, 75]) {
          for (final maior in [80, 99, 101, 140, 175]) {
            final eixo = EscalaDoGraficoBatimentos.eixoVertical(
              menorBpm: menor,
              maiorBpm: maior,
              zonaMinima: 60,
              zonaMaxima: 100,
            );

            expect(eixo.minimo, lessThanOrEqualTo(menor));
            expect(eixo.maximo, greaterThanOrEqualTo(maior));
            expect(eixo.minimo, lessThanOrEqualTo(60));
            expect(eixo.maximo, greaterThanOrEqualTo(100));
            expect(eixo.minimo % 20, 0);
            expect(eixo.maximo % 20, 0);
          }
        }
      });
    });
  });
}
