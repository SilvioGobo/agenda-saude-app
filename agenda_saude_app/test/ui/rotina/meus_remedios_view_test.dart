import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/core/theme/app_theme.dart';
import 'package:agenda_saude_app/domain/models/medicamento.dart';
import 'package:agenda_saude_app/ui/rotina/meus_remedios_view.dart';
import 'package:agenda_saude_app/ui/rotina/meus_remedios_viewmodel.dart';

const _losartana = Medicamento(
  id: 'm1',
  nome: 'Losartana',
  dose: '50 mg',
  horarios: ['08:00'],
);
const _metformina = Medicamento(
  id: 'm2',
  nome: 'Metformina',
  dose: '500 mg',
  horarios: ['12:00', '20:00'],
);

void main() {
  group('MeusRemediosView Testes', () {
    late List<List<Medicamento>> salvos;
    late bool gravaComSucesso;

    setUp(() {
      salvos = [];
      gravaComSucesso = true;
    });

    // Abre a tela por cima de outra, como o cartao da rotina faz. A tela de
    // teste e alta para a lista montar todos os campos de uma vez.
    Future<void> abrir(
      WidgetTester tester, {
      List<Medicamento> atual = const [],
      double escalaTexto = 1,
      Size tamanho = const Size(800, 3200),
    }) async {
      tester.view.physicalSize = tamanho;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var contador = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          // Simula a opcao "tamanho da fonte" do celular.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escalaTexto)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChangeNotifierProvider(
                      create: (_) => MeusRemediosViewModel(
                        atual: atual,
                        aoSalvar: (lista) async {
                          if (gravaComSucesso) salvos.add(lista);
                          return gravaComSucesso;
                        },
                        gerarId: () => 'novo${++contador}',
                      ),
                      child: const MeusRemediosView(),
                    ),
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
    }

    Finder campo(String rotulo) => find.widgetWithText(TextFormField, rotulo);

    testWidgets('Deve mostrar os remédios do paciente para editar, com os horários', (
      tester,
    ) async {
      await abrir(tester, atual: const [_losartana, _metformina]);

      expect(find.text('Meus remédios'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(6));
      expect(find.widgetWithText(TextFormField, 'Losartana'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '50 mg'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Metformina'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('12:00'), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget);
      expect(find.text('Adicionar remédio'), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('Sem remédios, deve explicar como começar', (tester) async {
      await abrir(tester);

      expect(find.textContaining('Você ainda não cadastrou nenhum remédio'),
          findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('Deve cadastrar um remédio novo com dose e horários e salvar', (
      tester,
    ) async {
      await abrir(tester);

      await tester.tap(find.text('Adicionar remédio'));
      await tester.pumpAndSettle();
      await tester.enterText(campo('Nome do remédio'), 'Losartana');
      await tester.enterText(campo('Dose (opcional)'), '50 mg');
      await tester.enterText(campo('Novo horário'), '2000');
      await tester.tap(find.text('Adicionar horário'));
      await tester.pumpAndSettle();
      await tester.enterText(campo('Novo horário'), '0800');
      await tester.tap(find.text('Adicionar horário'));
      await tester.pumpAndSettle();

      // Os horarios ficam em ordem e o campo de horario volta vazio.
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('08:00')).dy,
        lessThan(tester.getTopLeft(find.text('20:00')).dy),
      );
      final campoDeHorario =
          tester.widget<TextFormField>(campo('Novo horário'));
      expect(campoDeHorario.controller?.text ?? campoDeHorario.initialValue, '');

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final lista = salvos.single;
      expect(lista.single.id, 'novo1');
      expect(lista.single.nome, 'Losartana');
      expect(lista.single.dose, '50 mg');
      expect(lista.single.horarios, ['08:00', '20:00']);
      // Fechou a tela.
      expect(find.text('Meus remédios'), findsNothing);
    });

    testWidgets('Deve explicar quando o horário digitado não existe, sem adicioná-lo', (
      tester,
    ) async {
      await abrir(tester, atual: const [_losartana]);

      await tester.enterText(campo('Novo horário'), '2560');
      await tester.tap(find.text('Adicionar horário'));
      await tester.pumpAndSettle();

      expect(
        find.text('ESSE HORÁRIO NÃO EXISTE. DIGITE 4 NÚMEROS, COMO 0800 PARA 08:00.'),
        findsOneWidget,
      );
      expect(find.text('25:60'), findsNothing);

      // Digitar de novo tira o aviso.
      await tester.enterText(campo('Novo horário'), '1');
      await tester.pump();
      expect(find.textContaining('ESSE HORÁRIO NÃO EXISTE'), findsNothing);
    });

    testWidgets('Deve recusar um horário repetido', (tester) async {
      await abrir(tester, atual: const [_losartana]);

      await tester.enterText(campo('Novo horário'), '800');
      await tester.tap(find.text('Adicionar horário'));
      await tester.pumpAndSettle();

      expect(find.text('ESSE HORÁRIO JÁ ESTÁ NA LISTA.'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
    });

    testWidgets('Deve acrescentar o horário digitado e esquecido ao tocar em Salvar', (
      tester,
    ) async {
      await abrir(tester, atual: const [_losartana]);

      await tester.enterText(campo('Novo horário'), '2000');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(salvos.single.single.horarios, ['08:00', '20:00']);
    });

    testWidgets('Deve remover um horário', (tester) async {
      await abrir(tester, atual: const [_metformina]);

      await tester.tap(find.text('Remover').first);
      await tester.pumpAndSettle();

      expect(find.text('12:00'), findsNothing);
      expect(find.text('20:00'), findsOneWidget);
    });

    testWidgets('Deve remover um remédio inteiro', (tester) async {
      await abrir(tester, atual: const [_losartana, _metformina]);

      await tester.tap(find.text('Remover este remédio').first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Losartana'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Metformina'), findsOneWidget);
    });

    testWidgets('Deve pedir o nome de todos os remédios e manter a tela aberta', (
      tester,
    ) async {
      await abrir(tester);

      await tester.tap(find.text('Adicionar remédio'));
      await tester.pumpAndSettle();
      await tester.enterText(campo('Novo horário'), '0800');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Dê um nome para todos os remédios.'), findsOneWidget);
      expect(find.text('Meus remédios'), findsOneWidget);
      expect(salvos, isEmpty);
    });

    testWidgets('Deve pedir um horário para cada remédio e manter a tela aberta', (
      tester,
    ) async {
      await abrir(tester);

      await tester.tap(find.text('Adicionar remédio'));
      await tester.pumpAndSettle();
      await tester.enterText(campo('Nome do remédio'), 'Losartana');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Escolha pelo menos um horário para cada remédio.'),
          findsOneWidget);
      expect(salvos, isEmpty);
    });

    testWidgets('Deve avisar quando não consegue salvar e manter a tela aberta', (
      tester,
    ) async {
      gravaComSucesso = false;
      await abrir(tester, atual: const [_losartana]);

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível salvar. Tente de novo.'),
          findsOneWidget);
      expect(find.text('Meus remédios'), findsOneWidget);
    });

    testWidgets('Deve fechar sem salvar nada ao tocar em Cancelar ou Voltar', (
      tester,
    ) async {
      await abrir(tester, atual: const [_losartana]);

      await tester.tap(find.text('Remover este remédio'));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Meus remédios'), findsNothing);

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();
      expect(find.text('Meus remédios'), findsNothing);
      expect(salvos, isEmpty);
    });

    testWidgets('Deve parar de adicionar remédios no limite de 10', (tester) async {
      // Dez remedios em edicao sao uma lista muito comprida: a tela de teste e
      // altissima para a lista montar tudo e o botao continuar ao alcance.
      await abrir(tester, tamanho: const Size(800, 9000));

      for (var i = 0; i < 10; i++) {
        await tester.tap(find.text('Adicionar remédio'));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(30));
      expect(find.text('Você já tem o máximo de 10 remédios.'), findsOneWidget);
    });

    testWidgets('Não estoura com a fonte do celular em 200%', (tester) async {
      // Celular pequeno (360x640) com a fonte no maximo: qualquer overflow
      // vira erro e reprova o teste.
      await abrir(
        tester,
        atual: const [_losartana, _metformina],
        escalaTexto: 2,
        tamanho: const Size(360, 640),
      );

      await tester.scrollUntilVisible(
        find.text('Adicionar remédio'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Adicionar remédio'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
