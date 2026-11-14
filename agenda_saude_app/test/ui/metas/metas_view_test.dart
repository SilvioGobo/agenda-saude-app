import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/data/repositories/preferencias_repository.dart';
import 'package:agenda_saude_app/domain/metas/calculadora_metas.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/metas/metas_view.dart';
import 'package:agenda_saude_app/ui/metas/metas_viewmodel.dart';
import 'package:agenda_saude_app/ui/configuracoes/configuracoes_viewmodel.dart';
import 'package:agenda_saude_app/ui/shared/barra_acoes.dart';
import 'package:agenda_saude_app/ui/shared/barra_superior_formulario.dart';

import '../../core/services/fake_tts_service.dart';

void main() {
  group('MetasView Testes', () {
    final hoje = DateTime(2026, 10, 25);

    late FakeFirebaseFirestore fakeFirestore;
    late PacienteRepository repositorio;
    late List<Paciente> atualizacoes;
    late List<Paciente> continuacoes;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repositorio = PacienteRepository(firestore: fakeFirestore);
      atualizacoes = [];
      continuacoes = [];
    });

    // Idosa de 70 anos, 60 kg, sedentaria: 7 copos, 4000 passos, 1270 kcal.
    Future<Paciente> criarPaciente({
      int? limiteLiquidoMl,
      double? altura = 155,
    }) async {
      final semMetas = Paciente(
        id: 'paciente_01',
        nome: 'Maria Souza',
        email: 'maria@email.com',
        perfil: 'Paciente',
        possuiDiabetes: false,
        possuiCardiopatia: false,
        codigoVinculo: 'ABC123',
        triagemConcluida: true,
        dataNascimento: DateTime(1956, 3, 1),
        sexoBiologico: 'Feminino',
        alturaCm: altura,
        pesoKg: 60,
        nivelAtividadeFisica: 'Sedentário',
        limiteLiquidoMl: limiteLiquidoMl,
      );
      final metas = CalculadoraMetas.calcular(semMetas, hoje: hoje);
      final paciente = metas == null
          ? semMetas
          : semMetas.copyWith(metas: metas);
      await repositorio.salvarPaciente(paciente);
      return paciente;
    }

    // Tela alta para a lista inteira ser construida sem rolar.
    Future<void> montar(
      WidgetTester tester,
      Paciente paciente, {
      bool primeiraVez = false,
      double escalaTexto = 1,
      Size tamanhoTela = const Size(800, 3200),
      // O narrador do app, como quando a tela abre pelo menu do painel.
      ConfiguracoesViewModel? narrador,
    }) async {
      tester.view.physicalSize = tamanhoTela;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(escalaTexto)),
            child: child!,
          ),
          home: ChangeNotifierProvider<ConfiguracoesViewModel?>.value(
            value: narrador,
            child: ChangeNotifierProvider(
              create: (_) => MetasViewModel(
                paciente: paciente,
                pacienteRepository: repositorio,
                aoAtualizar: atualizacoes.add,
              ),
              child: MetasView(
                aoContinuar: primeiraVez ? continuacoes.add : null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<Map<String, dynamic>> metasSalvas() async {
      final doc = await fakeFirestore
          .collection('usuarios')
          .doc('paciente_01')
          .get();
      return Map<String, dynamic>.from(doc.data()!['metas'] as Map);
    }

    testWidgets('Deve mostrar a rotina, a alimentação, os limites e o IMC', (
      tester,
    ) async {
      await montar(tester, await criarPaciente());

      expect(find.text('Minhas metas'), findsOneWidget);
      expect(find.textContaining('São sugestões'), findsOneWidget);

      expect(find.text('Rotina do dia'), findsOneWidget);
      expect(find.text('7 copos (1.750 ml)'), findsOneWidget);
      expect(find.text('4.000 por dia'), findsOneWidget);
      expect(find.text('150 minutos por semana'), findsOneWidget);
      expect(find.text('7 a 8 horas por noite'), findsOneWidget);

      expect(find.text('Alimentação'), findsOneWidget);
      expect(find.text('1.270 kcal por dia'), findsOneWidget);
      expect(find.text('150 g'), findsOneWidget); // carboidratos
      expect(find.text('72 g'), findsOneWidget); // proteinas
      expect(find.text('42 g'), findsOneWidget); // gorduras
      expect(find.text('pelo menos 25 g'), findsOneWidget); // fibras

      expect(find.text('Limites por dia'), findsOneWidget);
      expect(find.text('até 2.000 mg'), findsOneWidget);
      expect(find.text('até 32 g'), findsOneWidget);
      expect(find.text('até 14 g'), findsOneWidget);

      expect(find.text('IMC 25,0'), findsOneWidget);
      expect(find.text('Peso adequado'), findsOneWidget);
    });

    testWidgets('Deve avisar do limite de líquido definido pelo médico', (
      tester,
    ) async {
      await montar(tester, await criarPaciente(limiteLiquidoMl: 1500));

      expect(
        find.textContaining('limite de 1,5 litros por dia'),
        findsOneWidget,
      );
      expect(find.text('6 copos (1.500 ml)'), findsOneWidget);
    });

    testWidgets(
      // Fora da primeira vez, ajustar fica em "Personalizar rotina" (menu) e o
      // peso muda em "Meus dados" (perfil do menu).
      'Fora da primeira vez, deve oferecer só o Voltar, sem botões embaixo',
      (tester) async {
        await montar(tester, await criarPaciente());

        expect(find.text('Voltar'), findsOneWidget);
        expect(find.text('Atualizar meu peso'), findsNothing);
        expect(find.text('Ajustar metas'), findsNothing);
        expect(find.text('Aceitar e continuar'), findsNothing);
        expect(find.byType(BarraAcoes), findsNothing);
      },
    );

    testWidgets(
      'Na primeira vez, deve aceitar e continuar com o paciente atual',
      (tester) async {
        final paciente = await criarPaciente();
        await montar(tester, paciente, primeiraVez: true);

        expect(find.text('Suas metas'), findsOneWidget);
        expect(find.text('Voltar'), findsNothing);
        expect(find.text('Ajustar metas'), findsOneWidget);

        await tester.tap(find.text('Aceitar e continuar'));
        await tester.pump();

        expect(continuacoes.single.id, 'paciente_01');
        expect(continuacoes.single.metas!.calorias, 1270);
      },
    );

    testWidgets('Deve ler as metas em voz alta pelo "Ouvir esta tela"', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'narrador.ligado': true});
      final tts = FakeTtsService();
      final narrador = ConfiguracoesViewModel(
        preferencias: PreferenciasRepository(),
        ttsService: tts,
      );
      await narrador.carregar();
      await montar(tester, await criarPaciente(), narrador: narrador);

      await tester.tap(find.text('Ouvir esta tela'));
      await tester.pump();

      expect(tts.faladas.single, contains('Beber 7 copos de água.'));
      expect(tts.faladas.single, contains('Andar 4000 passos.'));
    });

    testWidgets('Não deve mostrar "Ouvir esta tela" com o narrador desligado', (
      tester,
    ) async {
      await montar(tester, await criarPaciente());

      expect(find.text('Ouvir esta tela'), findsNothing);
    });

    testWidgets(
      'Sem metas calculadas, deve explicar sem oferecer ajustes',
      (tester) async {
        await montar(tester, await criarPaciente(altura: null));

        expect(
          find.text('Ainda não foi possível calcular suas metas.'),
          findsOneWidget,
        );
        expect(find.text('Rotina do dia'), findsNothing);
        expect(find.text('Ajustar metas'), findsNothing);
        expect(find.byType(BarraAcoes), findsNothing);
      },
    );

    testWidgets(
      'Deve ajustar a água com + e salvar, voltando com o valor novo',
      (tester) async {
        await montar(tester, await criarPaciente(), primeiraVez: true);

        await tester.tap(find.text('Ajustar metas'));
        await tester.pumpAndSettle();
        expect(find.text('Ajustar metas'), findsOneWidget);
        expect(find.text('7 copos'), findsOneWidget);
        // Salvar e Cancelar na barra de cima, no lugar do Voltar.
        expect(find.byType(BarraSuperiorFormulario), findsOneWidget);
        expect(find.text('Voltar'), findsNothing);

        await tester.tap(find.byIcon(Icons.add_rounded).at(0));
        await tester.pump();
        expect(find.text('8 copos'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.add_rounded).at(1));
        await tester.pump();
        expect(find.text('4.500'), findsOneWidget);

        await tester.tap(find.text('Salvar'));
        await tester.pumpAndSettle();

        expect(find.text('Suas metas'), findsOneWidget);
        expect(find.text('8 copos (2.000 ml)'), findsOneWidget);
        expect(find.text('4.500 por dia'), findsOneWidget);
        expect(atualizacoes.single.metas!.hidratacaoMl, 2000);

        final salvas = await metasSalvas();
        expect(salvas['hidratacaoMl'], 2000);
        expect(salvas['passos'], 4500);
        expect(salvas['ajustadaManualmente'], true);
      },
    );

    testWidgets('Cancelar o ajuste não deve mudar nem gravar nada', (
      tester,
    ) async {
      await montar(tester, await criarPaciente(), primeiraVez: true);

      await tester.tap(find.text('Ajustar metas'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.remove_rounded).at(1));
      await tester.pump();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('4.000 por dia'), findsOneWidget);
      expect(atualizacoes, isEmpty);
      expect((await metasSalvas())['ajustadaManualmente'], false);
    });

    testWidgets('Não deve deixar a água passar do limite do médico', (
      tester,
    ) async {
      await montar(
        tester,
        await criarPaciente(limiteLiquidoMl: 1750),
        primeiraVez: true,
      );

      await tester.tap(find.text('Ajustar metas'));
      await tester.pumpAndSettle();

      final mais = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add_rounded).at(0),
      );
      final menos = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.remove_rounded).at(0),
      );
      expect(mais.onPressed, isNull);
      expect(menos.onPressed, isNotNull);
      expect(find.textContaining('limite do médico: 1.750 ml'), findsOneWidget);
    });

    testWidgets('Não deve estourar o layout com a fonte do celular em 200%', (
      tester,
    ) async {
      // Tamanho de celular, para o estouro aparecer de verdade.
      await montar(
        tester,
        await criarPaciente(limiteLiquidoMl: 1500),
        primeiraVez: true,
        escalaTexto: 2,
        tamanhoTela: const Size(360, 740),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Ajustar metas'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      await montar(
        tester,
        await criarPaciente(limiteLiquidoMl: 1500),
        escalaTexto: 2,
        tamanhoTela: const Size(360, 740),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
