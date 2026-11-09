import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/batimentos/monitor_zona_seguranca.dart';
import 'package:agenda_saude_app/domain/models/alerta.dart';
import 'package:agenda_saude_app/domain/models/batimento_cardiaco.dart';
import 'package:agenda_saude_app/domain/models/limites_alerta.dart';

void main() {
  group('MonitorZonaSeguranca Testes', () {
    final agora = DateTime(2026, 11, 7, 15, 0);

    BatimentoCardiaco leitura(int bpm, int minutosAtras) => BatimentoCardiaco(
          id: '',
          pacienteId: 'paciente_01',
          bpm: bpm,
          timestamp: agora.subtract(Duration(minutes: minutosAtras)),
        );

    Alerta alerta(String tipo, int minutosAtras) => Alerta(
          id: 'alerta_$minutosAtras',
          pacienteId: 'paciente_01',
          tipo: tipo,
          mensagem: '',
          dataHora: agora.subtract(Duration(minutes: minutosAtras)),
        );

    MonitorZonaSeguranca retomar({
      List<BatimentoCardiaco> gravados = const [],
      List<Alerta> alertas = const [],
      bool possuiCardiopatia = false,
      LimitesAlerta? limites,
    }) {
      return MonitorZonaSeguranca.retomar(
        pacienteId: 'paciente_01',
        possuiCardiopatia: possuiCardiopatia,
        limites: limites,
        gravados: gravados,
        alertas: alertas,
      );
    }

    List<String> tipos(List<Alerta> alertas) =>
        alertas.map((a) => a.tipo).toList();

    test('Deve gerar uma emergência com 5 minutos fora da zona, sem "Atenção" junto', () {
      final alertas = retomar().avaliar([
        leitura(120, 6),
        leitura(125, 3),
        leitura(122, 1),
      ]);

      expect(tipos(alertas), [Alerta.tipoEmergencia]);
      expect(alertas.single.bpm, 122);
      expect(alertas.single.pacienteId, 'paciente_01');
      expect(
        alertas.single.mensagem,
        'Batimentos fora da zona de segurança há 5 minutos (última leitura: 122 BPM).',
      );
      expect(alertas.single.dataHora, agora.subtract(const Duration(minutes: 1)));
    });

    test('Deve avisar "Atenção" quando a leitura mais recente sai da zona', () {
      final alertas = retomar().avaliar([leitura(72, 3), leitura(118, 1)]);

      expect(tipos(alertas), [Alerta.tipoAtencao]);
      expect(alertas.single.mensagem, 'Batimentos acima da zona de segurança (118 BPM).');
    });

    test('Não deve alertar por um pico isolado que já voltou para a zona', () {
      final alertas = retomar().avaliar([
        leitura(70, 4),
        leitura(130, 3),
        leitura(72, 2),
      ]);

      expect(alertas, isEmpty);
    });

    test('Deve usar a zona mais estreita do cardiopata', () {
      final alertas = retomar(possuiCardiopatia: true)
          .avaliar([leitura(95, 7), leitura(96, 1)]);

      expect(tipos(alertas), [Alerta.tipoEmergencia]);
    });

    test('Deve continuar o episódio das leituras já gravadas e alertar no tempo certo', () {
      // O app (ou a execucao anterior com o app fechado) parou com o
      // paciente fora da zona havia 3 minutos, ja com o aviso de atencao.
      final monitor = retomar(
        gravados: [leitura(72, 20), leitura(118, 10), leitura(121, 7)],
        alertas: [alerta(Alerta.tipoAtencao, 10)],
      );

      final alertas = monitor.avaliar([leitura(123, 4)]);

      // 6 minutos desde a primeira leitura fora da zona (ha 10 min).
      expect(tipos(alertas), [Alerta.tipoEmergencia]);
      expect(alertas.single.mensagem, contains('há 6 minutos'));
    });

    test('Não deve repetir a emergência que o episódio já teve', () {
      final monitor = retomar(
        gravados: [leitura(120, 20), leitura(121, 14), leitura(123, 8)],
        alertas: [alerta(Alerta.tipoEmergencia, 14)],
      );

      expect(monitor.avaliar([leitura(124, 2)]), isEmpty);
    });

    test('Deve tratar a emergência de um episódio anterior como encerrada', () {
      // Emergencia antiga, depois o BPM voltou para a zona: e outro episodio.
      final monitor = retomar(
        gravados: [leitura(120, 40), leitura(121, 34), leitura(72, 30)],
        alertas: [alerta(Alerta.tipoEmergencia, 34)],
      );

      final alertas = monitor.avaliar([leitura(118, 8), leitura(119, 2)]);

      expect(tipos(alertas), [Alerta.tipoEmergencia]);
    });

    test('Não deve avisar "Atenção" de novo se o painel já estava em atenção', () {
      final monitor = retomar(gravados: [leitura(118, 3)]);

      expect(monitor.avaliar([leitura(121, 1)]), isEmpty);
    });

    test('Deve respeitar o intervalo mínimo desde o último aviso gravado', () {
      // Aviso ha 10 min; o BPM voltou e saiu de novo.
      final monitor = retomar(
        gravados: [leitura(118, 10), leitura(72, 5)],
        alertas: [alerta(Alerta.tipoAtencao, 10)],
      );

      expect(monitor.avaliar([leitura(119, 1)]), isEmpty);
    });

    test('Deve avisar de novo passado o intervalo mínimo desde o último aviso', () {
      final monitor = retomar(
        gravados: [leitura(118, 30), leitura(72, 20)],
        alertas: [alerta(Alerta.tipoAtencao, 30)],
      );

      expect(tipos(monitor.avaliar([leitura(119, 1)])), [Alerta.tipoAtencao]);
    });

    test('Não deve mudar o painel por uma leitura antiga que chegou atrasada', () {
      final monitor = retomar(gravados: [leitura(72, 1)]);

      // Leitura de 20 min atras, fora da zona, sincronizada so agora.
      expect(monitor.avaliar([leitura(118, 20)]), isEmpty);
    });

    test('Deve guardar o estado entre uma avaliação e outra', () {
      final monitor = retomar();

      expect(tipos(monitor.avaliar([leitura(118, 10)])), [Alerta.tipoAtencao]);
      expect(tipos(monitor.avaliar([leitura(120, 4)])), [Alerta.tipoEmergencia]);
      expect(monitor.avaliar([leitura(122, 1)]), isEmpty);
    });

    test('Não deve gerar nada sem leituras novas', () {
      expect(retomar().avaliar([]), isEmpty);
    });

    group('com os limites do acompanhante (RF 06.1)', () {
      const limites = LimitesAlerta(bpmMinimo: 50, bpmMaximo: 120);

      test('Não deve alertar dentro dos limites do paciente, mesmo fora da zona padrão', () {
        final alertas = retomar(limites: limites).avaliar([
          leitura(110, 7),
          leitura(115, 3),
          leitura(52, 1),
        ]);

        expect(alertas, isEmpty);
      });

      test('Deve alertar acima do máximo do paciente', () {
        final alertas = retomar(limites: limites).avaliar([
          leitura(125, 6),
          leitura(130, 1),
        ]);

        expect(tipos(alertas), [Alerta.tipoEmergencia]);
      });

      test('Deve dizer "abaixo" pela zona do paciente', () {
        final alertas = retomar(limites: limites).avaliar([leitura(48, 1)]);

        expect(tipos(alertas), [Alerta.tipoAtencao]);
        expect(alertas.single.mensagem, contains('abaixo'));
      });

      test('Os limites valem também para o cardiopata', () {
        final alertas = retomar(possuiCardiopatia: true, limites: limites)
            .avaliar([leitura(95, 7), leitura(96, 1)]);

        expect(alertas, isEmpty);
      });

      test('Retomar com limites novos reavalia as leituras gravadas com eles', () {
        // Com a zona padrao (ate 100), 95 BPM e normal; o acompanhante baixou
        // o maximo para 90 e o paciente esta acima dele ha 10 minutos.
        final monitor = retomar(
          gravados: [leitura(95, 10), leitura(96, 6)],
          limites: const LimitesAlerta(bpmMinimo: 50, bpmMaximo: 90),
        );

        expect(tipos(monitor.avaliar([leitura(97, 1)])), [Alerta.tipoEmergencia]);
      });
    });
  });
}
