import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/constants/momentos_glicemia.dart';
import 'package:agenda_saude_app/domain/lembretes/lembrete.dart';
import 'package:agenda_saude_app/domain/models/medicamento.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';

Paciente _paciente({
  bool possuiDiabetes = false,
  bool? usaInsulina,
  List<Medicamento> medicamentos = const [],
}) {
  return Paciente(
    id: 'p1',
    nome: 'José Silva',
    email: 'jose@email.com',
    perfil: 'Paciente',
    possuiDiabetes: possuiDiabetes,
    usaInsulina: usaInsulina,
    possuiCardiopatia: false,
    codigoVinculo: 'ABC123',
    medicamentos: medicamentos,
  );
}

void main() {
  group('Lembrete Testes', () {
    const losartana = Medicamento(
      id: 'm1',
      nome: 'Losartana',
      dose: '50 mg',
      horarios: ['08:00'],
    );
    const metformina = Medicamento(
      id: 'm2',
      nome: 'Metformina',
      dose: '500 mg',
      horarios: ['12:00', '20:00'],
    );

    test('Deve separar a hora e os minutos do horário', () {
      const lembrete = Lembrete(
        chave: 'k',
        tipo: TipoLembrete.remedio,
        titulo: 't',
        texto: 'x',
        resumo: 'r',
        horario: '07:45',
      );

      expect(lembrete.hora, 7);
      expect(lembrete.minuto, 45);
    });

    test('Deve calcular o instante do lembrete em um dia', () {
      const lembrete = Lembrete(
        chave: 'k',
        tipo: TipoLembrete.remedio,
        titulo: 't',
        texto: 'x',
        resumo: 'r',
        horario: '20:05',
      );

      expect(
        lembrete.em(DateTime(2026, 11, 5, 13, 30)),
        DateTime(2026, 11, 5, 20, 5),
      );
    });

    group('doPaciente', () {
      test('Não deve ter lembretes sem remédios e sem diabetes', () {
        expect(Lembrete.doPaciente(_paciente()), isEmpty);
      });

      test('Deve fazer um lembrete por dose de remédio, em ordem de horário', () {
        final lembretes = Lembrete.doPaciente(
          _paciente(medicamentos: [metformina, losartana]),
        );

        expect(lembretes.map((l) => l.horario), ['08:00', '12:00', '20:00']);
        expect(lembretes.every((l) => l.tipo == TipoLembrete.remedio), isTrue);
        expect(lembretes.first.titulo, 'Hora do remédio');
        expect(lembretes.first.texto, contains('Losartana 50 mg'));
      });

      test('Deve resumir cada aviso em poucas palavras para a lista', () {
        final lembretes = Lembrete.doPaciente(
          _paciente(
            possuiDiabetes: true,
            usaInsulina: true,
            medicamentos: [losartana],
          ),
        );

        expect(lembretes.map((l) => l.resumo), [
          'Medir a glicemia (ao acordar)',
          'Tomar Losartana 50 mg',
          'Medir a glicemia (antes do almoço)',
          'Medir a glicemia (antes do jantar)',
          'Medir a glicemia (antes de dormir)',
          'Aplicar a insulina lenta',
        ]);
      });

      test('Deve guardar o momento só nos avisos de glicemia e de insulina', () {
        final lembretes = Lembrete.doPaciente(
          _paciente(
            possuiDiabetes: true,
            usaInsulina: true,
            medicamentos: [losartana],
          ),
        );

        expect(lembretes.map((l) => l.nomeDoMomento), [
          'Ao acordar',
          null, // o remedio nao tem momento
          'Antes do almoço',
          'Antes do jantar',
          'Antes de dormir',
          'Insulina lenta (22h)',
        ]);
      });

      test('Deve usar a mesma chave da dose para a rotina poder cumpri-la', () {
        final lembretes =
            Lembrete.doPaciente(_paciente(medicamentos: [metformina]));

        expect(lembretes.map((l) => l.chave), [
          'remedio|m2|12:00',
          'remedio|m2|20:00',
        ]);
      });

      test('Deve ignorar o horário de remédio que não é uma hora válida', () {
        const estranho = Medicamento(
          id: 'm9',
          nome: 'Estranho',
          horarios: ['25:99', ''],
        );

        final lembretes = Lembrete.doPaciente(
          _paciente(medicamentos: [estranho, losartana]),
        );

        expect(lembretes.map((l) => l.chave), ['remedio|m1|08:00']);
      });

      test('Deve agendar a hora normalizada de um horário digitado de outro jeito', () {
        const digitado = Medicamento(id: 'm3', nome: 'Digitado', horarios: ['8:30']);

        final lembretes =
            Lembrete.doPaciente(_paciente(medicamentos: [digitado]));

        expect(lembretes.single.horario, '08:30');
        // A chave continua a da dose, que e o que os registros guardam.
        expect(lembretes.single.chave, 'remedio|m3|8:30');
      });

      test('Deve lembrar das quatro medições do diabético sem insulina', () {
        final lembretes = Lembrete.doPaciente(_paciente(possuiDiabetes: true));

        expect(lembretes.map((l) => l.chave), [
          'glicemia|Ao acordar',
          'glicemia|Antes do almoço',
          'glicemia|Antes do jantar',
          'glicemia|Antes de dormir',
        ]);
        expect(lembretes.map((l) => l.horario), [
          '07:00',
          '11:30',
          '18:00',
          '21:30',
        ]);
        expect(lembretes.every((l) => l.tipo == TipoLembrete.glicemia), isTrue);
        expect(lembretes.first.titulo, 'Hora de medir a glicemia');
      });

      test('Deve incluir a insulina lenta das 22h para quem usa insulina', () {
        final lembretes = Lembrete.doPaciente(
          _paciente(possuiDiabetes: true, usaInsulina: true),
        );

        expect(lembretes, hasLength(5));
        final insulina = lembretes.last;
        expect(insulina.tipo, TipoLembrete.insulina);
        expect(insulina.horario, '22:00');
        expect(insulina.chave, 'insulina|Insulina lenta (22h)');
        expect(insulina.titulo, 'Hora da insulina lenta');
      });

      test('Não deve lembrar de glicemia de quem não tem diabetes', () {
        final lembretes = Lembrete.doPaciente(
          _paciente(usaInsulina: true, medicamentos: [losartana]),
        );

        expect(lembretes.map((l) => l.tipo), [TipoLembrete.remedio]);
      });

      test('Deve usar o horário que o paciente escolheu para um momento', () {
        final lembretes = Lembrete.doPaciente(
          _paciente(possuiDiabetes: true),
          horariosDosMomentos: {MomentoGlicemia.aoAcordar.nome: '6:30'},
        );

        expect(lembretes.first.chave, 'glicemia|Ao acordar');
        expect(lembretes.first.horario, '06:30');
      });

      test('Deve voltar ao horário padrão se o escolhido não for válido', () {
        final lembretes = Lembrete.doPaciente(
          _paciente(possuiDiabetes: true),
          horariosDosMomentos: {MomentoGlicemia.aoAcordar.nome: 'abc'},
        );

        expect(lembretes.first.horario, '07:00');
      });

      test('Deve misturar remédios e glicemia na ordem do dia', () {
        final lembretes = Lembrete.doPaciente(
          _paciente(
            possuiDiabetes: true,
            usaInsulina: true,
            medicamentos: [losartana, metformina],
          ),
        );

        expect(lembretes.map((l) => l.horario), [
          '07:00',
          '08:00',
          '11:30',
          '12:00',
          '18:00',
          '20:00',
          '21:30',
          '22:00',
        ]);
      });
    });
  });
}
