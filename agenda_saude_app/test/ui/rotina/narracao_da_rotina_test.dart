import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/medicacao/dose_planejada.dart';
import 'package:agenda_saude_app/ui/rotina/narracao_da_rotina.dart';

int palavras(String texto) => texto.split(RegExp(r'\s+')).length;

DosePlanejada dose(String nome, String horario, {String dosagem = ''}) {
  return DosePlanejada(
    medicamentoId: nome.toLowerCase(),
    nome: nome,
    dose: dosagem,
    horario: horario,
  );
}

// Uma rotina em que tudo esta feito; cada teste muda so o que quer provar.
String narrar({
  int aguaMl = 2000,
  int metaAguaMl = 2000,
  int dosesTotal = 0,
  List<DosePlanejada> dosesPendentes = const [],
  int refeicoesTotal = 0,
  int refeicoesFeitas = 0,
  int? medicoesPendentes,
  bool insulinaPendente = false,
  bool sonoRegistrado = true,
  int exercicioMinutosNaSemana = 150,
  int exercicioMetaSemanal = 150,
}) {
  return narrarRotina(
    aguaMl: aguaMl,
    metaAguaMl: metaAguaMl,
    dosesTotal: dosesTotal,
    dosesPendentes: dosesPendentes,
    refeicoesTotal: refeicoesTotal,
    refeicoesFeitas: refeicoesFeitas,
    medicoesPendentes: medicoesPendentes,
    insulinaPendente: insulinaPendente,
    sonoRegistrado: sonoRegistrado,
    exercicioMinutosNaSemana: exercicioMinutosNaSemana,
    exercicioMetaSemanal: exercicioMetaSemanal,
  );
}

void main() {
  group('narrarRotina Testes', () {
    test('Deve parabenizar, sem listar nada, quando tudo está feito', () {
      expect(
        narrar(),
        'Sua rotina de hoje. Parabéns! Tudo da rotina de hoje já está feito. '
        'A meta de exercício da semana já foi batida.',
      );
    });

    test('Deve dizer quantos itens estão completos e só o que falta', () {
      final texto = narrar(
        aguaMl: 750,
        sonoRegistrado: false,
        exercicioMinutosNaSemana: 40,
      );

      expect(
        texto,
        'Sua rotina de hoje. Você completou 0 de 2 itens. Falta beber mais 5 '
        'copos de água e registrar o sono. Nesta semana, 40 de 150 minutos de '
        'exercício.',
      );
    });

    test('Deve contar só os itens que se aplicam ao paciente', () {
      // Sem remédios, sem plano de refeições e sem diabetes: água e sono.
      expect(narrar(sonoRegistrado: false), contains('completou 1 de 2 itens'));

      // Com remédios, refeições e diabetes: água, remédios, refeições, glicemia
      // e sono, cinco itens.
      final completo = narrar(
        dosesTotal: 2,
        refeicoesTotal: 4,
        refeicoesFeitas: 4,
        medicoesPendentes: 0,
      );
      expect(completo, contains('Parabéns'));
      final pendente = narrar(
        dosesTotal: 2,
        dosesPendentes: [dose('Losartana', '08:00')],
        refeicoesTotal: 4,
        refeicoesFeitas: 4,
        medicoesPendentes: 0,
      );
      expect(pendente, contains('completou 4 de 5 itens'));
    });

    group('água', () {
      test('Deve dizer quantos copos faltam', () {
        expect(narrar(aguaMl: 1000), contains('Falta beber mais 4 copos de água'));
      });

      test('Deve falar um copo no singular', () {
        expect(narrar(aguaMl: 1750), contains('Falta beber mais 1 copo de água'));
      });

      test('Deve arredondar para cima quando a meta não é de copos inteiros', () {
        // Falta 50 ml: ainda e preciso um copo.
        expect(
          narrar(aguaMl: 2250, metaAguaMl: 2300),
          contains('beber mais 1 copo de água'),
        );
      });

      test('Deve dar a água como feita ao passar da meta', () {
        expect(narrar(aguaMl: 2600), isNot(contains('água')));
      });

      test('Não deve contar a água se o paciente não tem meta', () {
        final texto = narrar(
          aguaMl: 0,
          metaAguaMl: 0,
          sonoRegistrado: false,
        );

        expect(texto, contains('completou 0 de 1 item'));
        expect(texto, isNot(contains('água')));
      });
    });

    group('remédios', () {
      test('Deve dizer qual remédio falta e a hora, com a unidade por extenso', () {
        final texto = narrar(
          dosesTotal: 3,
          dosesPendentes: [dose('Losartana', '14:00', dosagem: '50mg')],
        );

        expect(
          texto,
          contains('Falta tomar Losartana 50 miligramas às 14 horas.'),
        );
      });

      test('Deve dizer quantos faltam e por qual começar', () {
        final texto = narrar(
          dosesTotal: 3,
          dosesPendentes: [
            dose('Losartana', '08:30', dosagem: '50 mg'),
            dose('Metformina', '20:00'),
          ],
        );

        expect(texto, contains('Falta tomar 2 remédios.'));
        expect(
          texto,
          contains(
            'O primeiro remédio é Losartana 50 miligramas, às 8 horas e 30 '
            'minutos.',
          ),
        );
      });

      test('Não deve citar remédios se o paciente não tem nenhum cadastrado', () {
        expect(narrar(sonoRegistrado: false), isNot(contains('remédio')));
      });

      test('Não deve cobrar remédios que já foram tomados', () {
        expect(narrar(dosesTotal: 3), isNot(contains('remédio')));
      });
    });

    group('refeições', () {
      test('Deve dizer quantas refeições faltam', () {
        expect(
          narrar(refeicoesTotal: 4, refeicoesFeitas: 2),
          contains('Falta fazer 2 refeições'),
        );
      });

      test('Deve falar uma refeição no singular', () {
        expect(
          narrar(refeicoesTotal: 4, refeicoesFeitas: 3),
          contains('Falta fazer 1 refeição.'),
        );
      });

      test('Não deve cobrar refeições se o plano está vazio', () {
        expect(narrar(sonoRegistrado: false), isNot(contains('refeiç')));
      });
    });

    group('glicemia e insulina', () {
      test('Deve dizer quantas medições faltam', () {
        expect(
          narrar(medicoesPendentes: 3),
          contains('Falta fazer 3 medições da glicemia'),
        );
      });

      test('Deve falar uma medição no singular', () {
        expect(
          narrar(medicoesPendentes: 1),
          contains('fazer 1 medição da glicemia'),
        );
      });

      test('Deve lembrar da insulina lenta', () {
        expect(
          narrar(medicoesPendentes: 0, insulinaPendente: true),
          contains('Falta registrar a insulina lenta'),
        );
      });

      test('Deve contar glicemia e insulina como um item só', () {
        final texto = narrar(medicoesPendentes: 2, insulinaPendente: true);

        expect(texto, contains('completou 2 de 3 itens'));
        expect(
          texto,
          contains('fazer 2 medições da glicemia e registrar a insulina lenta'),
        );
      });

      test('Não deve citar glicemia se o paciente não tem diabetes', () {
        expect(narrar(sonoRegistrado: false), isNot(contains('glicemia')));
      });
    });

    group('exercício', () {
      test('Deve dizer o progresso da semana', () {
        expect(
          narrar(exercicioMinutosNaSemana: 40),
          contains('Nesta semana, 40 de 150 minutos de exercício.'),
        );
      });

      test('Deve dizer que a meta da semana foi batida', () {
        expect(
          narrar(exercicioMinutosNaSemana: 200),
          contains('A meta de exercício da semana já foi batida.'),
        );
      });

      test('Não deve falar de exercício se não há meta', () {
        expect(
          narrar(exercicioMinutosNaSemana: 0, exercicioMetaSemanal: 0),
          isNot(contains('exercício')),
        );
      });

      test('Não deve contar o exercício entre os itens do dia', () {
        // Nada de exercicio na semana, mas o dia esta completo.
        expect(
          narrar(exercicioMinutosNaSemana: 0),
          contains('Parabéns! Tudo da rotina de hoje já está feito'),
        );
      });
    });

    test('Deve ser curto mesmo no pior caso: tudo pendente, com diabetes', () {
      final texto = narrar(
        aguaMl: 0,
        dosesTotal: 5,
        dosesPendentes: [
          dose('Losartana', '08:30', dosagem: '50 mg'),
          dose('Metformina', '12:00', dosagem: '850 mg'),
          dose('Sinvastatina', '20:00', dosagem: '20 mg'),
        ],
        refeicoesTotal: 6,
        refeicoesFeitas: 0,
        medicoesPendentes: 4,
        insulinaPendente: true,
        sonoRegistrado: false,
        exercicioMinutosNaSemana: 0,
      );

      expect(palavras(texto), lessThan(80), reason: texto);
    });

    test('Deve ter avisos prontos para quando a rotina não carregou', () {
      expect(rotinaCarregandoNarrada, contains('carregando'));
      expect(rotinaComErroNarrada, contains('Não foi possível'));
    });
  });
}
