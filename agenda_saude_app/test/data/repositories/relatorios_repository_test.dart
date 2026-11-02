import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/data/repositories/relatorios_repository.dart';
import 'package:agenda_saude_app/domain/models/alerta.dart';
import 'package:agenda_saude_app/domain/models/batimento_cardiaco.dart';
import 'package:agenda_saude_app/domain/models/registro_agua.dart';
import 'package:agenda_saude_app/domain/models/registro_base.dart';
import 'package:agenda_saude_app/domain/models/registro_diabete.dart';
import 'package:agenda_saude_app/domain/models/registro_refeicao.dart';

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
          'tipo': 'sono',
          'pacienteId': 'paciente_99',
          'dataHora': DateTime(2026, 10, 25, 6),
          'horasTotais': 8.0,
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
