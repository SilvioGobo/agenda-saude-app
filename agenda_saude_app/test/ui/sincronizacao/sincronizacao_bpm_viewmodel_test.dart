import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/services/health_service.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/alerta.dart';
import 'package:agenda_saude_app/domain/models/batimento_cardiaco.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/sincronizacao/sincronizacao_bpm_viewmodel.dart';

import '../../core/services/fake_health_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SincronizacaoBpmViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    late FakeHealthService healthService;
    late Paciente paciente;

    // Relogio fixo para os testes nao dependerem da hora real.
    final agora = DateTime(2026, 9, 19, 14, 0);

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
      healthService = FakeHealthService();
      paciente = Paciente(
        id: 'paciente_01',
        nome: 'José Silva',
        email: 'jose@email.com',
        perfil: 'Paciente',
        possuiDiabetes: false,
        possuiCardiopatia: false,
        codigoVinculo: 'ABC123',
      );
    });

    SincronizacaoBpmViewModel criarViewModel({
      Paciente? outroPaciente,
      DateTime Function()? relogio,
    }) {
      return SincronizacaoBpmViewModel(
        paciente: outroPaciente ?? paciente,
        healthService: healthService,
        dadosRepository: dadosRepository,
        agora: relogio ?? () => agora,
        plataformaSuportada: true,
        intervalo: const Duration(hours: 1),
      );
    }

    Future<List<int>> bpmsGravados() async {
      final snapshot = await fakeFirestore
          .collection('batimentos_cardiacos')
          .orderBy('timestamp')
          .get();
      return snapshot.docs.map((d) => d.data()['bpm'] as int).toList();
    }

    Future<int> totalAlertas() async {
      final snapshot = await fakeFirestore.collection('alertas').get();
      return snapshot.docs.length;
    }

    Future<List<Map<String, dynamic>>> alertasDoTipo(String tipo) async {
      final snapshot = await fakeFirestore
          .collection('alertas')
          .where('tipo', isEqualTo: tipo)
          .get();
      return snapshot.docs.map((d) => d.data()).toList();
    }

    test('Deve ficar "não suportado" fora do Android sem chamar o Health Connect',
        () async {
      final viewModel = SincronizacaoBpmViewModel(
        paciente: paciente,
        healthService: healthService,
        dadosRepository: dadosRepository,
        plataformaSuportada: false,
      );

      await viewModel.iniciar();

      expect(viewModel.estado, EstadoSincronizacao.naoSuportado);
      expect(healthService.intervalosLidos, isEmpty);
      viewModel.dispose();
    });

    test('Deve pedir instalação quando o Health Connect não está instalado',
        () async {
      healthService.status = StatusHealthConnect.naoInstalado;
      final viewModel = criarViewModel();

      await viewModel.iniciar();
      expect(viewModel.estado, EstadoSincronizacao.healthConnectAusente);

      await viewModel.instalarHealthConnect();
      expect(healthService.aberturasDaLoja, 1);
      viewModel.dispose();
    });

    test('Deve aguardar permissão e ativar depois que ela é concedida',
        () async {
      healthService.permissaoConcedida = false;
      final viewModel = criarViewModel();

      await viewModel.iniciar();
      expect(viewModel.estado, EstadoSincronizacao.semPermissao);
      expect(healthService.intervalosLidos, isEmpty);

      await viewModel.conectar();
      expect(healthService.solicitacoesDePermissao, 1);
      expect(viewModel.estado, EstadoSincronizacao.ativa);
      expect(healthService.intervalosLidos, hasLength(1));
      viewModel.dispose();
    });

    test('Deve continuar sem permissão quando o usuário nega', () async {
      healthService.permissaoConcedida = false;
      healthService.concederAoSolicitar = false;
      final viewModel = criarViewModel();

      await viewModel.iniciar();
      await viewModel.conectar();

      expect(viewModel.estado, EstadoSincronizacao.semPermissao);
      expect(viewModel.mensagemErro, isNotNull);
      viewModel.dispose();
    });

    test('Deve gravar as leituras do smartwatch em batimentos_cardiacos',
        () async {
      healthService.leituras = [
        LeituraBpm(bpm: 72, timestamp: agora.subtract(const Duration(minutes: 2))),
        LeituraBpm(bpm: 75, timestamp: agora.subtract(const Duration(minutes: 1))),
      ];
      final viewModel = criarViewModel();

      await viewModel.iniciar();

      expect(viewModel.estado, EstadoSincronizacao.ativa);
      expect(await bpmsGravados(), [72, 75]);
      expect(viewModel.leiturasImportadasNaUltima, 2);
      expect(viewModel.ultimaSincronizacao, agora);

      final doc =
          (await fakeFirestore.collection('batimentos_cardiacos').get()).docs.first;
      expect(doc.data()['pacienteId'], 'paciente_01');
      viewModel.dispose();
    });

    test('Não deve regravar leituras já salvas no Firestore', () async {
      final jaSalva = agora.subtract(const Duration(minutes: 5));
      await dadosRepository.salvarBatimento(BatimentoCardiaco(
        id: '',
        pacienteId: paciente.id,
        bpm: 70,
        timestamp: jaSalva,
      ));
      healthService.leituras = [
        LeituraBpm(bpm: 70, timestamp: jaSalva),
        LeituraBpm(bpm: 68, timestamp: agora.subtract(const Duration(minutes: 10))),
        LeituraBpm(bpm: 74, timestamp: agora.subtract(const Duration(minutes: 1))),
      ];
      final viewModel = criarViewModel();

      await viewModel.iniciar();

      // 68 e anterior a leitura ja salva, mas ainda nao estava gravada
      expect(await bpmsGravados(), [68, 70, 74]);
      viewModel.dispose();
    });

    test('Deve importar leitura antiga que chega depois de uma mais nova',
        () async {
      healthService.leituras = [
        LeituraBpm(bpm: 72, timestamp: agora.subtract(const Duration(minutes: 2))),
      ];
      final viewModel = criarViewModel();
      await viewModel.iniciar();

      // o relogio sincronizou depois: leitura de antes da ultima importada
      healthService.leituras.add(
        LeituraBpm(bpm: 80, timestamp: agora.subtract(const Duration(minutes: 20))),
      );
      await viewModel.sincronizarAgora();

      expect(await bpmsGravados(), [80, 72]);
      expect(viewModel.leiturasImportadasNaUltima, 1);
      viewModel.dispose();
    });

    test('Não deve duplicar leituras entre sincronizações seguidas', () async {
      healthService.leituras = [
        LeituraBpm(bpm: 72, timestamp: agora.subtract(const Duration(minutes: 1))),
      ];
      final viewModel = criarViewModel();

      await viewModel.iniciar();
      await viewModel.sincronizarAgora();
      await viewModel.sincronizarAgora();

      expect(await bpmsGravados(), [72]);
      expect(viewModel.leiturasImportadasNaUltima, 0);
      viewModel.dispose();
    });

    test('Deve limitar a busca inicial à janela máxima de histórico', () async {
      final viewModel = criarViewModel();

      await viewModel.iniciar();

      final intervalo = healthService.intervalosLidos.single;
      expect(intervalo.inicio, agora.subtract(SincronizacaoBpmViewModel.janelaMaxima));
      expect(intervalo.fim, agora);
      viewModel.dispose();
    });

    test('Deve gerar um alerta quando o BPM fica fora da zona por tempo prolongado',
        () async {
      healthService.leituras = [
        LeituraBpm(bpm: 120, timestamp: agora.subtract(const Duration(minutes: 6))),
        LeituraBpm(bpm: 125, timestamp: agora.subtract(const Duration(minutes: 3))),
        LeituraBpm(bpm: 122, timestamp: agora.subtract(const Duration(minutes: 1))),
      ];
      final viewModel = criarViewModel();

      await viewModel.iniciar();

      // O alerta de emergencia ja avisa o acompanhante; nao vem junto um de
      // "Atenção" para o mesmo episodio.
      expect(await totalAlertas(), 1);
      final alerta = (await fakeFirestore.collection('alertas').get()).docs.first;
      expect(alerta.data()['pacienteId'], 'paciente_01');
      expect(alerta.data()['tipo'], Alerta.tipoEmergencia);
      expect(alerta.data()['lido'], false);
      expect(alerta.data()['bpm'], 122);
      expect(alerta.data()['mensagem'], contains('122 BPM'));
      viewModel.dispose();
    });

    test('Não deve gerar alerta para um pico isolado fora da zona', () async {
      healthService.leituras = [
        LeituraBpm(bpm: 70, timestamp: agora.subtract(const Duration(minutes: 4))),
        LeituraBpm(bpm: 130, timestamp: agora.subtract(const Duration(minutes: 3))),
        LeituraBpm(bpm: 72, timestamp: agora.subtract(const Duration(minutes: 2))),
      ];
      final viewModel = criarViewModel();

      await viewModel.iniciar();

      expect(await totalAlertas(), 0);
      viewModel.dispose();
    });

    test('Deve gerar um único alerta por episódio fora da zona', () async {
      healthService.leituras = [
        LeituraBpm(bpm: 120, timestamp: agora.subtract(const Duration(minutes: 20))),
        LeituraBpm(bpm: 121, timestamp: agora.subtract(const Duration(minutes: 14))),
        LeituraBpm(bpm: 123, timestamp: agora.subtract(const Duration(minutes: 8))),
        LeituraBpm(bpm: 124, timestamp: agora.subtract(const Duration(minutes: 2))),
      ];
      final viewModel = criarViewModel();

      await viewModel.iniciar();

      expect(await totalAlertas(), 1);
      viewModel.dispose();
    });

    test('Deve reiniciar o episódio quando o BPM volta para a zona', () async {
      healthService.leituras = [
        LeituraBpm(bpm: 120, timestamp: agora.subtract(const Duration(minutes: 30))),
        LeituraBpm(bpm: 121, timestamp: agora.subtract(const Duration(minutes: 24))),
        LeituraBpm(bpm: 72, timestamp: agora.subtract(const Duration(minutes: 20))),
        LeituraBpm(bpm: 118, timestamp: agora.subtract(const Duration(minutes: 10))),
        LeituraBpm(bpm: 119, timestamp: agora.subtract(const Duration(minutes: 4))),
      ];
      final viewModel = criarViewModel();

      await viewModel.iniciar();

      // dois episodios distintos, cada um com mais de 5 minutos fora da zona
      expect(await totalAlertas(), 2);
      viewModel.dispose();
    });

    test('Deve usar a zona mais estreita para paciente com cardiopatia', () async {
      final cardiopata = Paciente(
        id: 'paciente_02',
        nome: 'Maria',
        email: 'maria@email.com',
        perfil: 'Paciente',
        possuiDiabetes: false,
        possuiCardiopatia: true,
        codigoVinculo: 'XYZ789',
      );
      // 95 BPM: normal para o paciente padrao (<=100), alto para cardiopata (<=90)
      healthService.leituras = [
        LeituraBpm(bpm: 95, timestamp: agora.subtract(const Duration(minutes: 7))),
        LeituraBpm(bpm: 96, timestamp: agora.subtract(const Duration(minutes: 1))),
      ];
      final viewModel = criarViewModel(outroPaciente: cardiopata);

      await viewModel.iniciar();

      expect(await totalAlertas(), 1);
      viewModel.dispose();
    });

    test('Deve avisar o acompanhante quando o painel passa a mostrar "Atenção"',
        () async {
      healthService.leituras = [
        LeituraBpm(bpm: 72, timestamp: agora.subtract(const Duration(minutes: 3))),
        LeituraBpm(bpm: 118, timestamp: agora.subtract(const Duration(minutes: 1))),
      ];
      final viewModel = criarViewModel();

      await viewModel.iniciar();

      final alertas = await alertasDoTipo(Alerta.tipoAtencao);
      expect(alertas, hasLength(1));
      expect(alertas.single['pacienteId'], 'paciente_01');
      expect(alertas.single['bpm'], 118);
      expect(
        alertas.single['mensagem'],
        'Batimentos acima da zona de segurança (118 BPM).',
      );
      expect(await totalAlertas(), 1);
      viewModel.dispose();
    });

    test('Deve indicar no aviso de "Atenção" quando o BPM está abaixo da zona',
        () async {
      healthService.leituras = [
        LeituraBpm(bpm: 48, timestamp: agora.subtract(const Duration(minutes: 1))),
      ];
      final viewModel = criarViewModel();

      await viewModel.iniciar();

      final alertas = await alertasDoTipo(Alerta.tipoAtencao);
      expect(
        alertas.single['mensagem'],
        'Batimentos abaixo da zona de segurança (48 BPM).',
      );
      viewModel.dispose();
    });

    test('Não deve repetir o aviso enquanto o painel continua em "Atenção"',
        () async {
      var relogio = agora;
      healthService.leituras = [
        LeituraBpm(bpm: 118, timestamp: agora.subtract(const Duration(minutes: 1))),
      ];
      final viewModel = criarViewModel(relogio: () => relogio);
      await viewModel.iniciar();

      relogio = agora.add(const Duration(minutes: 2));
      healthService.leituras.add(
        LeituraBpm(bpm: 119, timestamp: agora.add(const Duration(minutes: 1))),
      );
      await viewModel.sincronizarAgora();

      expect(await alertasDoTipo(Alerta.tipoAtencao), hasLength(1));
      viewModel.dispose();
    });

    test('Não deve avisar ao reabrir o app se o painel já estava em "Atenção"',
        () async {
      // Leitura fora da zona gravada antes de o app ser fechado: o painel ja
      // mostrava "ATENÇÃO" e o acompanhante ja tinha sido avisado.
      final anterior = agora.subtract(const Duration(minutes: 3));
      await dadosRepository.salvarBatimento(BatimentoCardiaco(
        id: '', pacienteId: 'paciente_01', bpm: 118, timestamp: anterior,
      ));
      healthService.leituras = [
        LeituraBpm(bpm: 118, timestamp: anterior),
        LeituraBpm(bpm: 121, timestamp: agora.subtract(const Duration(minutes: 1))),
      ];
      final viewModel = criarViewModel();

      await viewModel.iniciar();

      expect(await totalAlertas(), 0);
      viewModel.dispose();
    });

    test('Deve avisar de novo só depois do intervalo mínimo entre avisos',
        () async {
      var relogio = agora;
      final viewModel = criarViewModel(relogio: () => relogio);
      Future<void> sincronizarEm(int minutos, int bpm) async {
        relogio = agora.add(Duration(minutes: minutos));
        healthService.leituras.add(LeituraBpm(
          bpm: bpm,
          timestamp: relogio.subtract(const Duration(minutes: 1)),
        ));
        await viewModel.sincronizarAgora();
      }

      healthService.leituras = [
        LeituraBpm(bpm: 118, timestamp: agora.subtract(const Duration(minutes: 1))),
      ];
      await viewModel.iniciar();
      await sincronizarEm(5, 72); // volta para a zona
      await sincronizarEm(10, 119); // sai de novo, 10 min apos o aviso
      expect(await alertasDoTipo(Alerta.tipoAtencao), hasLength(1));

      await sincronizarEm(20, 70);
      await sincronizarEm(30, 121); // 30 min apos o primeiro aviso
      expect(await alertasDoTipo(Alerta.tipoAtencao), hasLength(2));
      viewModel.dispose();
    });

    test('Deve escalar de "Atenção" para emergência quando o BPM continua fora da zona',
        () async {
      var relogio = agora;
      healthService.leituras = [
        LeituraBpm(bpm: 118, timestamp: agora.subtract(const Duration(minutes: 1))),
      ];
      final viewModel = criarViewModel(relogio: () => relogio);
      await viewModel.iniciar();
      expect(await alertasDoTipo(Alerta.tipoAtencao), hasLength(1));

      relogio = agora.add(const Duration(minutes: 6));
      healthService.leituras.addAll([
        LeituraBpm(bpm: 120, timestamp: agora.add(const Duration(minutes: 2))),
        LeituraBpm(bpm: 122, timestamp: agora.add(const Duration(minutes: 5))),
      ]);
      await viewModel.sincronizarAgora();

      expect(await alertasDoTipo(Alerta.tipoAtencao), hasLength(1));
      expect(await alertasDoTipo(Alerta.tipoEmergencia), hasLength(1));
      viewModel.dispose();
    });

    test('Deve informar falha de sincronização sem sair do estado ativo',
        () async {
      healthService.erroAoLer = Exception('Health Connect indisponível');
      final viewModel = criarViewModel();

      await viewModel.iniciar();

      expect(viewModel.estado, EstadoSincronizacao.ativa);
      expect(viewModel.mensagemErro, isNotNull);
      expect(viewModel.sincronizando, isFalse);
      viewModel.dispose();
    });
  });
}
