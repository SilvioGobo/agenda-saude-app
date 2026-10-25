import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/registro_agua.dart';
import 'package:agenda_saude_app/domain/models/registro_diabete.dart';
import 'package:agenda_saude_app/domain/models/batimento_cardiaco.dart';
import 'package:agenda_saude_app/domain/models/alerta.dart';

void main() {
  group('DadosMedicosRepository Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository repository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = DadosMedicosRepository(firestore: fakeFirestore);
    });

    test('Deve guardar um Registo Diário (Água) na coleção correta', () async {
      final registroAgua = RegistroAgua(
        id: '', // O ID será gerado pelo Firebase
        pacienteId: 'paciente_99',
        dataHora: DateTime.now(),
        quantidadeML: 250,
      );

      await repository.salvarRegistro(registroAgua);

      // Verifica se o documento foi realmente criado na coleção 'registros_diarios'
      final snapshot = await fakeFirestore.collection('registros_diarios').get();
      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first.data()['quantidadeML'], 250);
      expect(snapshot.docs.first.data()['tipo'], 'agua');
    });

    test('Deve guardar um Batimento Cardíaco na coleção específica', () async {
      final batimento = BatimentoCardiaco(
        id: '',
        pacienteId: 'paciente_99',
        bpm: 85,
        timestamp: DateTime.now(),
      );

      await repository.salvarBatimento(batimento);

      final snapshot = await fakeFirestore.collection('batimentos_cardiacos').get();
      expect(snapshot.docs.length, 1);
      expect(snapshot.docs.first.data()['bpm'], 85);
    });

    test('Deve gerar e recuperar Alertas de um paciente', () async {
      final alerta = Alerta(
        id: '',
        pacienteId: 'paciente_99',
        tipo: Alerta.tipoEmergencia,
        mensagem: 'Frequência cardíaca elevada detetada!',
        dataHora: DateTime.now(),
        lido: false,
      );

      // Ação: Guardar alerta
      await repository.gerarAlerta(alerta);

      // Ação: Buscar os alertas do paciente
      final alertasRecuperados = await repository.getAlertas('paciente_99');

      // Verificação
      expect(alertasRecuperados.length, 1);
      expect(alertasRecuperados.first.mensagem, 'Frequência cardíaca elevada detetada!');
      expect(alertasRecuperados.first.lido, false);
    });

    test('Deve transmitir em tempo real os alertas do paciente, do mais novo para o mais antigo', () async {
      final base = DateTime(2026, 9, 19, 10, 0);
      Future<void> gerar(String paciente, String mensagem, Duration depois) =>
          repository.gerarAlerta(Alerta(
            id: '',
            pacienteId: paciente,
            tipo: Alerta.tipoAtencao,
            mensagem: mensagem,
            dataHora: base.add(depois),
          ));
      await gerar('paciente_99', 'primeiro', Duration.zero);
      await gerar('outro_paciente', 'de outro paciente', const Duration(minutes: 5));

      final leituras = <List<String>>[];
      final assinatura = repository.streamAlertas('paciente_99').listen(
            (leitura) => leituras.add(leitura.alertas.map((a) => a.mensagem).toList()),
          );
      await Future<void>.delayed(Duration.zero);
      await gerar('paciente_99', 'segundo', const Duration(minutes: 10));
      await Future<void>.delayed(Duration.zero);
      await assinatura.cancel();

      expect(leituras.first, ['primeiro']);
      expect(leituras.last, ['segundo', 'primeiro']);
    });

    test('Deve limitar a quantidade de alertas transmitidos', () async {
      final base = DateTime(2026, 9, 19, 10, 0);
      for (var i = 0; i < 3; i++) {
        await repository.gerarAlerta(Alerta(
          id: '',
          pacienteId: 'paciente_99',
          tipo: Alerta.tipoAtencao,
          mensagem: 'alerta $i',
          dataHora: base.add(Duration(minutes: i)),
        ));
      }

      final leitura = await repository.streamAlertas('paciente_99', limite: 2).first;

      expect(leitura.alertas.map((a) => a.mensagem), ['alerta 2', 'alerta 1']);
      expect(leitura.doServidor, true);
    });

    test('Deve marcar alertas como lidos', () async {
      for (final mensagem in ['um', 'dois']) {
        await repository.gerarAlerta(Alerta(
          id: '',
          pacienteId: 'paciente_99',
          tipo: Alerta.tipoAtencao,
          mensagem: mensagem,
          dataHora: DateTime.now(),
        ));
      }
      final alertas = await repository.getAlertas('paciente_99');

      await repository.marcarAlertasComoLidos(alertas.map((a) => a.id).toList());

      final atualizados = await repository.getAlertas('paciente_99');
      expect(atualizados.every((a) => a.lido), true);
    });

    test('Deve retornar null quando o paciente ainda não tem batimentos', () async {
      expect(await repository.getUltimoBatimento('paciente_99'), isNull);
    });

    test('Deve buscar o batimento mais recente do paciente', () async {
      final base = DateTime(2026, 9, 19, 10, 0);
      await repository.salvarBatimento(BatimentoCardiaco(
        id: '', pacienteId: 'paciente_99', bpm: 70, timestamp: base,
      ));
      await repository.salvarBatimento(BatimentoCardiaco(
        id: '', pacienteId: 'paciente_99', bpm: 88,
        timestamp: base.add(const Duration(minutes: 10)),
      ));
      await repository.salvarBatimento(BatimentoCardiaco(
        id: '', pacienteId: 'outro_paciente', bpm: 130,
        timestamp: base.add(const Duration(hours: 1)),
      ));

      final ultimo = await repository.getUltimoBatimento('paciente_99');

      expect(ultimo?.bpm, 88);
      expect(ultimo?.timestamp, base.add(const Duration(minutes: 10)));
    });

    test('Deve buscar só os batimentos do paciente a partir de uma data', () async {
      final base = DateTime(2026, 9, 19, 10, 0);
      Future<void> salvar(String paciente, int bpm, Duration depois) =>
          repository.salvarBatimento(BatimentoCardiaco(
            id: '', pacienteId: paciente, bpm: bpm, timestamp: base.add(depois),
          ));
      await salvar('paciente_99', 60, Duration.zero);
      await salvar('paciente_99', 70, const Duration(minutes: 10));
      await salvar('paciente_99', 80, const Duration(minutes: 20));
      await salvar('outro_paciente', 130, const Duration(minutes: 15));

      final recentes = await repository.getBatimentosDesde(
        'paciente_99',
        base.add(const Duration(minutes: 10)),
      );

      expect(recentes.map((b) => b.bpm).toList()..sort(), [70, 80]);
    });

    test('Deve salvar um lote de batimentos de uma vez', () async {
      final base = DateTime(2026, 9, 19, 10, 0);
      final lote = List.generate(
        3,
        (i) => BatimentoCardiaco(
          id: '',
          pacienteId: 'paciente_99',
          bpm: 70 + i,
          timestamp: base.add(Duration(minutes: i)),
        ),
      );

      await repository.salvarBatimentos(lote);

      final snapshot = await fakeFirestore
          .collection('batimentos_cardiacos')
          .orderBy('timestamp')
          .get();
      expect(snapshot.docs.map((d) => d.data()['bpm']), [70, 71, 72]);
    });

    test('Deve dividir lotes maiores que 500 batimentos', () async {
      final base = DateTime(2026, 9, 19, 10, 0);
      final lote = List.generate(
        501,
        (i) => BatimentoCardiaco(
          id: '',
          pacienteId: 'paciente_99',
          bpm: 70,
          timestamp: base.add(Duration(seconds: i)),
        ),
      );

      await repository.salvarBatimentos(lote);

      final snapshot = await fakeFirestore.collection('batimentos_cardiacos').get();
      expect(snapshot.docs.length, 501);
    });

    group('Hidratação', () {
      final hoje = DateTime(2026, 10, 25, 15, 0);

      Future<void> salvarAgua(
        String pacienteId,
        DateTime dataHora, {
        int ml = 250,
      }) {
        return repository.salvarRegistro(RegistroAgua(
          id: '',
          pacienteId: pacienteId,
          dataHora: dataHora,
          quantidadeML: ml,
        ));
      }

      test('Deve listar só a água do paciente no dia pedido, da mais recente para a mais antiga', () async {
        await salvarAgua('paciente_99', DateTime(2026, 10, 25, 8, 0), ml: 100);
        await salvarAgua('paciente_99', DateTime(2026, 10, 25, 12, 0), ml: 200);
        await salvarAgua('paciente_99', DateTime(2026, 10, 25, 23, 59, 59), ml: 300);
        // Fora do dia (limites exatos) e de outro paciente.
        await salvarAgua('paciente_99', DateTime(2026, 10, 24, 23, 59, 59));
        await salvarAgua('paciente_99', DateTime(2026, 10, 26, 0, 0));
        await salvarAgua('outro_paciente', DateTime(2026, 10, 25, 9, 0));

        final registros =
            await repository.streamAguaDoDia('paciente_99', hoje).first;

        expect(registros.map((r) => r.quantidadeML), [300, 200, 100]);
      });

      test('Deve ignorar registros do dia que não são de água', () async {
        await salvarAgua('paciente_99', DateTime(2026, 10, 25, 8, 0));
        await fakeFirestore.collection('registros_diarios').add({
          'tipo': 'sono',
          'pacienteId': 'paciente_99',
          'dataHora': DateTime(2026, 10, 25, 7, 0),
          'horasTotais': 8.0,
        });

        final registros =
            await repository.streamAguaDoDia('paciente_99', hoje).first;

        expect(registros.length, 1);
        expect(registros.first.quantidadeML, 250);
      });

      test('Deve emitir a lista atualizada quando um copo é registrado', () async {
        final emissoes = <int>[];
        final assinatura = repository
            .streamAguaDoDia('paciente_99', hoje)
            .listen((registros) => emissoes.add(registros.length));

        await Future<void>.delayed(Duration.zero);
        await salvarAgua('paciente_99', DateTime(2026, 10, 25, 9, 0));
        await Future<void>.delayed(Duration.zero);
        await assinatura.cancel();

        expect(emissoes, [0, 1]);
      });

      test('Deve remover um registro pelo id', () async {
        await salvarAgua('paciente_99', DateTime(2026, 10, 25, 9, 0));
        await salvarAgua('paciente_99', DateTime(2026, 10, 25, 10, 0));
        final antes =
            await repository.streamAguaDoDia('paciente_99', hoje).first;

        await repository.removerRegistro(antes.first.id);

        final depois =
            await repository.streamAguaDoDia('paciente_99', hoje).first;
        expect(depois.length, 1);
        expect(depois.first.id, antes.last.id);
      });
    });

    group('Glicemia e insulina', () {
      final hoje = DateTime(2026, 10, 25, 15, 0);

      Future<void> salvarDiabete(
        String pacienteId,
        DateTime dataHora, {
        double? glicose = 110,
        double? dose,
        String momento = 'Ao acordar',
      }) {
        return repository.salvarRegistro(RegistroDiabete(
          id: '',
          pacienteId: pacienteId,
          dataHora: dataHora,
          nivelGlicose: glicose,
          momento: momento,
          doseInsulina: dose,
          tipoInsulina: dose == null ? null : 'Rápida',
        ));
      }

      test('Deve gravar o registro de diabetes com o tipo "diabete"', () async {
        await salvarDiabete('paciente_99', DateTime(2026, 10, 25, 7, 0), dose: 6);

        final snapshot =
            await fakeFirestore.collection('registros_diarios').get();
        expect(snapshot.docs.single.data()['tipo'], 'diabete');
        expect(snapshot.docs.single.data()['doseInsulina'], 6);
      });

      test('Deve listar só os registros de diabetes do paciente no dia pedido', () async {
        await salvarDiabete('paciente_99', DateTime(2026, 10, 25, 7, 0), glicose: 100);
        await salvarDiabete('paciente_99', DateTime(2026, 10, 25, 11, 30), glicose: 150);
        // Outro dia, outro paciente e outro tipo de registro.
        await salvarDiabete('paciente_99', DateTime(2026, 10, 24, 22, 0));
        await salvarDiabete('paciente_99', DateTime(2026, 10, 26, 0, 0));
        await salvarDiabete('outro_paciente', DateTime(2026, 10, 25, 8, 0));
        await repository.salvarRegistro(RegistroAgua(
          id: '',
          pacienteId: 'paciente_99',
          dataHora: DateTime(2026, 10, 25, 9, 0),
          quantidadeML: 250,
        ));

        final registros =
            await repository.streamDiabeteDoDia('paciente_99', hoje).first;

        expect(registros.map((r) => r.nivelGlicose), [150, 100]);
      });

      test('Deve transmitir os últimos registros de diabetes, do mais novo para o mais antigo e com limite', () async {
        for (var hora = 6; hora < 12; hora++) {
          await salvarDiabete(
            'paciente_99',
            DateTime(2026, 10, 24, hora, 0),
            glicose: hora * 10,
          );
        }
        await salvarDiabete('outro_paciente', DateTime(2026, 10, 25, 8, 0));

        final registros = await repository
            .streamUltimosRegistrosDiabete('paciente_99', limite: 3)
            .first;

        expect(registros.map((r) => r.nivelGlicose), [110, 100, 90]);
      });
    });
  });
}