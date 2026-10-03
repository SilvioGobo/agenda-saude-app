import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/alerta.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/alertas/alertas_viewmodel.dart';

import '../../core/services/fake_notification_service.dart';

// Repository cuja escuta de alertas e controlada pelo teste, para simular a
// lista chegando primeiro do cache do aparelho e depois do servidor.
class _RepositorioComCache extends DadosMedicosRepository {
  final controller =
      StreamController<({List<Alerta> alertas, bool doServidor})>();

  _RepositorioComCache() : super(firestore: FakeFirebaseFirestore());

  @override
  Stream<({List<Alerta> alertas, bool doServidor})> streamAlertas(
    String pacienteId, {
    int limite = 50,
  }) =>
      controller.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AlertasViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    late FakeNotificationService notificationService;

    final jose = Paciente(
      id: 'paciente_01',
      nome: 'José Silva',
      email: 'jose@email.com',
      perfil: 'Paciente',
      possuiDiabetes: false,
      possuiCardiopatia: false,
      codigoVinculo: 'ABC123',
    );
    final maria = Paciente(
      id: 'paciente_02',
      nome: 'Maria Souza',
      email: 'maria@email.com',
      perfil: 'Paciente',
      possuiDiabetes: false,
      possuiCardiopatia: true,
      codigoVinculo: 'XYZ789',
    );

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
      notificationService = FakeNotificationService();
    });

    AlertasViewModel criarViewModel({DadosMedicosRepository? repositorio}) {
      return AlertasViewModel(
        dadosRepository: repositorio ?? dadosRepository,
        notificationService: notificationService,
      );
    }

    Future<void> gerarAlerta(
      String pacienteId, {
      String tipo = Alerta.tipoAtencao,
      String mensagem = 'Batimentos acima da zona de segurança (118 BPM).',
      DateTime? dataHora,
    }) async {
      await dadosRepository.gerarAlerta(Alerta(
        id: '',
        pacienteId: pacienteId,
        tipo: tipo,
        mensagem: mensagem,
        bpm: 118,
        dataHora: dataHora ?? DateTime.now(),
      ));
      await Future<void>.delayed(Duration.zero);
    }

    Future<void> aguardarEscuta() => Future<void>.delayed(Duration.zero);

    test('Não deve notificar os alertas que já existiam ao abrir o painel', () async {
      await gerarAlerta('paciente_01');
      final viewModel = criarViewModel()..acompanharPacientes([jose]);

      await aguardarEscuta();

      expect(viewModel.alertas, hasLength(1));
      expect(viewModel.totalNaoLidos, 1);
      expect(notificationService.mostradas, isEmpty);
      viewModel.dispose();
    });

    test('Deve notificar em tempo real quando o paciente entra em "Atenção"', () async {
      final viewModel = criarViewModel()..acompanharPacientes([jose]);
      await aguardarEscuta();

      await gerarAlerta('paciente_01');

      final notificacao = notificationService.mostradas.single;
      expect(notificacao.titulo, 'Atenção: José Silva');
      expect(notificacao.texto, 'Batimentos acima da zona de segurança (118 BPM).');
      expect(notificacao.urgente, false);
      expect(notificacao.payload, viewModel.alertas.single.id);
      expect(viewModel.totalNaoLidos, 1);
      viewModel.dispose();
    });

    test('Deve notificar alerta de emergência como urgente', () async {
      final viewModel = criarViewModel()..acompanharPacientes([jose]);
      await aguardarEscuta();

      await gerarAlerta('paciente_01', tipo: Alerta.tipoEmergencia);

      final notificacao = notificationService.mostradas.single;
      expect(notificacao.titulo, 'Emergência: José Silva');
      expect(notificacao.urgente, true);
      viewModel.dispose();
    });

    test('Não deve notificar alertas de pacientes que não estão vinculados', () async {
      final viewModel = criarViewModel()..acompanharPacientes([jose]);
      await aguardarEscuta();

      await gerarAlerta('paciente_99');

      expect(notificationService.mostradas, isEmpty);
      expect(viewModel.alertas, isEmpty);
      viewModel.dispose();
    });

    test('Deve juntar os alertas de todos os pacientes, do mais novo para o mais antigo', () async {
      final base = DateTime(2026, 9, 19, 10, 0);
      await gerarAlerta('paciente_01', mensagem: 'José 10h', dataHora: base);
      await gerarAlerta(
        'paciente_02',
        mensagem: 'Maria 11h',
        dataHora: base.add(const Duration(hours: 1)),
      );
      final viewModel = criarViewModel()..acompanharPacientes([jose, maria]);

      await aguardarEscuta();

      expect(viewModel.alertas.map((a) => a.mensagem), ['Maria 11h', 'José 10h']);
      expect(viewModel.naoLidosDoPaciente('paciente_01'), 1);
      expect(viewModel.naoLidosDoPaciente('paciente_02'), 1);
      expect(viewModel.nomeDoPaciente('paciente_02'), 'Maria Souza');
      viewModel.dispose();
    });

    test('Deve parar de escutar o paciente desvinculado', () async {
      await gerarAlerta('paciente_02');
      final viewModel = criarViewModel()..acompanharPacientes([jose, maria]);
      await aguardarEscuta();
      expect(viewModel.alertas, hasLength(1));

      viewModel.acompanharPacientes([jose]);
      await gerarAlerta('paciente_02');

      expect(viewModel.alertas, isEmpty);
      expect(notificationService.mostradas, isEmpty);
      viewModel.dispose();
    });

    test('Deve começar a escutar o paciente vinculado depois sem notificar o histórico dele', () async {
      await gerarAlerta('paciente_02');
      final viewModel = criarViewModel()..acompanharPacientes([jose]);
      await aguardarEscuta();

      viewModel.acompanharPacientes([jose, maria]);
      await aguardarEscuta();
      expect(viewModel.alertas, hasLength(1));
      expect(notificationService.mostradas, isEmpty);

      await gerarAlerta('paciente_02');
      expect(notificationService.mostradas.single.titulo, 'Atenção: Maria Souza');
      viewModel.dispose();
    });

    test('Não deve notificar o histórico que chega do servidor depois do cache', () async {
      final repositorio = _RepositorioComCache();
      final viewModel = criarViewModel(repositorio: repositorio)
        ..acompanharPacientes([jose]);
      Alerta alerta(String id) => Alerta(
            id: id,
            pacienteId: 'paciente_01',
            tipo: Alerta.tipoAtencao,
            mensagem: 'alerta $id',
            dataHora: DateTime.now(),
          );

      // Cache do aparelho vazio; o servidor traz um alerta gerado enquanto o
      // app estava fechado: entra na lista, mas nao vira notificacao.
      repositorio.controller.add((alertas: [], doServidor: false));
      repositorio.controller.add((alertas: [alerta('a1')], doServidor: true));
      await aguardarEscuta();
      expect(viewModel.alertas, hasLength(1));
      expect(notificationService.mostradas, isEmpty);

      repositorio.controller.add((alertas: [alerta('a2'), alerta('a1')], doServidor: true));
      await aguardarEscuta();
      expect(notificationService.mostradas.single.payload, 'a2');
      viewModel.dispose();
    });

    test('Deve marcar como lido e tirar a notificação da bandeja', () async {
      final viewModel = criarViewModel()..acompanharPacientes([jose]);
      await aguardarEscuta();
      await gerarAlerta('paciente_01');
      final notificacao = notificationService.mostradas.single;

      await viewModel.marcarComoLido(viewModel.alertas.single);
      await aguardarEscuta();

      expect(viewModel.totalNaoLidos, 0);
      expect(viewModel.alertas.single.lido, true);
      expect(notificationService.canceladas, [notificacao.id]);
      viewModel.dispose();
    });

    test('Deve marcar todos os alertas como lidos', () async {
      await gerarAlerta('paciente_01');
      await gerarAlerta('paciente_02');
      final viewModel = criarViewModel()..acompanharPacientes([jose, maria]);
      await aguardarEscuta();
      expect(viewModel.totalNaoLidos, 2);

      await viewModel.marcarTodosComoLidos();
      await aguardarEscuta();

      expect(viewModel.totalNaoLidos, 0);
      final salvos = await dadosRepository.getAlertas('paciente_02');
      expect(salvos.single.lido, true);
      viewModel.dispose();
    });

    test('Deve pedir a permissão de notificações ao iniciar', () async {
      final viewModel = criarViewModel();

      await viewModel.iniciar();

      expect(notificationService.inicializacoes, 1);
      expect(notificationService.solicitacoesDePermissao, 1);
      expect(viewModel.notificacoesDesativadas, false);
      viewModel.dispose();
    });

    test('Deve indicar notificações desativadas e abrir as configurações ao ativar', () async {
      notificationService
        ..permitidas = false
        ..concederAoSolicitar = false;
      final viewModel = criarViewModel();
      await viewModel.iniciar();
      expect(viewModel.notificacoesDesativadas, true);

      await viewModel.ativarNotificacoes();

      expect(notificationService.aberturasDasConfiguracoes, 1);
      expect(viewModel.notificacoesDesativadas, true);
      viewModel.dispose();
    });

    test('Não deve avisar sobre permissão em aparelho sem notificações', () async {
      notificationService.disponivel = false;
      final viewModel = criarViewModel();

      await viewModel.iniciar();

      expect(notificationService.solicitacoesDePermissao, 0);
      expect(viewModel.notificacoesDesativadas, false);
      viewModel.dispose();
    });
  });
}
