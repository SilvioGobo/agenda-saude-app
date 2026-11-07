import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/data/repositories/relatorios_repository.dart';
import 'package:agenda_saude_app/domain/models/alerta.dart';
import 'package:agenda_saude_app/domain/models/batimento_cardiaco.dart';
import 'package:agenda_saude_app/domain/models/registro_agua.dart';
import 'package:agenda_saude_app/domain/models/registro_base.dart';
import 'package:agenda_saude_app/domain/models/registro_diabete.dart';
import 'package:agenda_saude_app/domain/models/registro_exercicio.dart';
import 'package:agenda_saude_app/domain/models/registro_medicacao.dart';
import 'package:agenda_saude_app/domain/models/registro_refeicao.dart';
import 'package:agenda_saude_app/domain/models/registro_sono.dart';

void main() {
  group('RelatoriosRepository Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    late RelatoriosRepository repository;

    // Dia de 25/10/2026, do primeiro ao ultimo instante.
    final inicio = DateTime(2026, 10, 25);
    final fim = DateTime(2026, 10, 26);

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
      repository = RelatoriosRepository(firestore: fakeFirestore);
    });

    Future<void> agua(String paciente, DateTime quando, [int ml = 250]) {
      return dadosRepository.salvarRegistro(RegistroAgua(
        id: '',
        pacienteId: paciente,
        dataHora: quando,
        quantidadeML: ml,
      ));
    }

    Future<void> refeicao(String paciente, String id, DateTime quando) {
      return dadosRepository.salvarRegistro(RegistroRefeicao(
        id: '',
        pacienteId: paciente,
        dataHora: quando,
        refeicaoId: id,
        nome: id,
      ));
    }

    // A noite como o app grava: ao acordar, inicio e fim valem o instante do
    // registro.
    Future<void> sono(String paciente, DateTime quando, double horas) {
      return dadosRepository.salvarRegistro(RegistroSono(
        id: '',
        pacienteId: paciente,
        dataHora: quando,
        dataFim: quando,
        horasTotais: horas,
        qualidade: 4,
      ));
    }

    Future<void> dose(String paciente, String medicamentoId, String horario, DateTime quando) {
      return dadosRepository.salvarRegistro(RegistroMedicacao(
        id: '',
        pacienteId: paciente,
        dataHora: quando,
        medicamentoId: medicamentoId,
        horario: horario,
        nome: medicamentoId,
        dose: '50 mg',
      ));
    }

    Future<void> exercicio(String paciente, DateTime quando, int minutos) {
      return dadosRepository.salvarRegistro(RegistroExercicio(
        id: '',
        pacienteId: paciente,
        dataHora: quando,
        tipoExercicio: 'Caminhada',
        duracaoMinutos: minutos,
        intensidade: 'Moderada',
      ));
    }

    Future<void> diabete(String paciente, DateTime quando, double glicose) {
      return dadosRepository.salvarRegistro(RegistroDiabete(
        id: '',
        pacienteId: paciente,
        dataHora: quando,
        nivelGlicose: glicose,
        momento: 'Ao acordar',
      ));
    }

    Future<void> alerta(String paciente, String tipo, DateTime quando) {
      return dadosRepository.gerarAlerta(Alerta(
        id: '',
        pacienteId: paciente,
        tipo: tipo,
        mensagem: 'alerta',
        dataHora: quando,
      ));
    }

    Future<void> batimento(String paciente, int bpm, DateTime quando) {
      return dadosRepository.salvarBatimento(BatimentoCardiaco(
        id: '',
        pacienteId: paciente,
        bpm: bpm,
        timestamp: quando,
      ));
    }

    group('exerciciosDaSemanaAte', () {
      // Quarta-feira, 28/10/2026: a semana (domingo a sabado) comeca em 25/10.
      final quarta = DateTime(2026, 10, 28, 15);

      test('Deve trazer os exercícios do começo da semana até o fim do dia', () async {
        await exercicio('paciente_99', DateTime(2026, 10, 25, 8), 10); // domingo
        await exercicio('paciente_99', DateTime(2026, 10, 27, 7), 20);
        await exercicio('paciente_99', DateTime(2026, 10, 28, 23, 59, 59), 30);
        // Antes da semana, depois do dia e de outro paciente.
        await exercicio('paciente_99', DateTime(2026, 10, 24, 23, 59, 59), 60);
        await exercicio('paciente_99', DateTime(2026, 10, 29), 60);
        await exercicio('outro_paciente', DateTime(2026, 10, 27, 9), 60);

        final registros =
            await repository.exerciciosDaSemanaAte('paciente_99', quarta);

        expect(registros.map((r) => r.duracaoMinutos), [30, 20, 10]);
      });

      test('Num domingo, só conta o próprio domingo', () async {
        await exercicio('paciente_99', DateTime(2026, 10, 25, 8), 10);
        await exercicio('paciente_99', DateTime(2026, 10, 24, 8), 60);
        await exercicio('paciente_99', DateTime(2026, 10, 26, 8), 60);

        final registros = await repository.exerciciosDaSemanaAte(
          'paciente_99',
          DateTime(2026, 10, 25),
        );

        expect(registros.map((r) => r.duracaoMinutos), [10]);
      });

      test('Deve ignorar registros que não são de exercício', () async {
        await exercicio('paciente_99', DateTime(2026, 10, 27, 7), 20);
        await agua('paciente_99', DateTime(2026, 10, 27, 8));

        final registros =
            await repository.exerciciosDaSemanaAte('paciente_99', quarta);

        expect(registros.length, 1);
      });
    });

    group('registrosDoPeriodo', () {
      test('Deve devolver só os registros do paciente dentro do intervalo, do mais recente para o mais antigo', () async {
        await agua('paciente_99', DateTime(2026, 10, 25, 8), 100);
        await agua('paciente_99', DateTime(2026, 10, 25, 12), 200);
        await agua('paciente_99', DateTime(2026, 10, 25, 23, 59, 59), 300);
        // Fora do intervalo (limites exatos) e de outro paciente.
        await agua('paciente_99', DateTime(2026, 10, 24, 23, 59, 59));
        await agua('paciente_99', DateTime(2026, 10, 26));
        await agua('outro_paciente', DateTime(2026, 10, 25, 9));

        final registros = await repository.registrosDoPeriodo(
          'paciente_99',
          inicio,
          fim,
          incluirDiabete: false,
        );

        expect(registros.agua.map((r) => r.quantidadeML), [300, 200, 100]);
      });

      test('Deve incluir o início do intervalo e deixar o fim de fora', () async {
        await agua('paciente_99', inicio, 100);
        await agua('paciente_99', fim, 200);

        final registros = await repository.registrosDoPeriodo(
          'paciente_99',
          inicio,
          fim,
          incluirDiabete: false,
        );

        expect(registros.agua.map((r) => r.quantidadeML), [100]);
      });

      test('Deve separar os registros por tipo e ignorar os tipos que o relatório não usa', () async {
        await agua('paciente_99', DateTime(2026, 10, 25, 8));
        await refeicao('paciente_99', 'cafe', DateTime(2026, 10, 25, 7));
        await refeicao('paciente_99', 'almoco', DateTime(2026, 10, 25, 12));
        await diabete('paciente_99', DateTime(2026, 10, 25, 7, 10), 112);
        await fakeFirestore.collection('registros_diarios').add({
          'tipo': 'tipo_futuro',
          'pacienteId': 'paciente_99',
          'dataHora': DateTime(2026, 10, 25, 6),
        });

        final registros = await repository.registrosDoPeriodo(
          'paciente_99',
          inicio,
          fim,
          incluirDiabete: true,
        );

        expect(registros.agua.length, 1);
        expect(registros.refeicoes.map((r) => r.refeicaoId), ['almoco', 'cafe']);
        expect(registros.diabete.single.nivelGlicose, 112);
        expect(registros.sono, isEmpty);
      });

      test('Deve trazer as noites de sono do paciente no intervalo', () async {
        await sono('paciente_99', DateTime(2026, 10, 25, 6, 30), 7.5);
        // Fora do intervalo e de outro paciente.
        await sono('paciente_99', DateTime(2026, 10, 24, 6, 30), 6);
        await sono('paciente_99', DateTime(2026, 10, 26, 6, 30), 9);
        await sono('outro_paciente', DateTime(2026, 10, 25, 7), 8);

        final registros = await repository.registrosDoPeriodo(
          'paciente_99',
          inicio,
          fim,
          incluirDiabete: false,
        );

        expect(registros.sono.map((r) => r.horasTotais), [7.5]);
        expect(registros.sono.single.qualidade, 4);
      });

      test('Deve trazer as doses de remédio tomadas pelo paciente no intervalo', () async {
        await dose('paciente_99', 'm1', '08:00', DateTime(2026, 10, 25, 8, 10));
        await dose('paciente_99', 'm2', '12:00', DateTime(2026, 10, 25, 12, 5));
        // Fora do intervalo e de outro paciente.
        await dose('paciente_99', 'm1', '08:00', DateTime(2026, 10, 24, 8, 10));
        await dose('paciente_99', 'm1', '08:00', DateTime(2026, 10, 26, 8, 10));
        await dose('outro_paciente', 'm1', '08:00', DateTime(2026, 10, 25, 8, 20));

        final registros = await repository.registrosDoPeriodo(
          'paciente_99',
          inicio,
          fim,
          incluirDiabete: false,
        );

        expect(registros.medicacoes.map((r) => r.medicamentoId), ['m2', 'm1']);
        expect(registros.medicacoes.first.horario, '12:00');
        expect(registros.medicacoes.first.dose, '50 mg');
      });

      test('Deve trazer os exercícios do paciente no intervalo, do mais recente para o mais antigo', () async {
        await exercicio('paciente_99', DateTime(2026, 10, 25, 7), 30);
        await exercicio('paciente_99', DateTime(2026, 10, 25, 18), 20);
        // Fora do intervalo e de outro paciente.
        await exercicio('paciente_99', DateTime(2026, 10, 24, 18), 60);
        await exercicio('paciente_99', DateTime(2026, 10, 26), 60);
        await exercicio('outro_paciente', DateTime(2026, 10, 25, 9), 60);

        final registros = await repository.registrosDoPeriodo(
          'paciente_99',
          inicio,
          fim,
          incluirDiabete: false,
        );

        expect(registros.exercicios.map((r) => r.duracaoMinutos), [20, 30]);
        expect(registros.exercicios.first.tipoExercicio, 'Caminhada');
      });

      test('Não deve buscar a glicemia de quem não tem diabetes', () async {
        await diabete('paciente_99', DateTime(2026, 10, 25, 7, 10), 112);

        final registros = await repository.registrosDoPeriodo(
          'paciente_99',
          inicio,
          fim,
          incluirDiabete: false,
        );

        expect(registros.diabete, isEmpty);
      });

      test('Deve trazer os alertas do paciente no intervalo', () async {
        await alerta('paciente_99', Alerta.tipoAtencao, DateTime(2026, 10, 25, 10));
        await alerta('paciente_99', Alerta.tipoEmergencia, DateTime(2026, 10, 25, 15));
        await alerta('paciente_99', Alerta.tipoAtencao, DateTime(2026, 10, 24, 10));
        await alerta('outro_paciente', Alerta.tipoAtencao, DateTime(2026, 10, 25, 10));

        final registros = await repository.registrosDoPeriodo(
          'paciente_99',
          inicio,
          fim,
          incluirDiabete: false,
        );

        expect(registros.alertas.map((a) => a.tipo), [
          Alerta.tipoEmergencia,
          Alerta.tipoAtencao,
        ]);
      });

      test('Deve cobrir vários dias, como no relatório do mês', () async {
        await agua('paciente_99', DateTime(2026, 10, 1, 8));
        await agua('paciente_99', DateTime(2026, 10, 15, 8));
        await agua('paciente_99', DateTime(2026, 10, 31, 20));
        await agua('paciente_99', DateTime(2026, 11, 1, 8));
        await agua('paciente_99', DateTime(2026, 9, 30, 20));

        final registros = await repository.registrosDoPeriodo(
          'paciente_99',
          DateTime(2026, 10),
          DateTime(2026, 11),
          incluirDiabete: false,
        );

        expect(registros.agua.length, 3);
      });

      test('Deve devolver listas vazias para um paciente sem registros', () async {
        final registros = await repository.registrosDoPeriodo(
          'paciente_99',
          inicio,
          fim,
          incluirDiabete: true,
        );

        expect(registros.agua, isEmpty);
        expect(registros.refeicoes, isEmpty);
        expect(registros.diabete, isEmpty);
        expect(registros.alertas, isEmpty);
      });

      test('Deve devolver os registros convertidos para o modelo certo', () async {
        await agua('paciente_99', DateTime(2026, 10, 25, 8));

        final registros = await repository.registrosDoPeriodo(
          'paciente_99',
          inicio,
          fim,
          incluirDiabete: false,
        );

        expect(registros.agua.single, isA<RegistroBase>());
        expect(registros.agua.single.pacienteId, 'paciente_99');
        expect(registros.agua.single.id, isNotEmpty);
      });
    });

    group('batimentosDoPeriodo', () {
      test('Deve devolver só os batimentos do paciente no intervalo, do mais recente para o mais antigo', () async {
        await batimento('paciente_99', 60, DateTime(2026, 10, 25, 6));
        await batimento('paciente_99', 75, DateTime(2026, 10, 25, 12));
        await batimento('paciente_99', 90, DateTime(2026, 10, 25, 18));
        await batimento('paciente_99', 70, DateTime(2026, 10, 24, 23, 59));
        await batimento('paciente_99', 80, DateTime(2026, 10, 26));
        await batimento('outro_paciente', 130, DateTime(2026, 10, 25, 12));

        final leituras =
            await repository.batimentosDoPeriodo('paciente_99', inicio, fim);

        expect(leituras.map((b) => b.bpm), [90, 75, 60]);
      });

      test('Deve devolver lista vazia quando o smartwatch não mediu nada', () async {
        final leituras =
            await repository.batimentosDoPeriodo('paciente_99', inicio, fim);

        expect(leituras, isEmpty);
      });
    });
  });
}
