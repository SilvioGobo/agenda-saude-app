import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/lembretes/lembrete.dart';
import 'package:agenda_saude_app/domain/lembretes/plano_de_lembretes.dart';
import 'package:agenda_saude_app/domain/models/registro_diabete.dart';
import 'package:agenda_saude_app/domain/models/registro_medicacao.dart';

Lembrete _remedio(String horario, {String id = 'm1'}) {
  return Lembrete(
    chave: 'remedio|$id|$horario',
    tipo: TipoLembrete.remedio,
    titulo: 'Hora do remédio',
    texto: 'Losartana 50 mg',
    resumo: 'Tomar Losartana 50 mg',
    descricao: 'Losartana 50 mg',
    horario: horario,
  );
}

// So os lembretes do plano, sem os avisos de pendencia (RF 06.3), que tem os
// testes deles no fim do arquivo.
List<OcorrenciaDeLembrete> _lembretes(PlanoDeLembretes plano) =>
    plano.agendar.where((ocorrencia) => !ocorrencia.pendencia).toList();

List<OcorrenciaDeLembrete> _pendencias(PlanoDeLembretes plano) =>
    plano.agendar.where((ocorrencia) => ocorrencia.pendencia).toList();

void main() {
  group('idDaNotificacao Testes', () {
    test('Deve dar sempre o mesmo id para o mesmo texto', () {
      expect(idDaNotificacao('remedio|m1|08:00@2026-11-05'),
          idDaNotificacao('remedio|m1|08:00@2026-11-05'));
    });

    test('Deve dar ids diferentes para textos diferentes', () {
      expect(idDaNotificacao('remedio|m1|08:00@2026-11-05'),
          isNot(idDaNotificacao('remedio|m1|08:00@2026-11-06')));
    });

    test('Deve caber em 31 bits, o que o plugin de notificações aceita', () {
      for (var i = 0; i < 500; i++) {
        final id = idDaNotificacao('lembrete-$i');
        expect(id, inInclusiveRange(0, 0x7fffffff));
      }
    });
  });

  group('OcorrenciaDeLembrete Testes', () {
    test('Deve dar um id por dia ao mesmo lembrete', () {
      final lembrete = _remedio('08:00');
      final hoje = OcorrenciaDeLembrete(lembrete, DateTime(2026, 11, 5, 8));
      final amanha = OcorrenciaDeLembrete(lembrete, DateTime(2026, 11, 6, 8));

      expect(hoje.id, isNot(amanha.id));
      expect(hoje.id,
          OcorrenciaDeLembrete(lembrete, DateTime(2026, 11, 5, 8)).id);
    });

    test('Deve ter um payload que identifica o lembrete e o dia', () {
      final ocorrencia =
          OcorrenciaDeLembrete(_remedio('08:00'), DateTime(2026, 11, 5, 8));

      expect(ocorrencia.payload, 'lembrete:remedio|m1|08:00@2026-11-05');
      expect(
        ocorrencia.payload.startsWith(OcorrenciaDeLembrete.prefixoDoPayload),
        isTrue,
      );
    });
  });

  group('PlanejadorDeLembretes.chavesCumpridas Testes', () {
    test('Deve contar uma dose de remédio marcada', () {
      final chaves = PlanejadorDeLembretes.chavesCumpridas(
        medicacoes: [
          RegistroMedicacao(
            id: 'r1',
            pacienteId: 'p1',
            dataHora: DateTime(2026, 11, 5, 8, 10),
            medicamentoId: 'm1',
            horario: '08:00',
            nome: 'Losartana',
          ),
        ],
      );

      expect(chaves, {'remedio|m1|08:00'});
    });

    test('Deve contar o momento da glicemia registrado como medição e como insulina', () {
      final chaves = PlanejadorDeLembretes.chavesCumpridas(
        diabete: [
          RegistroDiabete(
            id: 'd1',
            pacienteId: 'p1',
            dataHora: DateTime(2026, 11, 5, 7, 5),
            momento: 'Ao acordar',
            nivelGlicose: 110,
          ),
        ],
      );

      expect(chaves, containsAll(['glicemia|Ao acordar', 'insulina|Ao acordar']));
    });

    test('Não deve ter nada cumprido sem registros', () {
      expect(PlanejadorDeLembretes.chavesCumpridas(), isEmpty);
    });
  });

  group('PlanejadorDeLembretes.planejar Testes', () {
    final manha = _remedio('08:00');
    final noite = _remedio('20:00', id: 'm2');

    test('Deve agendar o que ainda vai tocar hoje e os dias seguintes', () {
      final plano = PlanejadorDeLembretes.planejar(
        lembretes: [manha, noite],
        cumpridosHoje: {},
        agora: DateTime(2026, 11, 5, 7, 0),
        dias: 2,
      );

      expect(_lembretes(plano).map((o) => o.dataHora), [
        DateTime(2026, 11, 5, 8),
        DateTime(2026, 11, 5, 20),
        DateTime(2026, 11, 6, 8),
        DateTime(2026, 11, 6, 20),
      ]);
    });

    test('Não deve agendar para hoje o horário que já passou', () {
      final plano = PlanejadorDeLembretes.planejar(
        lembretes: [manha, noite],
        cumpridosHoje: {},
        agora: DateTime(2026, 11, 5, 9, 0),
        dias: 2,
      );

      expect(_lembretes(plano).map((o) => o.dataHora), [
        DateTime(2026, 11, 5, 20),
        DateTime(2026, 11, 6, 8),
        DateTime(2026, 11, 6, 20),
      ]);
    });

    test('Não deve agendar um aviso para daqui a segundos, que o plugin recusaria', () {
      final plano = PlanejadorDeLembretes.planejar(
        lembretes: [manha],
        cumpridosHoje: {},
        agora: DateTime(2026, 11, 5, 7, 59, 50),
        dias: 1,
      );

      expect(_lembretes(plano), isEmpty);
    });

    test('Deve tirar só o de hoje quando a dose já foi cumprida', () {
      final plano = PlanejadorDeLembretes.planejar(
        lembretes: [manha, noite],
        cumpridosHoje: {manha.chave},
        agora: DateTime(2026, 11, 5, 7, 0),
        dias: 2,
      );

      expect(_lembretes(plano).map((o) => o.dataHora), [
        DateTime(2026, 11, 5, 20),
        DateTime(2026, 11, 6, 8),
        DateTime(2026, 11, 6, 20),
      ]);
    });

    test('Deve apontar o id do lembrete cumprido hoje, mesmo que o horário já tenha passado', () {
      final plano = PlanejadorDeLembretes.planejar(
        lembretes: [manha],
        cumpridosHoje: {manha.chave},
        agora: DateTime(2026, 11, 5, 9, 0),
        dias: 2,
      );

      final idDeHoje =
          OcorrenciaDeLembrete(manha, DateTime(2026, 11, 5, 8)).id;
      final pendenciaDeHoje =
          OcorrenciaDeLembrete.pendencia(manha, DateTime(2026, 11, 5, 8)).id;
      // O lembrete e o aviso de pendencia dele saem da bandeja.
      expect(plano.cumpridosHoje, [idDeHoje, pendenciaDeHoje]);
      // E o de amanhã segue agendado.
      expect(_lembretes(plano).map((o) => o.dataHora), [DateTime(2026, 11, 6, 8)]);
    });

    test('Deve respeitar o limite de agendamentos, ficando com os mais próximos', () {
      final plano = PlanejadorDeLembretes.planejar(
        lembretes: [manha, noite],
        cumpridosHoje: {},
        agora: DateTime(2026, 11, 5, 7, 0),
        dias: 7,
        limite: 3,
      );

      expect(_lembretes(plano).map((o) => o.dataHora), [
        DateTime(2026, 11, 5, 8),
        DateTime(2026, 11, 5, 20),
        DateTime(2026, 11, 6, 8),
      ]);
    });

    test('Deve usar sete dias e no máximo 60 agendamentos por padrão', () {
      final lembretes = [
        for (var h = 0; h < 12; h++) _remedio('${h.toString().padLeft(2, '0')}:10', id: 'm$h'),
      ];

      final plano = PlanejadorDeLembretes.planejar(
        lembretes: lembretes,
        cumpridosHoje: {},
        agora: DateTime(2026, 11, 5, 0, 0),
      );

      // 12 por dia em 7 dias seriam 84.
      expect(_lembretes(plano), hasLength(PlanejadorDeLembretes.limiteDeAgendamentos));
      expect(_lembretes(plano).last.dataHora.isBefore(DateTime(2026, 11, 12)), isTrue);
    });

    test('Deve desempatar o mesmo horário pela chave, sempre na mesma ordem', () {
      final a = _remedio('08:00', id: 'a');
      final b = _remedio('08:00', id: 'b');

      final plano = PlanejadorDeLembretes.planejar(
        lembretes: [b, a],
        cumpridosHoje: {},
        agora: DateTime(2026, 11, 5, 7, 0),
        dias: 1,
      );

      expect(_lembretes(plano).map((o) => o.lembrete.chave), [a.chave, b.chave]);
    });

    test('Deve passar do fim do mês para o seguinte', () {
      final plano = PlanejadorDeLembretes.planejar(
        lembretes: [manha],
        cumpridosHoje: {},
        agora: DateTime(2026, 11, 29, 7, 0),
        dias: 3,
      );

      expect(_lembretes(plano).map((o) => o.dataHora), [
        DateTime(2026, 11, 29, 8),
        DateTime(2026, 11, 30, 8),
        DateTime(2026, 12, 1, 8),
      ]);
    });

    test('Não deve agendar nada sem lembretes', () {
      final plano = PlanejadorDeLembretes.planejar(
        lembretes: const [],
        cumpridosHoje: {},
        agora: DateTime(2026, 11, 5, 7, 0),
      );

      expect(plano.agendar, isEmpty);
      expect(plano.cumpridosHoje, isEmpty);
    });
  });

  group('Aviso de pendência (RF 06.3) Testes', () {
    final manha = _remedio('08:00');
    final noite = _remedio('20:00', id: 'm2');

    test('Deve agendar a pendência uma hora depois de cada lembrete, só para hoje e amanhã', () {
      final plano = PlanejadorDeLembretes.planejar(
        lembretes: [manha, noite],
        cumpridosHoje: {},
        agora: DateTime(2026, 11, 5, 7, 0),
      );

      expect(_pendencias(plano).map((o) => o.dataHora), [
        DateTime(2026, 11, 5, 9),
        DateTime(2026, 11, 5, 21),
        DateTime(2026, 11, 6, 9),
        DateTime(2026, 11, 6, 21),
      ]);
      // Os lembretes continuam nos sete dias.
      expect(_lembretes(plano), hasLength(14));
    });

    test('Deve manter a pendência de hoje depois do horário do lembrete, até o horário-limite', () {
      final plano = PlanejadorDeLembretes.planejar(
        lembretes: [manha],
        cumpridosHoje: {},
        agora: DateTime(2026, 11, 5, 8, 30),
        dias: 1,
      );

      expect(_lembretes(plano), isEmpty);
      expect(_pendencias(plano).single.dataHora, DateTime(2026, 11, 5, 9));
    });

    test('Deve tirar a pendência de hoje junto com o lembrete cumprido', () {
      final plano = PlanejadorDeLembretes.planejar(
        lembretes: [manha],
        cumpridosHoje: {manha.chave},
        agora: DateTime(2026, 11, 5, 7, 0),
      );

      expect(_pendencias(plano).map((o) => o.dataHora), [DateTime(2026, 11, 6, 9)]);
      expect(
        plano.cumpridosHoje,
        contains(
          OcorrenciaDeLembrete.pendencia(manha, DateTime(2026, 11, 5, 8)).id,
        ),
      );
    });

    test('Não deve agendar no aparelho a pendência que passaria da meia-noite', () {
      final tarde = _remedio('23:30', id: 'm3');

      final plano = PlanejadorDeLembretes.planejar(
        lembretes: [tarde],
        cumpridosHoje: {},
        agora: DateTime(2026, 11, 5, 7, 0),
      );

      expect(_pendencias(plano), isEmpty);
      expect(_lembretes(plano), isNotEmpty);
    });

    test('A pendência não conta no limite dos lembretes', () {
      final plano = PlanejadorDeLembretes.planejar(
        lembretes: [manha, noite],
        cumpridosHoje: {},
        agora: DateTime(2026, 11, 5, 7, 0),
        limite: 3,
      );

      expect(_lembretes(plano), hasLength(3));
      expect(_pendencias(plano), hasLength(4));
    });

    test('Deve ter id e payload próprios, no dia da tarefa, e os textos da pendência', () {
      final lembrete = OcorrenciaDeLembrete(manha, DateTime(2026, 11, 5, 8));
      final pendencia =
          OcorrenciaDeLembrete.pendencia(manha, DateTime(2026, 11, 5, 8));

      expect(pendencia.pendencia, isTrue);
      expect(pendencia.dataHora, DateTime(2026, 11, 5, 9));
      expect(pendencia.id, isNot(lembrete.id));
      expect(
        pendencia.payload,
        'lembrete:remedio|m1|08:00@2026-11-05${OcorrenciaDeLembrete.sufixoDaPendencia}',
      );
      expect(pendencia.titulo, 'Remédio ainda não marcado');
      expect(pendencia.texto, startsWith('Losartana 50 mg, das 08:00.'));
      expect(lembrete.titulo, 'Hora do remédio');
    });
  });
}
