import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/registro_agua.dart';
import 'package:agenda_saude_app/domain/models/registro_base.dart';
import 'package:agenda_saude_app/domain/models/registro_diabete.dart';
import 'package:agenda_saude_app/domain/models/registro_exercicio.dart';
import 'package:agenda_saude_app/domain/models/registro_medicacao.dart';
import 'package:agenda_saude_app/domain/models/registro_refeicao.dart';
import 'package:agenda_saude_app/domain/models/registro_sono.dart';
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

    group('Refeições do dia (RF03.4)', () {
      final hoje = DateTime(2026, 10, 25, 15, 0);

      Future<void> marcar(String pacienteId, String refeicaoId, DateTime quando) {
        return repository.salvarRegistro(RegistroRefeicao(
          id: '',
          pacienteId: pacienteId,
          dataHora: quando,
          refeicaoId: refeicaoId,
          nome: refeicaoId,
        ));
      }

      test('Deve devolver só as refeições marcadas hoje, da mais recente para a mais antiga', () async {
        await marcar('paciente_99', 'cafe', DateTime(2026, 10, 25, 7, 0));
        await marcar('paciente_99', 'almoco', DateTime(2026, 10, 25, 12, 0));
        await marcar('paciente_99', 'jantar', DateTime(2026, 10, 24, 20, 0));
        await marcar('outro_paciente', 'cafe', DateTime(2026, 10, 25, 7, 30));

        final registros =
            await repository.streamRefeicoesDoDia('paciente_99', hoje).first;

        expect(registros.map((r) => r.refeicaoId), ['almoco', 'cafe']);
      });

      test('Deve ignorar registros que não são de refeição', () async {
        await marcar('paciente_99', 'cafe', DateTime(2026, 10, 25, 7, 0));
        await repository.salvarRegistro(RegistroAgua(
          id: '',
          pacienteId: 'paciente_99',
          dataHora: DateTime(2026, 10, 25, 8, 0),
          quantidadeML: 250,
        ));

        final registros =
            await repository.streamRefeicoesDoDia('paciente_99', hoje).first;

        expect(registros.length, 1);
        expect(registros.single.nome, 'cafe');
      });

      test('Deve emitir a lista atualizada quando uma refeição é marcada', () async {
        final emissoes = <int>[];
        final assinatura = repository
            .streamRefeicoesDoDia('paciente_99', hoje)
            .listen((registros) => emissoes.add(registros.length));

        await Future<void>.delayed(Duration.zero);
        await marcar('paciente_99', 'cafe', DateTime(2026, 10, 25, 7, 0));
        await Future<void>.delayed(Duration.zero);
        await assinatura.cancel();

        expect(emissoes, [0, 1]);
      });
    });

    group('Sono (RF03.2)', () {
      final hoje = DateTime(2026, 10, 25, 15, 0);

      // Como o app grava: ao acordar, inicio e fim valem o instante do registro.
      Future<void> registrarSono(
        String pacienteId,
        DateTime quando, {
        double horas = 7.5,
        int qualidade = 4,
      }) {
        return repository.salvarRegistro(RegistroSono(
          id: '',
          pacienteId: pacienteId,
          dataHora: quando,
          dataFim: quando,
          horasTotais: horas,
          qualidade: qualidade,
        ));
      }

      test('Deve devolver só o sono do dia, da noite mais recente para a mais antiga', () async {
        await registrarSono('paciente_99', DateTime(2026, 10, 25, 6, 30), horas: 6);
        await registrarSono('paciente_99', DateTime(2026, 10, 25, 9, 0), horas: 8);
        // Fora do dia e de outro paciente.
        await registrarSono('paciente_99', DateTime(2026, 10, 24, 6, 30));
        await registrarSono('paciente_99', DateTime(2026, 10, 26, 0, 0));
        await registrarSono('outro_paciente', DateTime(2026, 10, 25, 7, 0));

        final registros =
            await repository.streamSonoDoDia('paciente_99', hoje).first;

        expect(registros.map((r) => r.horasTotais), [8, 6]);
      });

      test('Deve ignorar registros do dia que não são de sono', () async {
        await registrarSono('paciente_99', DateTime(2026, 10, 25, 7, 0));
        await repository.salvarRegistro(RegistroAgua(
          id: '',
          pacienteId: 'paciente_99',
          dataHora: DateTime(2026, 10, 25, 8, 0),
          quantidadeML: 250,
        ));

        final registros =
            await repository.streamSonoDoDia('paciente_99', hoje).first;

        expect(registros.length, 1);
        expect(registros.single.qualidade, 4);
      });

      test('Deve emitir a lista atualizada quando o sono é registrado', () async {
        final emissoes = <int>[];
        final assinatura = repository
            .streamSonoDoDia('paciente_99', hoje)
            .listen((registros) => emissoes.add(registros.length));

        await Future<void>.delayed(Duration.zero);
        await registrarSono('paciente_99', DateTime(2026, 10, 25, 7, 0));
        await Future<void>.delayed(Duration.zero);
        await assinatura.cancel();

        expect(emissoes, [0, 1]);
      });

      test('Deve trocar o conteúdo de um registro sem criar outro', () async {
        await registrarSono('paciente_99', DateTime(2026, 10, 25, 7, 0));
        final antes =
            (await repository.streamSonoDoDia('paciente_99', hoje).first).single;

        await repository.atualizarRegistro(
          antes.id,
          RegistroSono(
            id: antes.id,
            pacienteId: 'paciente_99',
            dataHora: DateTime(2026, 10, 25, 8, 0),
            dataFim: DateTime(2026, 10, 25, 8, 0),
            horasTotais: 9,
            qualidade: 2,
          ),
        );

        final depois =
            (await repository.streamSonoDoDia('paciente_99', hoje).first).single;
        expect(depois.id, antes.id);
        expect(depois.horasTotais, 9);
        expect(depois.qualidade, 2);
        expect(
          (await fakeFirestore.collection('registros_diarios').get()).docs,
          hasLength(1),
        );
      });
    });

    group('Medicação (RF003)', () {
      final hoje = DateTime(2026, 10, 25, 15, 0);

      Future<void> marcar(
        String pacienteId,
        String medicamentoId,
        String horario,
        DateTime quando,
      ) {
        return repository.salvarRegistro(RegistroMedicacao(
          id: '',
          pacienteId: pacienteId,
          dataHora: quando,
          medicamentoId: medicamentoId,
          horario: horario,
          nome: medicamentoId,
          dose: '50 mg',
        ));
      }

      test('Deve devolver só as doses tomadas hoje, da mais recente para a mais antiga', () async {
        await marcar('paciente_99', 'losartana', '08:00', DateTime(2026, 10, 25, 8, 10));
        await marcar('paciente_99', 'metformina', '12:00', DateTime(2026, 10, 25, 12, 5));
        // Fora do dia e de outro paciente.
        await marcar('paciente_99', 'losartana', '08:00', DateTime(2026, 10, 24, 8, 0));
        await marcar('paciente_99', 'losartana', '08:00', DateTime(2026, 10, 26, 8, 0));
        await marcar('outro_paciente', 'losartana', '08:00', DateTime(2026, 10, 25, 8, 30));

        final registros =
            await repository.streamMedicacoesDoDia('paciente_99', hoje).first;

        expect(registros.map((r) => r.medicamentoId), ['metformina', 'losartana']);
        expect(registros.first.horario, '12:00');
        expect(registros.first.dose, '50 mg');
      });

      test('Deve ignorar registros do dia que não são de remédio', () async {
        await marcar('paciente_99', 'losartana', '08:00', DateTime(2026, 10, 25, 8, 10));
        await repository.salvarRegistro(RegistroAgua(
          id: '',
          pacienteId: 'paciente_99',
          dataHora: DateTime(2026, 10, 25, 9, 0),
          quantidadeML: 250,
        ));

        final registros =
            await repository.streamMedicacoesDoDia('paciente_99', hoje).first;

        expect(registros.length, 1);
      });

      test('Deve emitir a lista atualizada quando uma dose é marcada ou desmarcada', () async {
        final emissoes = <int>[];
        final assinatura = repository
            .streamMedicacoesDoDia('paciente_99', hoje)
            .listen((registros) => emissoes.add(registros.length));

        await Future<void>.delayed(Duration.zero);
        await marcar('paciente_99', 'losartana', '08:00', DateTime(2026, 10, 25, 8, 10));
        await Future<void>.delayed(Duration.zero);
        final tomada =
            (await repository.streamMedicacoesDoDia('paciente_99', hoje).first).single;
        await repository.removerRegistro(tomada.id);
        await Future<void>.delayed(Duration.zero);
        await assinatura.cancel();

        expect(emissoes, [0, 1, 0]);
      });
    });

    group('Exercício (RF03.3)', () {
      // Quarta-feira, 28/10/2026: a semana (domingo a sabado) vai de 25/10 ate
      // 31/10, e 1/11 ja e a semana seguinte.
      final quarta = DateTime(2026, 10, 28, 15, 0);

      Future<void> registrarExercicio(
        String pacienteId,
        DateTime quando, {
        int minutos = 30,
      }) {
        return repository.salvarRegistro(RegistroExercicio(
          id: '',
          pacienteId: pacienteId,
          dataHora: quando,
          tipoExercicio: 'Caminhada',
          duracaoMinutos: minutos,
          intensidade: 'Leve',
        ));
      }

      test('Deve devolver só os exercícios da semana, do mais recente para o mais antigo', () async {
        await registrarExercicio('paciente_99', DateTime(2026, 10, 25, 8, 0), minutos: 10);
        await registrarExercicio('paciente_99', DateTime(2026, 10, 28, 7, 0), minutos: 20);
        await registrarExercicio('paciente_99', DateTime(2026, 10, 31, 23, 59, 59), minutos: 30);
        // Fora da semana (limites exatos) e de outro paciente.
        await registrarExercicio('paciente_99', DateTime(2026, 10, 24, 23, 59, 59));
        await registrarExercicio('paciente_99', DateTime(2026, 11, 1, 0, 0));
        await registrarExercicio('outro_paciente', DateTime(2026, 10, 28, 9, 0));

        final registros =
            await repository.streamExerciciosDaSemana('paciente_99', quarta).first;

        expect(registros.map((r) => r.duracaoMinutos), [30, 20, 10]);
      });

      test('Deve dar a mesma semana para qualquer dia dela, do domingo ao sábado', () async {
        await registrarExercicio('paciente_99', DateTime(2026, 10, 28, 7, 0), minutos: 20);

        for (final dia in [
          DateTime(2026, 10, 25),
          DateTime(2026, 10, 28, 23, 59),
          DateTime(2026, 10, 31, 12, 0),
        ]) {
          final registros =
              await repository.streamExerciciosDaSemana('paciente_99', dia).first;
          expect(registros.map((r) => r.duracaoMinutos), [20], reason: '$dia');
        }
        // O domingo seguinte ja e outra semana.
        final proxima = await repository
            .streamExerciciosDaSemana('paciente_99', DateTime(2026, 11, 1))
            .first;
        expect(proxima, isEmpty);
      });

      test('Deve ignorar registros da semana que não são de exercício', () async {
        await registrarExercicio('paciente_99', DateTime(2026, 10, 28, 7, 0));
        await repository.salvarRegistro(RegistroAgua(
          id: '',
          pacienteId: 'paciente_99',
          dataHora: DateTime(2026, 10, 28, 8, 0),
          quantidadeML: 250,
        ));

        final registros =
            await repository.streamExerciciosDaSemana('paciente_99', quarta).first;

        expect(registros.length, 1);
        expect(registros.single.tipoExercicio, 'Caminhada');
      });

      test('Deve emitir a lista atualizada quando um exercício é registrado ou apagado', () async {
        final emissoes = <int>[];
        final assinatura = repository
            .streamExerciciosDaSemana('paciente_99', quarta)
            .listen((registros) => emissoes.add(registros.length));

        await Future<void>.delayed(Duration.zero);
        await registrarExercicio('paciente_99', DateTime(2026, 10, 28, 9, 0));
        await Future<void>.delayed(Duration.zero);
        final registrado =
            (await repository.streamExerciciosDaSemana('paciente_99', quarta).first)
                .single;
        await repository.removerRegistro(registrado.id);
        await Future<void>.delayed(Duration.zero);
        await assinatura.cancel();

        expect(emissoes, [0, 1, 0]);
      });
    });

    group('Última atividade da rotina (Figura 15)', () {
      test('Deve emitir null quando o paciente ainda não registrou nada', () async {
        final atividade =
            await repository.streamUltimaAtividade('paciente_99').first;

        expect(atividade, isNull);
      });

      test('Deve devolver o registro mais recente do paciente, de qualquer tipo', () async {
        await repository.salvarRegistro(RegistroAgua(
          id: '',
          pacienteId: 'paciente_99',
          dataHora: DateTime(2026, 11, 6, 8, 0),
          quantidadeML: 250,
        ));
        await repository.salvarRegistro(RegistroDiabete(
          id: '',
          pacienteId: 'paciente_99',
          dataHora: DateTime(2026, 11, 6, 11, 30),
          nivelGlicose: 112,
          momento: 'Antes do almoço',
        ));
        await repository.salvarRegistro(RegistroRefeicao(
          id: '',
          pacienteId: 'paciente_99',
          dataHora: DateTime(2026, 11, 6, 10, 0),
          refeicaoId: 'lanche',
          nome: 'Lanche da manhã',
        ));
        // Mais recente, mas de outro paciente.
        await repository.salvarRegistro(RegistroAgua(
          id: '',
          pacienteId: 'outro_paciente',
          dataHora: DateTime(2026, 11, 6, 12, 0),
          quantidadeML: 500,
        ));

        final atividade =
            await repository.streamUltimaAtividade('paciente_99').first;

        expect(atividade, isA<RegistroDiabete>());
        expect((atividade as RegistroDiabete).nivelGlicose, 112);
        expect(atividade.dataHora, DateTime(2026, 11, 6, 11, 30));
      });

      test('Deve montar sono e exercício pelo campo "tipo"', () async {
        await repository.salvarRegistro(RegistroSono(
          id: '',
          pacienteId: 'paciente_99',
          dataHora: DateTime(2026, 11, 5, 22, 0),
          dataFim: DateTime(2026, 11, 6, 6, 0),
          horasTotais: 8,
          qualidade: 4,
        ));
        expect(
          await repository.streamUltimaAtividade('paciente_99').first,
          isA<RegistroSono>(),
        );

        await repository.salvarRegistro(RegistroExercicio(
          id: '',
          pacienteId: 'paciente_99',
          dataHora: DateTime(2026, 11, 6, 7, 0),
          tipoExercicio: 'Caminhada',
          duracaoMinutos: 30,
          intensidade: 'Leve',
        ));
        expect(
          await repository.streamUltimaAtividade('paciente_99').first,
          isA<RegistroExercicio>(),
        );
      });

      test('Deve montar a medicação pelo campo "tipo"', () async {
        await repository.salvarRegistro(RegistroMedicacao(
          id: '',
          pacienteId: 'paciente_99',
          dataHora: DateTime(2026, 11, 6, 8, 10),
          medicamentoId: 'm1',
          horario: '08:00',
          nome: 'Losartana',
          dose: '50 mg',
        ));

        final atividade =
            await repository.streamUltimaAtividade('paciente_99').first;

        expect(atividade, isA<RegistroMedicacao>());
        expect((atividade as RegistroMedicacao).descricao, 'Losartana 50 mg');
      });

      test('Deve emitir null para um tipo de registro que o app não conhece', () async {
        await fakeFirestore.collection('registros_diarios').add({
          'tipo': 'tipo_futuro',
          'pacienteId': 'paciente_99',
          'dataHora': DateTime(2026, 11, 6, 9, 0),
        });

        final atividade =
            await repository.streamUltimaAtividade('paciente_99').first;

        expect(atividade, isNull);
      });

      test('Deve emitir a atividade nova assim que o paciente registra', () async {
        final emissoes = <RegistroBase?>[];
        final assinatura = repository
            .streamUltimaAtividade('paciente_99')
            .listen(emissoes.add);

        await Future<void>.delayed(Duration.zero);
        await repository.salvarRegistro(RegistroAgua(
          id: '',
          pacienteId: 'paciente_99',
          dataHora: DateTime(2026, 11, 6, 9, 0),
          quantidadeML: 250,
        ));
        await Future<void>.delayed(Duration.zero);
        await assinatura.cancel();

        expect(emissoes.first, isNull);
        expect(emissoes.last, isA<RegistroAgua>());
      });
    });
  });
}
