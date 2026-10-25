import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/localizacao_repository.dart';
import 'package:agenda_saude_app/domain/models/localizacao.dart';

void main() {
  group('LocalizacaoRepository Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late LocalizacaoRepository repository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = LocalizacaoRepository(firestore: fakeFirestore);
    });

    Localizacao posicao({double latitude = -22.2210, int minuto = 0}) {
      return Localizacao(
        pacienteId: 'paciente_01',
        ativo: true,
        latitude: latitude,
        longitude: -54.8056,
        precisaoMetros: 12,
        dataHora: DateTime(2026, 10, 25, 14, minuto),
      );
    }

    test('Deve salvar e buscar a localização do paciente', () async {
      await repository.salvarLocalizacao(posicao());

      final resultado = await repository.getLocalizacao('paciente_01');

      expect(resultado, isNotNull);
      expect(resultado!.ativo, true);
      expect(resultado.latitude, -22.2210);
      expect(resultado.dataHora, DateTime(2026, 10, 25, 14, 0));
    });

    test('Deve retornar null para paciente que nunca compartilhou', () async {
      expect(await repository.getLocalizacao('paciente_01'), isNull);
    });

    test('Deve guardar só a última posição, sem histórico', () async {
      await repository.salvarLocalizacao(posicao(latitude: -22.1, minuto: 0));
      await repository.salvarLocalizacao(posicao(latitude: -22.3, minuto: 1));

      final docs = await fakeFirestore.collection('localizacoes').get();
      expect(docs.docs, hasLength(1));
      expect(docs.docs.single.id, 'paciente_01');
      expect(docs.docs.single.data()['latitude'], -22.3);
    });

    test('Deve ligar o compartilhamento sem posição', () async {
      await repository.ativarCompartilhamento('paciente_01');

      final resultado = await repository.getLocalizacao('paciente_01');
      expect(resultado!.ativo, true);
      expect(resultado.temPosicao, false);
    });

    test('Deve apagar a posição ao desligar o compartilhamento', () async {
      await repository.salvarLocalizacao(posicao());

      await repository.desativarCompartilhamento('paciente_01');

      final doc =
          await fakeFirestore.collection('localizacoes').doc('paciente_01').get();
      expect(doc.data()!['ativo'], false);
      expect(doc.data()!['latitude'], isNull);
      expect(doc.data()!['longitude'], isNull);
      expect(doc.data()!['dataHora'], isNull);
    });

    test('Deve emitir a localização em tempo real', () async {
      final emitidas = <Localizacao?>[];
      final assinatura =
          repository.streamLocalizacao('paciente_01').listen(emitidas.add);

      await pumpEventQueue();
      await repository.salvarLocalizacao(posicao());
      await pumpEventQueue();
      await repository.desativarCompartilhamento('paciente_01');
      await pumpEventQueue();
      await assinatura.cancel();

      expect(emitidas, hasLength(3));
      expect(emitidas[0], isNull);
      expect(emitidas[1]!.temPosicao, true);
      expect(emitidas[2]!.ativo, false);
    });
  });
}
