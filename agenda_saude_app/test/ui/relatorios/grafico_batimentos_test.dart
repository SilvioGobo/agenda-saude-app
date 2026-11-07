import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/theme/app_cores.dart';
import 'package:agenda_saude_app/core/theme/app_theme.dart';
import 'package:agenda_saude_app/domain/models/alerta.dart';
import 'package:agenda_saude_app/domain/models/batimento_cardiaco.dart';
import 'package:agenda_saude_app/domain/relatorios/serie_de_batimentos.dart';
import 'package:agenda_saude_app/ui/relatorios/grafico_batimentos.dart';

final _dia = DateTime(2026, 11, 5);

BatimentoCardiaco _leitura(int bpm, int hora, [int minuto = 0]) {
  return BatimentoCardiaco(
    id: '',
    pacienteId: 'p1',
    bpm: bpm,
    timestamp: DateTime(2026, 11, 5, hora, minuto),
  );
}

SerieDeBatimentos _serie(List<BatimentoCardiaco> leituras) {
  return SerieDeBatimentos.de(
    leituras,
    inicio: _dia,
    fim: DateTime(2026, 11, 6),
  );
}

Alerta _alerta(String tipo, {int? bpm, int hora = 14}) {
  return Alerta(
    id: 'a$hora',
    pacienteId: 'p1',
    tipo: tipo,
    mensagem: 'BPM fora da zona',
    bpm: bpm,
    dataHora: DateTime(2026, 11, 5, hora, 30),
  );
}

// Um dia com subida e descida, todo dentro da zona de 60 a 100.
List<BatimentoCardiaco> _diaCalmo() => [
      for (var hora = 0; hora < 24; hora++) _leitura(65 + (hora % 6) * 5, hora),
    ];

void main() {
  group('GraficoBatimentos Testes', () {
    final chave = GlobalKey();

    Future<void> montar(
      WidgetTester tester, {
      required SerieDeBatimentos serie,
      List<Alerta> alertas = const [],
      int zonaMinima = 60,
      int zonaMaxima = 100,
      String descricao = 'Gráfico de teste',
      double largura = 400,
      double escalaTexto = 1,
    }) async {
      tester.view.physicalSize = Size(largura + 40, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escalaTexto)),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: chave,
                child: Material(
                  child: SizedBox(
                    width: largura,
                    child: GraficoBatimentos(
                      serie: serie,
                      zonaMinima: zonaMinima,
                      zonaMaxima: zonaMaxima,
                      alertas: alertas,
                      descricao: descricao,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Todas as cores que aparecem no desenho, como ARGB.
    Future<Set<int>> coresDesenhadas(WidgetTester tester) async {
      final cores = await tester.runAsync(() async {
        final fronteira = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(chave),
        );
        final imagem = await fronteira.toImage();
        final dados = await imagem.toByteData(format: ui.ImageByteFormat.rawRgba);
        final bytes = dados!.buffer.asUint8List();
        final conjunto = <int>{};
        for (var i = 0; i < bytes.length; i += 4) {
          conjunto.add(
            (bytes[i + 3] << 24) | (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2],
          );
        }
        return conjunto;
      });
      return cores!;
    }

    final primaria = AppTheme.claro.colorScheme.primary.toARGB32();

    group('desenho', () {
      testWidgets('Deve desenhar a zona de segurança e a curva', (tester) async {
        await montar(tester, serie: _serie(_diaCalmo()));

        final cores = await coresDesenhadas(tester);
        expect(cores, contains(AppCores.sucessoContainer.toARGB32()));
        expect(cores, contains(primaria));
      });

      testWidgets('Deve marcar o alerta de emergência com vermelho', (tester) async {
        await montar(
          tester,
          serie: _serie(_diaCalmo()),
          alertas: [_alerta(Alerta.tipoEmergencia, bpm: 120)],
        );

        expect(await coresDesenhadas(tester), contains(AppCores.perigo.toARGB32()));
      });

      testWidgets('Deve marcar o alerta de atenção com laranja', (tester) async {
        await montar(
          tester,
          serie: _serie(_diaCalmo()),
          alertas: [_alerta(Alerta.tipoAtencao, bpm: 105)],
        );

        final cores = await coresDesenhadas(tester);
        expect(cores, contains(AppCores.aviso.toARGB32()));
        expect(cores, isNot(contains(AppCores.perigo.toARGB32())));
      });

      testWidgets('Não deve pintar de vermelho nem de laranja sem alertas', (tester) async {
        await montar(tester, serie: _serie(_diaCalmo()));

        final cores = await coresDesenhadas(tester);
        // A legenda tambem nao tem marcas de alerta: nada de vermelho nem laranja.
        expect(cores, isNot(contains(AppCores.perigo.toARGB32())));
        expect(cores, isNot(contains(AppCores.aviso.toARGB32())));
      });

      testWidgets('Deve marcar o alerta que não guardou o BPM, no alto do gráfico', (tester) async {
        await montar(
          tester,
          serie: _serie(_diaCalmo()),
          alertas: [_alerta(Alerta.tipoEmergencia)],
        );

        expect(await coresDesenhadas(tester), contains(AppCores.perigo.toARGB32()));
        expect(tester.takeException(), isNull);
      });
    });

    group('legenda', () {
      testWidgets('Deve explicar a linha e a zona de segurança', (tester) async {
        await montar(tester, serie: _serie(_diaCalmo()));

        expect(find.text('Média a cada 10 minutos'), findsOneWidget);
        expect(find.text('Zona de segurança (60 a 100 BPM)'), findsOneWidget);
      });

      testWidgets('Deve usar a zona do cardiopata quando é ela', (tester) async {
        await montar(
          tester,
          serie: _serie(_diaCalmo()),
          zonaMaxima: 90,
        );

        expect(find.text('Zona de segurança (60 a 90 BPM)'), findsOneWidget);
      });

      testWidgets('Deve mostrar na legenda só os tipos de alerta que existem', (tester) async {
        await montar(
          tester,
          serie: _serie(_diaCalmo()),
          alertas: [_alerta(Alerta.tipoEmergencia, bpm: 120)],
        );

        expect(find.text('Alerta de emergência'), findsOneWidget);
        expect(find.text('Alerta de atenção'), findsNothing);
      });

      testWidgets('Deve mostrar os dois tipos quando há os dois', (tester) async {
        await montar(
          tester,
          serie: _serie(_diaCalmo()),
          alertas: [
            _alerta(Alerta.tipoEmergencia, bpm: 120, hora: 15),
            _alerta(Alerta.tipoAtencao, bpm: 105, hora: 14),
          ],
        );

        expect(find.text('Alerta de emergência'), findsOneWidget);
        expect(find.text('Alerta de atenção'), findsOneWidget);
      });

      testWidgets('Deve dizer o tamanho do intervalo da série', (tester) async {
        final serie = SerieDeBatimentos.de(
          _diaCalmo(),
          inicio: _dia,
          fim: DateTime(2026, 11, 6),
          intervaloMinutos: 30,
        );

        await montar(tester, serie: serie);

        expect(find.text('Média a cada 30 minutos'), findsOneWidget);
      });
    });

    group('leitor de tela', () {
      testWidgets('Deve falar a descrição do gráfico por inteiro, como uma imagem', (tester) async {
        final semantica = tester.ensureSemantics();
        await montar(
          tester,
          serie: _serie(_diaCalmo()),
          descricao: 'Gráfico dos batimentos do dia. Variaram de 65 a 90 BPM.',
        );

        expect(
          find.bySemanticsLabel(
            'Gráfico dos batimentos do dia. Variaram de 65 a 90 BPM.',
          ),
          findsOneWidget,
        );
        semantica.dispose();
      });
    });

    group('situações difíceis', () {
      testWidgets('Deve aguentar um dia só com uma leitura', (tester) async {
        await montar(tester, serie: _serie([_leitura(72, 12)]));

        expect(tester.takeException(), isNull);
        expect(await coresDesenhadas(tester), contains(primaria));
      });

      testWidgets('Deve deixar buraco onde o relógio ficou fora do pulso', (tester) async {
        await montar(
          tester,
          serie: _serie([
            _leitura(70, 8),
            _leitura(72, 9),
            _leitura(80, 15),
            _leitura(82, 16),
          ]),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('Deve aguentar BPM fora do que o eixo cobria antes', (tester) async {
        await montar(
          tester,
          serie: _serie([_leitura(20, 3), _leitura(210, 18)]),
          alertas: [_alerta(Alerta.tipoEmergencia, bpm: 230)],
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('Deve aguentar um dia inteiro de pontos de 10 em 10 minutos', (tester) async {
        final leituras = [
          for (var minuto = 0; minuto < 24 * 60; minuto += 10)
            _leitura(60 + minuto % 41, minuto ~/ 60, minuto % 60),
        ];

        await montar(tester, serie: _serie(leituras));

        expect(tester.takeException(), isNull);
      });

      testWidgets('Não deve desenhar nada, nem quebrar, sem pontos', (tester) async {
        await montar(tester, serie: _serie(const []));

        expect(tester.takeException(), isNull);
      });

      testWidgets('Deve caber num celular estreito com a fonte em 200%', (tester) async {
        await montar(
          tester,
          serie: _serie(_diaCalmo()),
          alertas: [
            _alerta(Alerta.tipoEmergencia, bpm: 120, hora: 15),
            _alerta(Alerta.tipoAtencao, bpm: 105, hora: 14),
          ],
          largura: 312,
          escalaTexto: 2,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Média a cada 10 minutos'), findsOneWidget);
      });
    });
  });
}
