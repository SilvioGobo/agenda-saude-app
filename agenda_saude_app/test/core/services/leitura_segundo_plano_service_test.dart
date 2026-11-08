import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/services/health_service.dart';
import 'package:agenda_saude_app/core/services/leitura_segundo_plano_service.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/alerta.dart';
import 'package:agenda_saude_app/domain/models/batimento_cardiaco.dart';
import 'package:agenda_saude_app/domain/models/limites_alerta.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';

import 'fake_health_service.dart';

void main() {
  group('Leitura do BPM com o app fechado (B7) Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    late FakeHealthService healthService;
    final agora = DateTime(2026, 11, 6, 15, 0);

    Paciente paciente({bool possuiCardiopatia = false}) => Paciente(
          id: 'paciente_01',
          nome: 'José Silva',
          email: 'jose@email.com',
          perfil: 'Paciente',
          possuiDiabetes: false,
          possuiCardiopatia: possuiCardiopatia,
          codigoVinculo: 'ABC123',
        );

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
      healthService = FakeHealthService();
    });

    Future<({int leiturasNovas, int alertas})> sincronizar({
      bool possuiCardiopatia = false,
    }) =>
        sincronizarComAppFechado(
          paciente: paciente(possuiCardiopatia: possuiCardiopatia),
          healthService: healthService,
          dadosRepository: dadosRepository,
          agora: agora,
        );

    DateTime haMinutos(int minutos) => agora.subtract(Duration(minutes: minutos));

    Future<void> gravarLeitura(int bpm, int minutosAtras) {
      return dadosRepository.salvarBatimento(BatimentoCardiaco(
        id: '',
        pacienteId: 'paciente_01',
        bpm: bpm,
        timestamp: haMinutos(minutosAtras),
      ));
    }

    Future<List<Alerta>> alertasGravados() =>
        dadosRepository.getAlertas('paciente_01');

    test('Deve gravar as leituras do Health Connect que ainda não estão no Firestore', () async {
      await gravarLeitura(70, 40);
      healthService.leituras = [
        LeituraBpm(bpm: 70, timestamp: haMinutos(40)),
        LeituraBpm(bpm: 75, timestamp: haMinutos(20)),
        LeituraBpm(bpm: 80, timestamp: haMinutos(5)),
      ];

      final resultado = await sincronizar();

      expect(resultado.leiturasNovas, 2);
      expect(resultado.alertas, 0);
      final gravados = await dadosRepository.getBatimentosDesde(
        'paciente_01',
        agora.subtract(const Duration(hours: 1)),
      );
      expect(gravados.map((b) => b.bpm), [80, 75, 70]);
    });

    test('Não deve gravar nada quando não há leitura nova', () async {
      healthService.leituras = [];

      final resultado = await sincronizar();

      expect(resultado.leiturasNovas, 0);
      expect(
        (await fakeFirestore.collection('batimentos_cardiacos').get()).docs,
        isEmpty,
      );
    });

    test('Deve ler só a janela das últimas 12 horas', () async {
      await sincronizar();

      final intervalo = healthService.intervalosLidos.single;
      expect(intervalo.fim, agora);
      expect(intervalo.inicio, agora.subtract(const Duration(hours: 12)));
    });

    test('Deve repassar a falha do Health Connect (ex.: sem permissão de segundo plano)', () async {
      healthService.erroAoLer = Exception('SecurityException');

      expect(sincronizar(), throwsException);
    });

    test('Deve gerar a emergência com o BPM fora da zona por 5 minutos com o app fechado', () async {
      healthService.leituras = [
        LeituraBpm(bpm: 120, timestamp: haMinutos(14)),
        LeituraBpm(bpm: 124, timestamp: haMinutos(8)),
        LeituraBpm(bpm: 126, timestamp: haMinutos(2)),
      ];

      final resultado = await sincronizar();

      expect(resultado.alertas, 1);
      final alerta = (await alertasGravados()).single;
      expect(alerta.tipo, Alerta.tipoEmergencia);
      expect(alerta.bpm, 124);
      expect(alerta.pacienteId, 'paciente_01');
      expect(alerta.lido, false);
    });

    test('Deve avisar "Atenção" quando a leitura mais nova sai da zona', () async {
      await gravarLeitura(72, 20);
      healthService.leituras = [
        LeituraBpm(bpm: 72, timestamp: haMinutos(20)),
        LeituraBpm(bpm: 118, timestamp: haMinutos(3)),
      ];

      await sincronizar();

      final alerta = (await alertasGravados()).single;
      expect(alerta.tipo, Alerta.tipoAtencao);
      expect(alerta.mensagem, 'Batimentos acima da zona de segurança (118 BPM).');
    });

    test('Deve usar a zona mais estreita do cardiopata', () async {
      healthService.leituras = [
        LeituraBpm(bpm: 95, timestamp: haMinutos(7)),
        LeituraBpm(bpm: 96, timestamp: haMinutos(1)),
      ];

      expect((await sincronizar(possuiCardiopatia: true)).alertas, 1);
    });

    test('Deve usar os limites que o acompanhante definiu (RF 06.1)', () async {
      healthService.leituras = [
        LeituraBpm(bpm: 95, timestamp: haMinutos(7)),
        LeituraBpm(bpm: 96, timestamp: haMinutos(1)),
      ];
      // 95 BPM e normal na zona padrao, mas acima do maximo de 90 do paciente.
      final resultado = await sincronizarComAppFechado(
        paciente: paciente().copyWith(
          limitesAlerta: const LimitesAlerta(bpmMinimo: 50, bpmMaximo: 90),
        ),
        healthService: healthService,
        dadosRepository: dadosRepository,
        agora: agora,
      );

      expect(resultado.alertas, 1);
      expect((await alertasGravados()).single.tipo, Alerta.tipoEmergencia);
    });

    test('Não deve repetir a emergência que a execução anterior já gerou', () async {
      // Execucao de 15 min atras: episodio fora da zona e emergencia gravados.
      await gravarLeitura(120, 30);
      await gravarLeitura(125, 20);
      await dadosRepository.gerarAlerta(Alerta(
        id: '',
        pacienteId: 'paciente_01',
        tipo: Alerta.tipoEmergencia,
        mensagem: 'Batimentos fora da zona de segurança há 10 minutos.',
        bpm: 125,
        dataHora: haMinutos(20),
      ));
      healthService.leituras = [
        LeituraBpm(bpm: 120, timestamp: haMinutos(30)),
        LeituraBpm(bpm: 125, timestamp: haMinutos(20)),
        LeituraBpm(bpm: 127, timestamp: haMinutos(5)),
      ];

      final resultado = await sincronizar();

      expect(resultado.leiturasNovas, 1);
      expect(resultado.alertas, 0);
      expect(await alertasGravados(), hasLength(1));
    });

    test('Deve gerar a emergência de um episódio que começou na execução anterior', () async {
      // A execucao anterior viu so o comeco do episodio (1 leitura).
      await gravarLeitura(118, 16);
      healthService.leituras = [
        LeituraBpm(bpm: 118, timestamp: haMinutos(16)),
        LeituraBpm(bpm: 121, timestamp: haMinutos(2)),
      ];

      final resultado = await sincronizar();

      expect(resultado.alertas, 1);
      final alerta = (await alertasGravados()).single;
      expect(alerta.tipo, Alerta.tipoEmergencia);
      expect(alerta.mensagem, contains('há 14 minutos'));
    });

    test('Deve avisar a tarefa enquanto o app aberto lê o BPM', () {
      expect(appAbertoLendoBpm(), false);

      anunciarAppAberto(true);
      expect(appAbertoLendoBpm(), true);

      anunciarAppAberto(false);
      expect(appAbertoLendoBpm(), false);
    });
  });
}
