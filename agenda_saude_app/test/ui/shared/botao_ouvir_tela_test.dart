import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agenda_saude_app/core/theme/app_theme.dart';
import 'package:agenda_saude_app/data/repositories/preferencias_repository.dart';
import 'package:agenda_saude_app/ui/configuracoes/configuracoes_viewmodel.dart';
import 'package:agenda_saude_app/ui/shared/botao_ouvir_tela.dart';

import '../../core/services/fake_tts_service.dart';

// A voz do sistema recusa falar.
class _VozQueFalha extends FakeTtsService {
  @override
  Future<void> falar(String texto) async => throw Exception('sem motor de voz');
}

void main() {
  group('BotaoOuvirTela Testes', () {
    late FakeTtsService tts;
    var pedidosDeTexto = 0;

    setUp(() {
      tts = FakeTtsService();
      pedidosDeTexto = 0;
    });

    String texto() {
      pedidosDeTexto++;
      return 'Texto da tela $pedidosDeTexto.';
    }

    Future<ConfiguracoesViewModel> narrador({
      bool ligado = true,
      FakeTtsService? voz,
    }) async {
      SharedPreferences.setMockInitialValues({'narrador.ligado': ligado});
      final viewModel = ConfiguracoesViewModel(
        preferencias: PreferenciasRepository(),
        ttsService: voz ?? tts,
      );
      await viewModel.carregar();
      return viewModel;
    }

    // A tela de teste: o botao embaixo de um titulo, dentro de uma lista como
    // nas telas do app.
    Widget tela({
      ConfiguracoesViewModel? viewModel,
      bool leitorDeTela = false,
      double escalaTexto = 1,
    }) {
      Widget botao = ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Título'),
          BotaoOuvirTela(texto: texto),
          const Text('Conteúdo'),
        ],
      );
      if (viewModel != null) {
        botao = ChangeNotifierProvider.value(value: viewModel, child: botao);
      }

      return MaterialApp(
        theme: AppTheme.claro,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(escalaTexto),
            accessibleNavigation: leitorDeTela,
          ),
          child: child!,
        ),
        home: Scaffold(body: botao),
      );
    }

    Future<void> montar(
      WidgetTester tester,
      ConfiguracoesViewModel? viewModel, {
      bool leitorDeTela = false,
      double escalaTexto = 1,
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(tela(
        viewModel: viewModel,
        leitorDeTela: leitorDeTela,
        escalaTexto: escalaTexto,
      ));
      await tester.pump();
    }

    final ouvir = find.text('Ouvir esta tela');
    final parar = find.text('Parar de ouvir');

    group('quando aparece', () {
      testWidgets('Deve aparecer com o narrador ligado', (tester) async {
        await montar(tester, await narrador());

        expect(ouvir, findsOneWidget);
        expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      });

      testWidgets('Não deve aparecer com o narrador desligado', (tester) async {
        await montar(tester, await narrador(ligado: false));

        expect(ouvir, findsNothing);
      });

      testWidgets('Deve aparecer quando o narrador é ligado com a tela aberta', (tester) async {
        final viewModel = await narrador(ligado: false);
        await montar(tester, viewModel);
        expect(ouvir, findsNothing);

        await viewModel.alternarNarrador(true);
        await tester.pump();

        expect(ouvir, findsOneWidget);
      });

      testWidgets('Deve sumir quando o narrador é desligado com a tela aberta', (tester) async {
        final viewModel = await narrador();
        await montar(tester, viewModel);
        expect(ouvir, findsOneWidget);

        await viewModel.alternarNarrador(false);
        await tester.pump();

        expect(ouvir, findsNothing);
      });

      testWidgets('Não deve aparecer onde o aparelho não tem voz do sistema', (tester) async {
        await montar(tester, await narrador(voz: FakeTtsService(disponivel: false)));

        expect(ouvir, findsNothing);
      });

      testWidgets('Não deve aparecer, nem quebrar, sem narrador na árvore', (tester) async {
        await montar(tester, null);

        expect(ouvir, findsNothing);
        expect(find.text('Título'), findsOneWidget);
        expect(find.text('Conteúdo'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Não deve aparecer com o leitor de tela ligado, para as duas vozes não falarem juntas', (tester) async {
        await montar(tester, await narrador(), leitorDeTela: true);

        expect(ouvir, findsNothing);
      });

      testWidgets('Não deve deixar um buraco no lugar do botão escondido', (tester) async {
        await montar(tester, await narrador(ligado: false));

        final titulo = tester.getBottomLeft(find.text('Título')).dy;
        final conteudo = tester.getTopLeft(find.text('Conteúdo')).dy;
        // Os dois textos ficam colados, como se o botao nao existisse.
        expect(conteudo - titulo, lessThan(8));
      });
    });

    group('ao tocar', () {
      testWidgets('Deve ler o texto da tela em voz alta', (tester) async {
        await montar(tester, await narrador());

        await tester.tap(ouvir);
        await tester.pump();

        expect(tts.faladas, ['Texto da tela 1.']);
      });

      testWidgets('Deve pedir o texto só ao tocar, e não a cada vez que a tela desenha', (tester) async {
        final viewModel = await narrador();
        await montar(tester, viewModel);
        await tester.pump();
        expect(pedidosDeTexto, 0);

        await tester.tap(ouvir);
        await tester.pump();

        expect(pedidosDeTexto, 1);
      });

      testWidgets('Deve virar "Parar de ouvir" enquanto a voz fala', (tester) async {
        await montar(tester, await narrador());

        await tester.tap(ouvir);
        await tester.pump();

        expect(parar, findsOneWidget);
        expect(ouvir, findsNothing);
        expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      });

      testWidgets('Deve parar a leitura ao tocar de novo', (tester) async {
        await montar(tester, await narrador());
        await tester.tap(ouvir);
        await tester.pump();

        await tester.tap(parar);
        await tester.pump();

        expect(tts.paradas, 1);
        expect(ouvir, findsOneWidget);
        expect(parar, findsNothing);
      });

      testWidgets('Deve voltar a "Ouvir esta tela" quando a voz termina o texto', (tester) async {
        await montar(tester, await narrador());
        await tester.tap(ouvir);
        await tester.pump();
        expect(parar, findsOneWidget);

        tts.terminarDeFalar();
        await tester.pump();

        expect(ouvir, findsOneWidget);
        expect(parar, findsNothing);
      });

      testWidgets('Deve ler de novo, com o texto atual, depois de terminar', (tester) async {
        await montar(tester, await narrador());
        await tester.tap(ouvir);
        await tester.pump();
        tts.terminarDeFalar();
        await tester.pump();

        await tester.tap(ouvir);
        await tester.pump();

        expect(tts.faladas, ['Texto da tela 1.', 'Texto da tela 2.']);
      });

      testWidgets('Deve avisar, sem quebrar, quando a voz do sistema recusa falar', (tester) async {
        await montar(tester, await narrador(voz: _VozQueFalha()));

        await tester.tap(ouvir);
        await tester.pump();
        await tester.pump();

        expect(find.textContaining('voz do sistema'), findsOneWidget);
        expect(ouvir, findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('ao sair da tela', () {
      testWidgets('Deve calar a leitura quando a tela é fechada', (tester) async {
        await montar(tester, await narrador());
        await tester.tap(ouvir);
        await tester.pump();

        await tester.pumpWidget(const MaterialApp(home: Scaffold()));
        await tester.pump();

        expect(tts.paradas, 1);
      });

      testWidgets('Deve calar a leitura quando outra tela abre por cima', (tester) async {
        await montar(tester, await narrador());
        await tester.tap(ouvir);
        await tester.pump();

        tester
            .state<NavigatorState>(find.byType(Navigator))
            .push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
        await tester.pumpAndSettle();

        expect(tts.paradas, 1);
      });

      testWidgets('Deve calar a leitura quando o leitor de tela é ligado no meio dela', (tester) async {
        final viewModel = await narrador();
        await montar(tester, viewModel);
        await tester.tap(ouvir);
        await tester.pump();

        await tester.pumpWidget(tela(viewModel: viewModel, leitorDeTela: true));
        await tester.pump();

        expect(tts.paradas, 1);
        expect(ouvir, findsNothing);
      });

      testWidgets('Não deve mexer na voz ao sair da tela sem ter lido nada', (tester) async {
        await montar(tester, await narrador());

        await tester.pumpWidget(const MaterialApp(home: Scaffold()));
        await tester.pump();

        expect(tts.paradas, 0);
      });

      testWidgets('Não deve cortar uma fala que não foi dele, como o "Testar voz"', (tester) async {
        final viewModel = await narrador();
        await montar(tester, viewModel);
        await viewModel.testarVoz();
        tts.comecouAFalar();
        await tester.pump();

        await tester.pumpWidget(const MaterialApp(home: Scaffold()));
        await tester.pump();

        expect(tts.paradas, 0);
      });

      testWidgets('Não deve cortar a fala de outra leitura depois que a dele terminou', (tester) async {
        final viewModel = await narrador();
        await montar(tester, viewModel);
        await tester.tap(ouvir);
        await tester.pump();
        tts.terminarDeFalar();
        await tester.pump();
        // Outra coisa passa a falar...
        await viewModel.testarVoz();
        tts.comecouAFalar();
        await tester.pump();

        // ...e a tela do botao fecha: a fala nao e mais dele.
        await tester.pumpWidget(const MaterialApp(home: Scaffold()));
        await tester.pump();

        expect(tts.paradas, 0);
      });
    });

    group('ao rolar a tela', () {
      // Uma tela comprida, como o painel e os relatorios: o botao no topo de
      // uma lista que rola bem para baixo dele.
      Future<void> montarTelaComprida(
        WidgetTester tester,
        ConfiguracoesViewModel viewModel,
      ) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.claro,
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: viewModel,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text('Título'),
                  BotaoOuvirTela(texto: texto),
                  for (var i = 0; i < 40; i++)
                    SizedBox(height: 200, child: Text('Conteúdo $i')),
                ],
              ),
            ),
          ),
        ));
        await tester.pump();
      }

      testWidgets('Deve continuar lendo quando a tela rola e o botão sai de vista', (tester) async {
        await montarTelaComprida(tester, await narrador());
        await tester.tap(ouvir);
        await tester.pump();

        await tester.drag(find.byType(ListView), const Offset(0, -4000));
        await tester.pumpAndSettle();

        // O botao saiu da tela, mas continua vivo, e a voz segue falando.
        expect(parar, findsNothing);
        expect(find.text('Parar de ouvir', skipOffstage: false), findsOneWidget);
        expect(tts.paradas, 0);

        // De volta ao topo, ele ainda oferece parar.
        await tester.drag(find.byType(ListView), const Offset(0, 4000));
        await tester.pumpAndSettle();
        expect(parar, findsOneWidget);
      });

      testWidgets('Deve deixar a lista soltar o botão depois que a voz termina', (tester) async {
        await montarTelaComprida(tester, await narrador());
        await tester.tap(ouvir);
        await tester.pump();
        tts.terminarDeFalar();
        await tester.pump();

        await tester.drag(find.byType(ListView), const Offset(0, -4000));
        await tester.pumpAndSettle();

        // Sem fala dele, nao ha por que ficar vivo fora da tela.
        expect(find.text('Ouvir esta tela', skipOffstage: false), findsNothing);
        expect(tts.paradas, 0);
      });
    });

    group('acessibilidade e layout', () {
      testWidgets('Deve ter o tamanho dos botões do app, de pelo menos 56dp', (tester) async {
        await montar(tester, await narrador());

        // `OutlinedButton.icon` e uma subclasse privada: byType nao a acha.
        final tamanho = tester.getSize(
          find.byWidgetPredicate((widget) => widget is OutlinedButton),
        );

        expect(tamanho.height, greaterThanOrEqualTo(56));
        expect(tamanho.width, greaterThan(300));
      });

      testWidgets('Não deve estourar o layout com a fonte do celular em 200%', (tester) async {
        final viewModel = await narrador();
        await montar(tester, viewModel, escalaTexto: 2);
        expect(tester.takeException(), isNull);

        await tester.tap(ouvir);
        await tester.pump();

        expect(parar, findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Não deve estourar numa tela estreita de 320dp com a fonte em 200%', (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final viewModel = await narrador();

        await tester.pumpWidget(tela(viewModel: viewModel, escalaTexto: 2));
        await tester.pump();

        expect(ouvir, findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
