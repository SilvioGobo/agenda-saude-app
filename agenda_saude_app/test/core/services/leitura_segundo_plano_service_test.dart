import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/services/health_service.dart';
import 'package:agenda_saude_app/core/services/leitura_segundo_plano_service.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/batimento_cardiaco.dart';

import 'fake_health_service.dart';

void main() {
  group('Leitura do BPM com o app fechado (teste B2) Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    late FakeHealthService healthService;
    final agora = DateTime(2026, 11, 6, 15, 0);

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
      healthService = FakeHealthService();
    });

    Future<int> importar() => importarLeiturasNovas(
          pacienteId: 'paciente_01',
          healthService: healthService,
          dadosRepository: dadosRepository,
          agora: agora,
        );

    test('Deve gravar as leituras do Health Connect que ainda não estão no Firestore', () async {
      final jaGravada = agora.subtract(const Duration(minutes: 40));
      await dadosRepository.salvarBatimento(BatimentoCardiaco(
        id: '',
        pacienteId: 'paciente_01',
        bpm: 70,
        timestamp: jaGravada,
      ));
      healthService.leituras = [
        LeituraBpm(bpm: 70, timestamp: jaGravada),
        LeituraBpm(bpm: 75, timestamp: agora.subtract(const Duration(minutes: 20))),
        LeituraBpm(bpm: 80, timestamp: agora.subtract(const Duration(minutes: 5))),
      ];

      final novas = await importar();

      expect(novas, 2);
      final gravados = await dadosRepository.getBatimentosDesde(
        'paciente_01',
        agora.subtract(const Duration(hours: 1)),
      );
      expect(gravados.map((b) => b.bpm), [80, 75, 70]);
    });

    test('Não deve gravar nada quando não há leitura nova', () async {
      healthService.leituras = [];

      expect(await importar(), 0);
      expect(
        (await fakeFirestore.collection('batimentos_cardiacos').get()).docs,
        isEmpty,
      );
    });

    test('Deve ler só a janela das últimas 12 horas', () async {
      await importar();

      final intervalo = healthService.intervalosLidos.single;
      expect(intervalo.fim, agora);
      expect(intervalo.inicio, agora.subtract(const Duration(hours: 12)));
    });

    test('Deve repassar a falha do Health Connect (ex.: sem permissão de segundo plano)', () async {
      healthService.erroAoLer = Exception('SecurityException');

      expect(importar(), throwsException);
    });
  });
}
