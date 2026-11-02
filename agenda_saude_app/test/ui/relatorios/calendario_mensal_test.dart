import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/theme/app_theme.dart';
import 'package:agenda_saude_app/domain/models/alerta.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/refeicao_planejada.dart';
import 'package:agenda_saude_app/domain/models/registro_agua.dart';
import 'package:agenda_saude_app/domain/models/registro_refeicao.dart';
import 'package:agenda_saude_app/domain/relatorios/calculadora_relatorios.dart';
import 'package:agenda_saude_app/domain/relatorios/resumo_do_mes.dart';
import 'package:agenda_saude_app/ui/relatorios/calendario_mensal.dart';

void main() {
  group('CalendarioMensal Testes', () {
    final paciente = Paciente(
      id: 'paciente_01',
      nome: 'José Silva',
      email: 'jose@email.com',
      perfil: 'Paciente',
      possuiDiabetes: false,
      possuiCardiopatia: false,
      codigoVinculo: 'ABC123',
      refeicoes: const [RefeicaoPlanejada(id: 'cafe', nome: 'Café')],
    );

    // Novembro de 2026 (comeca num domingo), visto no dia 20: do dia 1 ao 19
    // ja terminaram. Dia 3 completo; dia 4 parcial com emergencia; dia 6
    // parcial so com aviso; o resto sem registro.
    ResumoDoMes novembro() {
      return CalculadoraRelatorios.resumirMes(
        paciente: paciente,
        mes: DateTime(2026, 11),
        hoje: DateTime(2026, 11, 20, 10),
        agua: [
          for (var i = 0; i < 8; i++)
            RegistroAgua(
              id: '',
              pacienteId: 'paciente_01',
              dataHora: DateTime(2026, 11, 3, 8 + i),
              quantidadeML: 250,
            ),
          RegistroAgua(
            id: '',
            pacienteId: 'paciente_01',
            dataHora: DateTime(2026, 11, 4, 9),
            quantidadeML: 250,
          ),
          RegistroAgua(
            id: '',
            pacienteId: 'paciente_01',
            dataHora: DateTime(2026, 11, 6, 9),
            quantidadeML: 250,
          ),
        ],
        refeicoes: [
          RegistroRefeicao(
            id: '',
            pacienteId: 'paciente_01',
            dataHora: DateTime(2026, 11, 3, 7),
            refeicaoId: 'cafe',
            nome: 'Café',
          ),
        ],
        alertas: [
          Alerta(
            id: '',
            pacienteId: 'paciente_01',
            tipo: Alerta.tipoEmergencia,
            mensagem: 'BPM alto',
            dataHora: DateTime(2026, 11, 4, 14),
          ),
          Alerta(
            id: '',
            pacienteId: 'paciente_01',
            tipo: Alerta.tipoAtencao,
            mensagem: 'BPM alto',
            dataHora: DateTime(2026, 11, 6, 14),
          ),
        ],
      );
    }

    Future<void> montar(
      WidgetTester tester,
      ResumoDoMes resumo, {
      ValueChanged<int>? aoTocarDia,
      Size tela = const Size(400, 800),
    }) async {
      tester.view.physicalSize = tela;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          home: Scaffold(
            body: SingleChildScrollView(
              child: CalendarioMensal(resumo: resumo, aoTocarDia: aoTocarDia),
            ),
          ),
        ),
      );
    }

    // A celula (InkWell) que tem o numero do dia.
    Finder celula(int dia) => find.ancestor(
          of: find.descendant(
            of: find.byType(CalendarioMensal),
            matching: find.text('$dia'),
          ),
          matching: find.byType(InkWell),
        );

    Finder iconeNaCelula(int dia, IconData icone) =>
        find.descendant(of: celula(dia), matching: find.byIcon(icone));

    testWidgets('Deve mostrar o número de cada dia do mês e as iniciais da semana', (tester) async {
      await montar(tester, novembro());

      for (var dia = 1; dia <= 30; dia++) {
        expect(
          find.descendant(
            of: find.byType(CalendarioMensal),
            matching: find.text('$dia'),
          ),
          findsOneWidget,
          reason: 'dia $dia',
        );
      }
      expect(find.text('31'), findsNothing);
      expect(find.text('D'), findsOneWidget);
      expect(find.text('T'), findsOneWidget);
      expect(find.text('S'), findsNWidgets(3));
      expect(find.text('Q'), findsNWidgets(2));
    });

    testWidgets('Deve começar o mês na coluna do dia da semana certo', (tester) async {
      // Novembro de 2026 comeca no domingo: o dia 1 fica sob o "D".
      await montar(tester, novembro());
      final largura = tester.getSize(find.byType(CalendarioMensal)).width / 7;
      final domingo = tester.getCenter(find.text('D')).dx;
      expect(tester.getCenter(find.text('1')).dx, closeTo(domingo, 1));
      expect(tester.getCenter(find.text('2')).dx, closeTo(domingo + largura, 1));
      // O dia 8 volta para o domingo, uma linha abaixo.
      expect(tester.getCenter(find.text('8')).dx, closeTo(domingo, 1));
      expect(
        tester.getCenter(find.text('8')).dy,
        greaterThan(tester.getCenter(find.text('1')).dy),
      );

      // Abril de 2026 comeca numa quarta: tres celulas vazias antes do dia 1.
      final abril = CalculadoraRelatorios.resumirMes(
        paciente: paciente,
        mes: DateTime(2026, 4),
        hoje: DateTime(2026, 5, 2),
      );
      await montar(tester, abril);
      await tester.pump();
      final domingoDeAbril = tester.getCenter(find.text('D')).dx;
      final larguraDeAbril =
          tester.getSize(find.byType(CalendarioMensal)).width / 7;
      expect(
        tester.getCenter(find.text('1')).dx,
        closeTo(domingoDeAbril + 3 * larguraDeAbril, 1),
      );
    });

    testWidgets('Deve usar o ícone de cada situação e nenhum em hoje nem nos dias que não chegaram', (tester) async {
      await montar(tester, novembro());

      expect(iconeNaCelula(3, Icons.check_circle_rounded), findsOneWidget);
      expect(iconeNaCelula(4, Icons.incomplete_circle_rounded), findsOneWidget);
      expect(
        iconeNaCelula(5, Icons.remove_circle_outline_rounded),
        findsOneWidget,
      );
      // Hoje (20) e os dias seguintes ficam sem icone.
      for (final dia in [20, 21, 30]) {
        expect(
          find.descendant(of: celula(dia), matching: find.byType(Icon)),
          findsNothing,
          reason: 'dia $dia',
        );
      }
    });

    testWidgets('Deve marcar com o triângulo vermelho só os dias de alerta grave', (tester) async {
      await montar(tester, novembro());

      // So a emergencia do dia 4; o aviso do dia 6 nao e alerta grave.
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
      expect(iconeNaCelula(4, Icons.warning_rounded), findsOneWidget);
      expect(iconeNaCelula(6, Icons.warning_rounded), findsNothing);
    });

    testWidgets('Deve responder ao toque só nos dias que já terminaram', (tester) async {
      final tocados = <int>[];
      await montar(tester, novembro(), aoTocarDia: tocados.add);

      await tester.tap(celula(3));
      await tester.tap(celula(5)); // sem registro, mas ja terminou
      await tester.tap(celula(19));
      await tester.tap(celula(20)); // hoje
      await tester.tap(celula(25)); // ainda nao chegou

      expect(tocados, [3, 5, 19]);
    });

    testWidgets('Deve descrever cada dia para o leitor de tela', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, novembro(), aoTocarDia: (_) {});

      expect(
        find.bySemanticsLabel(
          'Dia 3: rotina completa. Toque para ver o relatório do dia.',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Dia 4: rotina parcial, com alerta de saúde. '
          'Toque para ver o relatório do dia.',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Dia 5: sem registros. Toque para ver o relatório do dia.',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Dia 20: hoje, ainda em andamento'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Dia 25: ainda não chegou'), findsOneWidget);
      expect(find.bySemanticsLabel('domingo'), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('Não deve estourar o layout com a fonte em 200% num celular pequeno', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CalendarioMensal(resumo: novembro(), aoTocarDia: (_) {}),
            ),
          ),
        ),
      );

      expect(find.byType(CalendarioMensal), findsOneWidget);
    });
  });
}
