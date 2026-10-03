import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/registro_agua.dart';
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
  });
}