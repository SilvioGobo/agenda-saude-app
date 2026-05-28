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
  });
}