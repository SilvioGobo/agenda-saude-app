import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Com o seletor de hora aberto (`mostrarSeletorDeHorario`), escolhe o horario
// como a pessoa faz: toca na hora no relogio, depois nos minutos (de 5 em 5),
// e confirma em OK.
//
// As posicoes seguem o desenho do relogio do Flutter 3.32: os numeros ficam a
// 28 da borda e o anel de dentro (12 a 23), mais 28 para dentro; o 00 (ou o 12)
// fica no alto e as horas andam no sentido do relogio.
Future<void> escolherNoSeletorDeHorario(
  WidgetTester tester, {
  required int hora,
  required int minuto,
}) async {
  assert(minuto % 5 == 0, 'Tocando no relogio, os minutos vao de 5 em 5.');
  final relogio = find.byKey(const ValueKey<String>('time-picker-dial'));

  Offset ponto(double fracaoDaVolta, {bool aneldeDentro = false}) {
    final area = tester.getRect(relogio);
    final raioDosNumeros = area.shortestSide / 2 - 28;
    final raio = aneldeDentro ? raioDosNumeros - 28 : raioDosNumeros;
    final angulo = fracaoDaVolta * 2 * math.pi;
    return area.center + Offset(math.sin(angulo), -math.cos(angulo)) * raio;
  }

  await tester.tapAt(ponto((hora % 12) / 12, aneldeDentro: hora >= 12));
  await tester.pumpAndSettle();
  await tester.tapAt(ponto(minuto / 60));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}
