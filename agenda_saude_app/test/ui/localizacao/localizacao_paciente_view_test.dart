import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/localizacao_repository.dart';
import 'package:agenda_saude_app/domain/models/localizacao.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/localizacao/localizacao_paciente_view.dart';

import '../../core/services/fake_mapa_service.dart';

void main() {
  group('LocalizacaoPacienteView Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late LocalizacaoRepository localizacaoRepository;
    late FakeMapaService mapaService;

    final agora = DateTime(2026, 10, 25, 14, 10);
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
    });

    Future<void> enviarPosicao({DateTime? dataHora}) {
      return localizacaoRepository.salvarLocalizacao(Localizacao(
        pacienteId: paciente.id,
        ativo: true,
        latitude: -22.2210,
        longitude: -54.8056,
        precisaoMetros: 12,
        dataHora: dataHora ?? DateTime(2026, 10, 25, 14, 8),
      ));
    }

    Future<void> montar(WidgetTester tester, {double escalaTexto = 1}) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escalaTexto)),
            child: child!,
          ),
          home: LocalizacaoPacienteView.comProviders(
            paciente,
            localizacaoRepository: localizacaoRepository,
            mapaService: mapaService,
            agora: () => agora,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Desmonta a tela para o ViewModel cancelar o relogio de 1 minuto.
    Future<void> desmontar(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
    }

    testWidgets('Deve orientar a pedir o compartilhamento quando está desligado',
        (tester) async {
      await montar(tester);

      expect(find.text('Onde está José'), findsOneWidget);
      expect(find.text('Localização não compartilhada'), findsOneWidget);
      expect(find.textContaining('Menu > Minha localização'), findsOneWidget);
      expect(find.text('Abrir no mapa'), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Deve aguardar a primeira posição com o compartilhamento ligado',
        (tester) async {
      await localizacaoRepository.ativarCompartilhamento(paciente.id);
      await montar(tester);

      expect(find.text('Aguardando localização'), findsOneWidget);
      expect(find.text('Abrir no mapa'), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar endereço, horário e precisão do último local',
        (tester) async {
      await enviarPosicao();
      await montar(tester);

      expect(find.text('Local atual'), findsOneWidget);
      expect(find.text('Rua das Flores, 120 - Centro, Dourados'), findsOneWidget);
      expect(find.text('Atualizado há 2 minutos'), findsOneWidget);
      expect(find.text('Precisão de cerca de 12 metros'), findsOneWidget);
      expect(find.text('Local pode estar desatualizado'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('Local atual: Rua das Flores, 120')),
        findsOneWidget,
      );

      await desmontar(tester);
    });

    testWidgets('Deve abrir o app de mapas nas coordenadas do paciente',
        (tester) async {
      await enviarPosicao();
      await montar(tester);

      await tester.tap(find.text('Abrir no mapa'));
      await tester.pumpAndSettle();

      expect(mapaService.mapasAbertos.single.latitude, -22.2210);
      expect(mapaService.mapasAbertos.single.longitude, -54.8056);

      await desmontar(tester);
    });

    testWidgets('Deve avisar quando não consegue abrir o mapa', (tester) async {
      mapaService.abreMapa = false;
      await enviarPosicao();
      await montar(tester);

      await tester.tap(find.text('Abrir no mapa'));
      await tester.pumpAndSettle();

      expect(
        find.text('Não foi possível abrir o mapa neste celular.'),
        findsOneWidget,
      );

      await desmontar(tester);
    });

    testWidgets('Deve mostrar as coordenadas quando não há endereço',
        (tester) async {
      mapaService.endereco = null;
      await enviarPosicao();
      await montar(tester);

      expect(find.text('Endereço não encontrado'), findsOneWidget);
      expect(find.text('-22.22100, -54.80560'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve avisar quando o último local é antigo', (tester) async {
      await enviarPosicao(dataHora: DateTime(2026, 10, 25, 9, 30));
      await montar(tester);

      expect(find.text('Último local conhecido'), findsOneWidget);
      expect(find.text('Atualizado hoje às 09:30'), findsOneWidget);
      expect(find.text('Local pode estar desatualizado'), findsOneWidget);
      expect(find.textContaining('O aplicativo de José está fechado'),
          findsOneWidget);
      // O mapa continua disponivel: e o ultimo lugar conhecido.
      await tester.scrollUntilVisible(find.text('Abrir no mapa'), 200);
      expect(find.text('Abrir no mapa'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Não deve estourar o layout com a fonte do celular em 200%',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await enviarPosicao(dataHora: DateTime(2026, 10, 24, 9, 30));
      await montar(tester, escalaTexto: 2);

      await tester.scrollUntilVisible(
        find.text('Local pode estar desatualizado'),
        200,
      );
      await tester.scrollUntilVisible(find.text('Abrir no mapa'), 200);
      expect(find.text('Abrir no mapa'), findsOneWidget);

      await desmontar(tester);
    });
  });

  group('descreverAtualizacao Testes', () {
    final agora = DateTime(2026, 10, 25, 14, 10);

    test('Deve descrever atualizações recentes em minutos', () {
      expect(
        descreverAtualizacao(DateTime(2026, 10, 25, 14, 9, 40), agora),
        'Atualizado agora mesmo',
      );
      expect(
        descreverAtualizacao(DateTime(2026, 10, 25, 14, 9), agora),
        'Atualizado há 1 minuto',
      );
      expect(
        descreverAtualizacao(DateTime(2026, 10, 25, 13, 20), agora),
        'Atualizado há 50 minutos',
      );
    });

    test('Deve descrever atualizações antigas pelo dia e horário', () {
      expect(
        descreverAtualizacao(DateTime(2026, 10, 25, 8, 5), agora),
        'Atualizado hoje às 08:05',
      );
      expect(
        descreverAtualizacao(DateTime(2026, 10, 24, 22, 0), agora),
        'Atualizado ontem às 22:00',
      );
      expect(
        descreverAtualizacao(DateTime(2026, 10, 20, 7, 30), agora),
        'Atualizado em 20/10 às 07:30',
      );
    });
  });
}
