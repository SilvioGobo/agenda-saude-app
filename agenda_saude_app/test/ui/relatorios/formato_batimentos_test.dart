import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/models/alerta.dart';
import 'package:agenda_saude_app/domain/relatorios/resumo_do_dia.dart';
import 'package:agenda_saude_app/ui/relatorios/formato_batimentos.dart';

Alerta _alerta(String tipo, int hora, int minuto, {int? bpm}) {
  return Alerta(
    id: 'a$hora$minuto',
    pacienteId: 'p1',
    tipo: tipo,
    mensagem: 'BPM fora da zona',
    bpm: bpm,
    dataHora: DateTime(2026, 11, 5, hora, minuto),
  );
}

BatimentosDoDia _batimentos({int foraDaZona = 0, int zonaMaxima = 100}) {
  return BatimentosDoDia(
    leituras: 40,
    media: 78.4,
    minimo: 58,
    maximo: 121,
    foraDaZona: foraDaZona,
    zonaMinima: 60,
    zonaMaxima: zonaMaxima,
  );
}

void main() {
  group('descreverGraficoDeBatimentos Testes', () {
    test('Deve dizer a variação do dia e a média', () {
      final texto = descreverGraficoDeBatimentos(
        batimentos: _batimentos(),
        alertas: const [],
      );

      expect(
        texto,
        contains('Os batimentos variaram de 58 a 121 BPM, com média de 78.'),
      );
      expect(texto, startsWith('Gráfico dos batimentos do dia, das 0 às 24 horas.'));
    });

    test('Deve dizer quando todas as leituras ficaram dentro da zona', () {
      final texto = descreverGraficoDeBatimentos(
        batimentos: _batimentos(),
        alertas: const [],
      );

      expect(
        texto,
        contains(
          'Todas as leituras ficaram dentro da zona de segurança, de 60 a 100 BPM.',
        ),
      );
    });

    test('Deve contar as leituras fora da zona, no singular e no plural', () {
      final uma = descreverGraficoDeBatimentos(
        batimentos: _batimentos(foraDaZona: 1),
        alertas: const [],
      );
      final varias = descreverGraficoDeBatimentos(
        batimentos: _batimentos(foraDaZona: 7, zonaMaxima: 90),
        alertas: const [],
      );

      expect(uma, contains('1 leitura ficou fora da zona de segurança, de 60 a 100 BPM.'));
      expect(
        varias,
        contains('7 leituras ficaram fora da zona de segurança, de 60 a 90 BPM.'),
      );
    });

    test('Deve dizer que não houve alerta', () {
      final texto = descreverGraficoDeBatimentos(
        batimentos: _batimentos(),
        alertas: const [],
      );

      expect(texto, endsWith('Nenhum alerta no dia.'));
    });

    test('Deve contar cada alerta com o tipo, a hora e o BPM', () {
      final texto = descreverGraficoDeBatimentos(
        batimentos: _batimentos(foraDaZona: 3),
        alertas: [
          _alerta(Alerta.tipoEmergencia, 14, 32, bpm: 118),
          _alerta(Alerta.tipoAtencao, 14, 10),
        ],
      );

      expect(texto, contains('Alerta de atenção às 14:10.'));
      expect(texto, contains('Alerta de emergência às 14:32, com 118 BPM.'));
      expect(texto, isNot(contains('Nenhum alerta')));
    });

    test('Deve contar os alertas do mais antigo para o mais recente', () {
      final texto = descreverGraficoDeBatimentos(
        batimentos: _batimentos(),
        // O resumo os entrega do mais recente para o mais antigo.
        alertas: [
          _alerta(Alerta.tipoEmergencia, 15, 0, bpm: 120),
          _alerta(Alerta.tipoAtencao, 9, 0, bpm: 105),
        ],
      );

      expect(
        texto.indexOf('às 09:00'),
        lessThan(texto.indexOf('às 15:00')),
      );
    });

    test('Deve limitar os alertas falados e dizer quantos ficaram de fora', () {
      final texto = descreverGraficoDeBatimentos(
        batimentos: _batimentos(),
        alertas: [
          for (var hora = 8; hora < 15; hora++)
            _alerta(Alerta.tipoAtencao, hora, 0, bpm: 105),
        ],
        maximoDeAlertas: 5,
      );

      expect(RegExp('Alerta de atenção às').allMatches(texto), hasLength(5));
      expect(texto, endsWith('E mais 2 alertas.'));
    });

    test('Deve falar "1 alerta" no singular', () {
      final texto = descreverGraficoDeBatimentos(
        batimentos: _batimentos(),
        alertas: [
          _alerta(Alerta.tipoAtencao, 8, 0),
          _alerta(Alerta.tipoAtencao, 9, 0),
        ],
        maximoDeAlertas: 1,
      );

      expect(texto, endsWith('E mais 1 alerta.'));
    });
  });
}
