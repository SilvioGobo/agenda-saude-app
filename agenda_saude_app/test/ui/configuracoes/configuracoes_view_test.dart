import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agenda_saude_app/data/repositories/preferencias_repository.dart';
import 'package:agenda_saude_app/domain/acessibilidade/configuracao_narrador.dart';
import 'package:agenda_saude_app/ui/configuracoes/configuracoes_view.dart';
import 'package:agenda_saude_app/ui/configuracoes/configuracoes_viewmodel.dart';

import '../../core/services/fake_tts_service.dart';

void main() {
  group('ConfiguracoesView Testes', () {
    late FakeTtsService tts;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tts = FakeTtsService();
    });

    Future<ConfiguracoesViewModel> montar(
      WidgetTester tester, {
      double escalaTexto = 1,
      // Simula o TalkBack ligado.
      bool leitorDeTela = false,
    }) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final viewModel = ConfiguracoesViewModel(
        preferencias: PreferenciasRepository(),
        ttsService: tts,
      );
      await viewModel.carregar();

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(escalaTexto),
              accessibleNavigation: leitorDeTela,
            ),
            child: child!,
          ),
          home: ChangeNotifierProvider.value(
            value: viewModel,
            child: const ConfiguracoesView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return viewModel;
    }

    // O botao de velocidade traz um check quando esta escolhido.
    Finder checkDe(String rotulo) => find.descendant(
          of: find.widgetWithText(OutlinedButton, rotulo),
          matching: find.byIcon(Icons.check_rounded),
        );

    testWidgets('Deve mostrar o título e o narrador desligado de início',
        (tester) async {
      await montar(tester);

      expect(find.text('Acessibilidade'), findsOneWidget);
      expect(find.text('Narrador desligado'), findsOneWidget);
      expect(find.text('Ligar narrador'), findsOneWidget);
      expect(find.text('Velocidade da voz'), findsOneWidget);
      expect(find.text('Testar voz'), findsOneWidget);
    });

    testWidgets('Deve explicar o botão "Ouvir esta tela" e onde ele aparece', (tester) async {
      await montar(tester);

      expect(find.textContaining('botão "Ouvir esta tela"'), findsOneWidget);
      expect(find.textContaining('painel, na rotina e nos relatórios'), findsOneWidget);
    });

    testWidgets('Não deve falar do leitor de tela quando ele está desligado', (tester) async {
      await montar(tester);

      expect(find.text('Leitor de tela ligado'), findsNothing);
    });

    testWidgets('Deve explicar por que o botão some quando o leitor de tela está ligado', (tester) async {
      await montar(tester, leitorDeTela: true);

      expect(find.text('Leitor de tela ligado'), findsOneWidget);
      expect(find.textContaining('TalkBack'), findsOneWidget);
      expect(find.textContaining('as duas vozes'), findsOneWidget);
    });

    testWidgets('Deve ligar o narrador e confirmar falando', (tester) async {
      await montar(tester);

      await tester.tap(find.text('Ligar narrador'));
      await tester.pumpAndSettle();

      expect(find.text('Narrador ligado'), findsOneWidget);
      expect(find.text('Desligar narrador'), findsOneWidget);
      expect(tts.faladas, ['Narrador ligado.']);
    });

    testWidgets('Deve desligar o narrador', (tester) async {
      SharedPreferences.setMockInitialValues({'narrador.ligado': true});
      await montar(tester);
      expect(find.text('Narrador ligado'), findsOneWidget);

      await tester.tap(find.text('Desligar narrador'));
      await tester.pumpAndSettle();

      expect(find.text('Narrador desligado'), findsOneWidget);
      expect(find.text('Ligar narrador'), findsOneWidget);
    });

    testWidgets('Deve oferecer as três velocidades, com a normal escolhida de início',
        (tester) async {
      await montar(tester);

      expect(find.text('Devagar'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Rápido'), findsOneWidget);
      expect(checkDe('Normal'), findsOneWidget);
      expect(checkDe('Devagar'), findsNothing);
      expect(checkDe('Rápido'), findsNothing);
    });

    testWidgets('Deve mostrar a velocidade que o paciente já tinha escolhido',
        (tester) async {
      SharedPreferences.setMockInitialValues({'narrador.velocidade': 'rapido'});
      await montar(tester);

      expect(checkDe('Rápido'), findsOneWidget);
      expect(checkDe('Normal'), findsNothing);
    });

    testWidgets('Deve trocar a velocidade, guardá-la e falar um exemplo',
        (tester) async {
      await montar(tester);

      await tester.tap(find.text('Devagar'));
      await tester.pumpAndSettle();

      expect(checkDe('Devagar'), findsOneWidget);
      expect(checkDe('Normal'), findsNothing);
      expect(tts.velocidade, VelocidadeNarracao.devagar.taxa);
      expect(tts.faladas, ['Estou falando devagar.']);
      expect(
        (await PreferenciasRepository().narrador()).velocidade,
        VelocidadeNarracao.devagar,
      );
    });

    testWidgets('Deve testar a voz', (tester) async {
      await montar(tester);

      await tester.tap(find.text('Testar voz'));
      await tester.pumpAndSettle();

      expect(tts.faladas, hasLength(1));
      expect(tts.faladas.single, contains('narrador do Agenda Saúde'));
    });

    testWidgets('Deve avisar quando o celular não tem a voz em português',
        (tester) async {
      tts = FakeTtsService(vozEmPortugues: false);
      await montar(tester);

      expect(find.text('Voz em português não encontrada'), findsOneWidget);
    });

    testWidgets('Não deve avisar de voz faltando quando ela existe', (tester) async {
      await montar(tester);

      expect(find.text('Voz em português não encontrada'), findsNothing);
    });

    testWidgets('Deve avisar que o aparelho não tem voz do sistema', (tester) async {
      tts = FakeTtsService(disponivel: false);
      await montar(tester);

      expect(find.text('Narrador indisponível'), findsOneWidget);
      expect(find.text('Ligar narrador'), findsNothing);
      expect(find.text('Testar voz'), findsNothing);
    });

    testWidgets('Deve mostrar o erro quando a voz do sistema recusa falar',
        (tester) async {
      tts = _VozQueFalha();
      await montar(tester);

      await tester.tap(find.text('Testar voz'));
      await tester.pumpAndSettle();

      expect(find.textContaining('VOZ DO SISTEMA'), findsOneWidget);
    });

    testWidgets('Não deve estourar o layout com a fonte do celular em 200%',
        (tester) async {
      await montar(tester, escalaTexto: 2);

      expect(tester.takeException(), isNull);
      expect(find.text('Acessibilidade'), findsOneWidget);
    });
  });
}

// A voz do sistema recusa falar.
class _VozQueFalha extends FakeTtsService {
  @override
  Future<void> falar(String texto) => throw Exception('motor de voz ausente');
}
