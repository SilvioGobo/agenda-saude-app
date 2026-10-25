import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_diabete.dart';
import 'package:agenda_saude_app/ui/insulina/glicemia_insulina_viewmodel.dart';
import 'package:agenda_saude_app/ui/rotina/hidratacao_viewmodel.dart';
import 'package:agenda_saude_app/ui/rotina/rotina_view.dart';

void main() {
  group('CardGlicemiaInsulina Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    final hoje = DateTime(2026, 10, 25, 15, 0);

    Paciente criarPaciente({bool usaInsulina = false}) => Paciente(
          id: 'paciente_01',
          nome: 'José Silva',
          email: 'jose@email.com',
          perfil: 'Paciente',
          possuiDiabetes: true,
          tipoDiabetes: usaInsulina ? 'Tipo 1' : 'Tipo 2',
          usaInsulina: usaInsulina,
          possuiCardiopatia: false,
          codigoVinculo: 'ABC123',
        );

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
    });

    Future<void> montar(
      WidgetTester tester, {
      bool usaInsulina = false,
      double escalaTexto = 1,
    }) async {
      final paciente = criarPaciente(usaInsulina: usaInsulina);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escalaTexto)),
            child: child!,
          ),
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => HidratacaoViewModel(
                  paciente: paciente,
                  dadosRepository: dadosRepository,
                  agora: () => hoje,
                ),
              ),
              ChangeNotifierProvider(
                create: (_) => GlicemiaInsulinaViewModel(
                  paciente: paciente,
                  dadosRepository: dadosRepository,
                  agora: () => hoje,
                ),
              ),
            ],
            child: const RotinaView(exibirDiabetes: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Desmonta a tela para os ViewModels cancelarem o timer da meia-noite.
    Future<void> desmontar(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
    }

    // As listas sao preguicosas: o que esta abaixo da tela ainda nao existe,
    // entao rola ate o alvo aparecer.
    Future<void> rolarAte(WidgetTester tester, Finder alvo) async {
      if (alvo.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          alvo,
          200,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await tester.ensureVisible(alvo);
      await tester.pumpAndSettle();
    }

    Future<void> tocar(WidgetTester tester, Finder alvo) async {
      await rolarAte(tester, alvo);
      await tester.tap(alvo);
      await tester.pumpAndSettle();
    }

    Future<void> salvar(
      String momento,
      DateTime dataHora, {
      double? glicose,
      double? dose,
    }) {
      return dadosRepository.salvarRegistro(RegistroDiabete(
        id: '',
        pacienteId: 'paciente_01',
        dataHora: dataHora,
        nivelGlicose: glicose,
        momento: momento,
        doseInsulina: dose,
        tipoInsulina: dose == null ? null : 'Rápida',
      ));
    }

    testWidgets('Deve mostrar o cartão com as quatro medições pendentes', (tester) async {
      await montar(tester);

      expect(find.text('Glicemia e Insulina'), findsOneWidget);
      expect(find.text('0 de 4 medições'), findsOneWidget);
      expect(find.text('Ao acordar'), findsOneWidget);
      expect(find.text('Antes do almoço'), findsOneWidget);
      expect(find.text('Antes do jantar'), findsOneWidget);
      expect(find.text('Antes de dormir'), findsOneWidget);
      expect(find.text('Insulina lenta (22h)'), findsNothing);
      expect(find.text('Toque para registrar'), findsNWidgets(4));
      expect(find.text('Outra medição'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve registrar a glicemia de um momento e mostrar o valor classificado', (tester) async {
      await montar(tester);

      await tocar(tester, find.text('Ao acordar'));
      expect(find.text('Glicemia (mg/dL)'), findsOneWidget);
      expect(find.text('Aplicou insulina agora?'), findsNothing);

      await tester.enterText(find.byType(TextField), '112');
      await tocar(tester, find.text('Salvar'));

      // Voltou para o checklist.
      expect(find.text('Salvar'), findsNothing);
      expect(find.text('112 mg/dL'), findsOneWidget);
      expect(find.text('Na faixa'), findsOneWidget);
      expect(find.text('Registrado às 15:00'), findsOneWidget);
      expect(find.text('1 de 4 medições'), findsOneWidget);
      expect(find.text('Ao acordar: registro salvo.'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar o erro e continuar na tela se a glicemia for inválida', (tester) async {
      await montar(tester);

      await tocar(tester, find.text('Antes do jantar'));
      await tester.enterText(find.byType(TextField), '5');
      await tocar(tester, find.text('Salvar'));

      expect(find.textContaining('entre 20 e 600'), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);
      expect(
        (await fakeFirestore.collection('registros_diarios').get()).docs,
        isEmpty,
      );

      await desmontar(tester);
    });

    testWidgets('Deve registrar glicemia com dose de insulina para quem usa insulina', (tester) async {
      await montar(tester, usaInsulina: true);
      expect(find.text('Insulina lenta (22h)'), findsOneWidget);

      await tocar(tester, find.text('Antes do almoço'));
      await tester.enterText(find.byType(TextField), '190');
      await tocar(tester, find.text('Sim'));
      expect(find.text('Qual insulina?'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '6');
      await tocar(tester, find.text('Salvar'));

      expect(find.text('190 mg/dL'), findsOneWidget);
      expect(find.text('Alta'), findsOneWidget);
      expect(find.text('Insulina rápida: 6 unidades'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve registrar a insulina lenta só com a dose', (tester) async {
      await montar(tester, usaInsulina: true);

      await tocar(tester, find.text('Insulina lenta (22h)'));
      expect(find.text('Glicemia (mg/dL)'), findsNothing);
      expect(find.text('Qual insulina?'), findsNothing);
      await tester.enterText(find.byType(TextField), '14');
      await tocar(tester, find.text('Salvar'));

      expect(find.text('Insulina lenta: 14 unidades'), findsOneWidget);
      // A insulina lenta não conta como medição de glicemia.
      expect(find.text('0 de 4 medições'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar a orientação quando a última glicemia estiver baixa', (tester) async {
      await salvar('Ao acordar', DateTime(2026, 10, 25, 7, 0), glicose: 62);
      await montar(tester);

      expect(find.text('GLICEMIA BAIXA'), findsOneWidget);
      expect(find.textContaining('meça de novo em 15 minutos'), findsOneWidget);
      expect(find.text('Baixa'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve apagar um registro após confirmar, para corrigir o valor', (tester) async {
      await salvar('Ao acordar', DateTime(2026, 10, 25, 7, 0), glicose: 300);
      await montar(tester);
      expect(find.text('Muito alta'), findsOneWidget);

      await tocar(tester, find.text('Ao acordar'));
      expect(find.text('Apagar este registro?'), findsOneWidget);

      await tocar(tester, find.text('Apagar registro'));

      expect(find.text('300 mg/dL'), findsNothing);
      expect(find.text('Toque para registrar'), findsNWidgets(4));
      expect(find.text('Registro apagado.'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve registrar uma medição avulsa em "Outra medição"', (tester) async {
      await montar(tester);

      await tocar(tester, find.text('Outra medição'));
      await tester.enterText(find.byType(TextField), '95');
      await tocar(tester, find.text('Salvar'));

      // O título do botão e o da linha registrada.
      expect(find.text('Outra medição'), findsNWidgets(2));
      expect(find.text('95 mg/dL'), findsOneWidget);
      expect(find.text('0 de 4 medições'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve falar cada momento de forma completa para o leitor de tela', (tester) async {
      final semantica = tester.ensureSemantics();
      await salvar('Ao acordar', DateTime(2026, 10, 25, 7, 5), glicose: 110, dose: 4);
      await montar(tester, usaInsulina: true);

      expect(
        find.bySemanticsLabel('Glicemia e Insulina: 1 de 4 medições feitas hoje.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Ao acordar: feito. Glicemia 110 miligramas por decilitro, na '
          'faixa. Insulina rápida, 4 unidades. Registrado às 07:05. Toque '
          'para apagar este registro.',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Antes do almoço: pendente. Toque para registrar.'),
        findsOneWidget,
      );

      await desmontar(tester);
      semantica.dispose();
    });

    testWidgets('Não deve estourar o layout com a fonte do celular em 200%', (tester) async {
      await salvar('Ao acordar', DateTime(2026, 10, 25, 7, 0), glicose: 40, dose: 6.5);
      await salvar('Insulina lenta (22h)', DateTime(2026, 10, 25, 8, 0), dose: 14);
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await montar(tester, usaInsulina: true, escalaTexto: 2);

      expect(tester.takeException(), isNull);
      await rolarAte(tester, find.text('Muito baixa'));
      expect(tester.takeException(), isNull);

      await tocar(tester, find.text('Antes do jantar'));
      await tocar(tester, find.text('Sim'));
      expect(tester.takeException(), isNull);

      await desmontar(tester);
    });
  });
}
