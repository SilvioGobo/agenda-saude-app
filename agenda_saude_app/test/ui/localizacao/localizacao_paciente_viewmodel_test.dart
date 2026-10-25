import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/localizacao_repository.dart';
import 'package:agenda_saude_app/domain/models/localizacao.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/localizacao/localizacao_paciente_viewmodel.dart';

import '../../core/services/fake_mapa_service.dart';

void main() {
  group('LocalizacaoPacienteViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late LocalizacaoRepository localizacaoRepository;
    late FakeMapaService mapaService;
    late DateTime agora;

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
      mapaService = FakeMapaService();
      agora = DateTime(2026, 10, 25, 14, 10);
    });

    LocalizacaoPacienteViewModel criarViewModel() {
      final viewModel = LocalizacaoPacienteViewModel(
        paciente: paciente,
        localizacaoRepository: localizacaoRepository,
        mapaService: mapaService,
        agora: () => agora,
      );
      addTearDown(viewModel.dispose);
      return viewModel;
    }

    Future<void> enviarPosicao({
      double latitude = -22.2210,
      double longitude = -54.8056,
      DateTime? dataHora,
    }) {
      return localizacaoRepository.salvarLocalizacao(Localizacao(
        pacienteId: paciente.id,
        ativo: true,
        latitude: latitude,
        longitude: longitude,
        precisaoMetros: 12,
        dataHora: dataHora ?? DateTime(2026, 10, 25, 14, 8),
      ));
    }

    test('Deve indicar que o paciente não compartilha a localização',
        () async {
      final viewModel = criarViewModel();
      expect(viewModel.carregando, true);

      await pumpEventQueue();

      expect(viewModel.carregando, false);
      expect(viewModel.compartilhando, false);
      expect(viewModel.temPosicao, false);
      expect(mapaService.enderecosPedidos, isEmpty);
    });

    test('Deve aguardar a primeira posição com o compartilhamento ligado',
        () async {
      await localizacaoRepository.ativarCompartilhamento(paciente.id);
      final viewModel = criarViewModel();

      await pumpEventQueue();

      expect(viewModel.compartilhando, true);
      expect(viewModel.temPosicao, false);
    });

    test('Deve mostrar a posição recebida com o endereço', () async {
      await enviarPosicao();
      final viewModel = criarViewModel();

      await pumpEventQueue();

      expect(viewModel.temPosicao, true);
      expect(viewModel.desatualizada, false);
      expect(viewModel.endereco, 'Rua das Flores, 120 - Centro, Dourados');
      expect(viewModel.buscandoEndereco, false);
      expect(mapaService.enderecosPedidos.single.latitude, -22.2210);
    });

    test('Deve atualizar em tempo real quando o paciente se move', () async {
      await enviarPosicao();
      final viewModel = criarViewModel();
      await pumpEventQueue();

      mapaService.endereco = 'Avenida Marcelino Pires, 500 - Centro, Dourados';
      await enviarPosicao(latitude: -22.2300);
      await pumpEventQueue();

      expect(viewModel.localizacao!.latitude, -22.2300);
      expect(viewModel.endereco,
          'Avenida Marcelino Pires, 500 - Centro, Dourados');
      expect(mapaService.enderecosPedidos, hasLength(2));
    });

    test('Não deve buscar o endereço de novo se o paciente continua no lugar',
        () async {
      await enviarPosicao();
      final viewModel = criarViewModel();
      await pumpEventQueue();

      // Mesma posicao (diferenca de ~1 metro), enviada um minuto depois.
      await enviarPosicao(
        latitude: -22.22101,
        dataHora: DateTime(2026, 10, 25, 14, 9),
      );
      await pumpEventQueue();

      expect(viewModel.localizacao!.dataHora, DateTime(2026, 10, 25, 14, 9));
      expect(mapaService.enderecosPedidos, hasLength(1));
      expect(viewModel.endereco, isNotNull);
    });

    test('Deve marcar como desatualizada a posição antiga', () async {
      await enviarPosicao(dataHora: DateTime(2026, 10, 25, 13, 0));
      final viewModel = criarViewModel();
      await pumpEventQueue();

      expect(viewModel.desatualizada, true);
    });

    test('Deve esconder a posição quando o paciente desliga', () async {
      await enviarPosicao();
      final viewModel = criarViewModel();
      await pumpEventQueue();

      await localizacaoRepository.desativarCompartilhamento(paciente.id);
      await pumpEventQueue();

      expect(viewModel.compartilhando, false);
      expect(viewModel.temPosicao, false);
    });

    test('Deve ficar sem endereço quando o celular não consegue descobrir',
        () async {
      mapaService.endereco = null;
      await enviarPosicao();
      final viewModel = criarViewModel();

      await pumpEventQueue();

      expect(viewModel.temPosicao, true);
      expect(viewModel.endereco, isNull);
      expect(viewModel.buscandoEndereco, false);
    });

    test('Deve abrir o mapa nas coordenadas do paciente', () async {
      await enviarPosicao();
      final viewModel = criarViewModel();
      await pumpEventQueue();

      final abriu = await viewModel.abrirNoMapa();

      expect(abriu, true);
      expect(mapaService.mapasAbertos.single.latitude, -22.2210);
      expect(mapaService.mapasAbertos.single.longitude, -54.8056);
    });

    test('Não deve abrir o mapa sem posição', () async {
      final viewModel = criarViewModel();
      await pumpEventQueue();

      expect(await viewModel.abrirNoMapa(), false);
      expect(mapaService.mapasAbertos, isEmpty);
    });
  });
}
