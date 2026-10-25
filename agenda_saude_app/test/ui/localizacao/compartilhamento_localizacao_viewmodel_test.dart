import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/services/localizacao_service.dart';
import 'package:agenda_saude_app/data/repositories/localizacao_repository.dart';
import 'package:agenda_saude_app/domain/models/localizacao.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/localizacao/compartilhamento_localizacao_viewmodel.dart';

import '../../core/services/fake_localizacao_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CompartilhamentoLocalizacaoViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late LocalizacaoRepository localizacaoRepository;
    late FakeLocalizacaoService localizacaoService;

    final paciente = Paciente(
      id: 'paciente_01',
      nome: 'José Silva',
      email: 'jose@email.com',
      perfil: 'Paciente',
      possuiDiabetes: false,
      possuiCardiopatia: false,
      codigoVinculo: 'ABC123',
    );

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      localizacaoRepository = LocalizacaoRepository(firestore: fakeFirestore);
      localizacaoService = FakeLocalizacaoService();
    });

    CompartilhamentoLocalizacaoViewModel criarViewModel({
      bool plataformaSuportada = true,
    }) {
      final viewModel = CompartilhamentoLocalizacaoViewModel(
        paciente: paciente,
        localizacaoService: localizacaoService,
        localizacaoRepository: localizacaoRepository,
        plataformaSuportada: plataformaSuportada,
        // longo o bastante para o timer nao disparar durante o teste
        intervalo: const Duration(hours: 1),
      );
      addTearDown(viewModel.dispose);
      return viewModel;
    }

    Future<Localizacao?> salva() =>
        localizacaoRepository.getLocalizacao(paciente.id);

    PosicaoGps posicao(double latitude, int minuto) => PosicaoGps(
          latitude: latitude,
          longitude: -54.8056,
          precisaoMetros: 10,
          dataHora: DateTime(2026, 10, 25, 14, minuto),
        );

    test('Deve ficar "não suportado" fora do celular sem tocar no GPS',
        () async {
      final viewModel = criarViewModel(plataformaSuportada: false);

      await viewModel.iniciar();

      expect(viewModel.estado, EstadoCompartilhamento.naoSuportado);
      expect(localizacaoService.leiturasDePosicao, 0);
      expect(localizacaoService.solicitacoesDePermissao, 0);
    });

    test('Deve começar desligado quando o paciente nunca compartilhou',
        () async {
      final viewModel = criarViewModel();

      await viewModel.iniciar();

      expect(viewModel.estado, EstadoCompartilhamento.desligado);
      expect(viewModel.compartilhamentoLigado, false);
      // Nao pede permissao nem le o GPS sem o paciente pedir.
      expect(localizacaoService.solicitacoesDePermissao, 0);
      expect(localizacaoService.leiturasDePosicao, 0);
      expect(await salva(), isNull);
    });

    test('Deve pedir permissão ao ligar e enviar a posição ao acompanhante',
        () async {
      localizacaoService.permissao = PermissaoLocalizacao.negada;
      final viewModel = criarViewModel();
      await viewModel.iniciar();

      await viewModel.ativar();

      expect(localizacaoService.solicitacoesDePermissao, 1);
      expect(viewModel.estado, EstadoCompartilhamento.ativo);
      expect(viewModel.compartilhamentoLigado, true);
      expect(viewModel.ultimaAtualizacao, DateTime(2026, 10, 25, 14, 0));
      final localizacao = await salva();
      expect(localizacao!.ativo, true);
      expect(localizacao.latitude, -22.2210);
      expect(localizacao.longitude, -54.8056);
      expect(localizacao.precisaoMetros, 12);
    });

    test('Não deve ligar nem gravar nada quando a permissão é negada',
        () async {
      localizacaoService
        ..permissao = PermissaoLocalizacao.negada
        ..respostaAoSolicitar = PermissaoLocalizacao.negada;
      final viewModel = criarViewModel();
      await viewModel.iniciar();

      await viewModel.ativar();

      expect(viewModel.estado, EstadoCompartilhamento.semPermissao);
      expect(viewModel.permissaoBloqueada, false);
      expect(viewModel.mensagemErro, contains('Permissão não concedida'));
      expect(viewModel.compartilhamentoLigado, false);
      expect(localizacaoService.leiturasDePosicao, 0);
      expect(await salva(), isNull);
    });

    test('Deve indicar permissão bloqueada para abrir as configurações',
        () async {
      localizacaoService
        ..permissao = PermissaoLocalizacao.bloqueada
        ..respostaAoSolicitar = PermissaoLocalizacao.bloqueada;
      final viewModel = criarViewModel();
      await viewModel.iniciar();

      await viewModel.ativar();
      await viewModel.abrirConfiguracoesDoApp();

      expect(viewModel.estado, EstadoCompartilhamento.semPermissao);
      expect(viewModel.permissaoBloqueada, true);
      expect(viewModel.mensagemErro, contains('bloqueada'));
      expect(localizacaoService.aberturasDasConfiguracoesDoApp, 1);
    });

    test('Deve guardar a escolha e avisar quando o GPS está desligado',
        () async {
      localizacaoService.gps = false;
      final viewModel = criarViewModel();
      await viewModel.iniciar();

      await viewModel.ativar();

      expect(viewModel.estado, EstadoCompartilhamento.gpsDesligado);
      expect(viewModel.compartilhamentoLigado, true);
      expect(localizacaoService.leiturasDePosicao, 0);
      final localizacao = await salva();
      expect(localizacao!.ativo, true);
      expect(localizacao.temPosicao, false);
    });

    test('Deve voltar a enviar ao retornar ao app com o GPS ligado', () async {
      localizacaoService.gps = false;
      final viewModel = criarViewModel();
      await viewModel.iniciar();
      await viewModel.ativar();
      expect(viewModel.estado, EstadoCompartilhamento.gpsDesligado);

      // O paciente ligou o GPS nas configuracoes e voltou para o app.
      localizacaoService.gps = true;
      viewModel.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(viewModel.estado, EstadoCompartilhamento.ativo);
      expect((await salva())!.temPosicao, true);
    });

    test('Deve retomar sozinho ao abrir o app se o paciente já compartilhava',
        () async {
      await localizacaoRepository.ativarCompartilhamento(paciente.id);
      final viewModel = criarViewModel();

      await viewModel.iniciar();

      expect(viewModel.estado, EstadoCompartilhamento.ativo);
      expect(localizacaoService.solicitacoesDePermissao, 0);
      expect(localizacaoService.leiturasDePosicao, 1);
      expect((await salva())!.temPosicao, true);
    });

    test('Deve avisar sem pedir permissão quando ela foi revogada', () async {
      await localizacaoRepository.ativarCompartilhamento(paciente.id);
      localizacaoService.permissao = PermissaoLocalizacao.negada;
      final viewModel = criarViewModel();

      await viewModel.iniciar();

      expect(viewModel.estado, EstadoCompartilhamento.semPermissao);
      expect(viewModel.compartilhamentoLigado, true);
      expect(localizacaoService.solicitacoesDePermissao, 0);
      expect(localizacaoService.leiturasDePosicao, 0);
    });

    test('Deve sobrescrever a posição a cada atualização', () async {
      final viewModel = criarViewModel();
      await viewModel.iniciar();
      await viewModel.ativar();

      localizacaoService.posicao = posicao(-22.3000, 5);
      await viewModel.atualizarAgora();

      final localizacao = await salva();
      expect(localizacao!.latitude, -22.3000);
      expect(localizacao.dataHora, DateTime(2026, 10, 25, 14, 5));
      expect(viewModel.ultimaAtualizacao, DateTime(2026, 10, 25, 14, 5));
      final docs = await fakeFirestore.collection('localizacoes').get();
      expect(docs.docs, hasLength(1));
    });

    test('Deve apagar a posição ao parar de compartilhar', () async {
      final viewModel = criarViewModel();
      await viewModel.iniciar();
      await viewModel.ativar();

      final desligou = await viewModel.desativar();

      expect(desligou, true);
      expect(viewModel.estado, EstadoCompartilhamento.desligado);
      expect(viewModel.compartilhamentoLigado, false);
      expect(viewModel.ultimaAtualizacao, isNull);
      final localizacao = await salva();
      expect(localizacao!.ativo, false);
      expect(localizacao.temPosicao, false);
    });

    test('Não deve gravar posição que o GPS entrega depois de desligar',
        () async {
      final viewModel = criarViewModel();
      await viewModel.iniciar();
      await viewModel.ativar();

      // O GPS demora a responder e o paciente desliga nesse meio tempo.
      localizacaoService.leituraPendente = Completer<PosicaoGps>();
      final atualizacao = viewModel.atualizarAgora();
      await viewModel.desativar();
      localizacaoService.leituraPendente!.complete(posicao(-22.9, 9));
      await atualizacao;

      final localizacao = await salva();
      expect(localizacao!.ativo, false);
      expect(localizacao.temPosicao, false);
      expect(viewModel.estado, EstadoCompartilhamento.desligado);
    });

    test('Deve avisar quando o GPS é desligado durante o compartilhamento',
        () async {
      final viewModel = criarViewModel();
      await viewModel.iniciar();
      await viewModel.ativar();

      localizacaoService.erroAoLer = GpsDesligadoException();
      await viewModel.atualizarAgora();

      expect(viewModel.estado, EstadoCompartilhamento.gpsDesligado);
      expect(viewModel.compartilhamentoLigado, true);
    });

    test('Deve mostrar falha de envio e limpar quando voltar a funcionar',
        () async {
      final viewModel = criarViewModel();
      await viewModel.iniciar();
      await viewModel.ativar();

      localizacaoService.erroAoLer = Exception('sem sinal');
      await viewModel.atualizarAgora();

      expect(viewModel.estado, EstadoCompartilhamento.ativo);
      expect(viewModel.mensagemErro, isNotNull);

      localizacaoService.erroAoLer = null;
      await viewModel.atualizarAgora();

      expect(viewModel.mensagemErro, isNull);
    });
  });
}
