import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_diabete.dart';
import 'package:agenda_saude_app/ui/insulina/formatacao_diabete.dart';
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

    testWidgets('Deve mostrar o cartão em caixa alta com as quatro medições pendentes', (tester) async {
      await montar(tester);

      expect(find.text('GLICEMIA E INSULINA'), findsOneWidget);
      expect(find.text('HOJE: 0 DE 4 MEDIÇÕES'), findsOneWidget);
      expect(find.text('AO ACORDAR'), findsOneWidget);
      expect(find.text('ANTES DO ALMOÇO'), findsOneWidget);
      expect(find.text('ANTES DO JANTAR'), findsOneWidget);
      expect(find.text('ANTES DE DORMIR'), findsOneWidget);
      expect(find.text('INSULINA LENTA (22\u00A0HORAS)'), findsNothing);
      expect(find.text('AINDA NÃO ANOTADO'), findsNWidgets(4));
      expect(find.text('TOQUE AQUI PARA ANOTAR'), findsNWidgets(4));
      expect(find.text('ANOTAR OUTRA MEDIÇÃO'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar o campo vazio com dica fina e o exemplo fora do campo', (tester) async {
      await montar(tester);

      await tocar(tester, find.text('AO ACORDAR'));

      expect(find.text('1. QUAL FOI A SUA GLICEMIA?'), findsOneWidget);
      expect(find.textContaining('APLICOU INSULINA'), findsNothing);
      expect(find.text('EXEMPLO: 110'), findsOneWidget);
      final campo = tester.widget<TextField>(find.byType(TextField));
      expect(campo.decoration!.hintText, 'Toque aqui');
      // A dica nao pode parecer um valor ja digitado.
      expect(campo.decoration!.hintStyle!.fontWeight, FontWeight.normal);
      expect(campo.style!.fontWeight, FontWeight.bold);

      await desmontar(tester);
    });

    testWidgets('Deve anotar a glicemia de um momento e mostrar o valor com a faixa', (tester) async {
      await montar(tester);

      await tocar(tester, find.text('AO ACORDAR'));
      await tester.enterText(find.byType(TextField), '112');
      await tocar(tester, find.text('SALVAR'));

      // Voltou para o checklist.
      expect(find.text('SALVAR'), findsNothing);
      expect(find.text(formatarGlicemia(112)), findsOneWidget);
      expect(find.text('NA FAIXA'), findsOneWidget);
      expect(find.text('ANOTADO ÀS 15:00'), findsOneWidget);
      expect(find.text('CORRIGIR'), findsOneWidget);
      expect(find.text('HOJE: 1 DE 4 MEDIÇÕES'), findsOneWidget);
      expect(find.text('AO ACORDAR: ANOTADO COM SUCESSO.'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar o erro em caixa alta e continuar na tela se a glicemia for inválida', (tester) async {
      await montar(tester);

      await tocar(tester, find.text('ANTES DO JANTAR'));
      await tester.enterText(find.byType(TextField), '5');
      await tocar(tester, find.text('SALVAR'));

      expect(find.text('DIGITE UM VALOR ENTRE 20 E 600 MG/DL.'), findsOneWidget);
      // O erro toma o lugar do exemplo.
      expect(find.text('EXEMPLO: 110'), findsNothing);
      expect(find.text('SALVAR'), findsOneWidget);
      expect(
        (await fakeFirestore.collection('registros_diarios').get()).docs,
        isEmpty,
      );

      await desmontar(tester);
    });

    testWidgets('Deve anotar glicemia com dose de insulina, com as perguntas numeradas', (tester) async {
      await montar(tester, usaInsulina: true);
      expect(find.text('INSULINA LENTA (22\u00A0HORAS)'), findsOneWidget);

      await tocar(tester, find.text('ANTES DO ALMOÇO'));
      expect(find.text('2. VOCÊ APLICOU INSULINA AGORA?'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '190');
      await tocar(tester, find.text('SIM'));
      expect(find.text('3. QUAL INSULINA?'), findsOneWidget);
      await rolarAte(tester, find.text('4. QUANTAS UNIDADES?'));
      expect(find.text('4. QUANTAS UNIDADES?'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '6');
      await tocar(tester, find.text('SALVAR'));

      expect(find.text(formatarGlicemia(190)), findsOneWidget);
      expect(find.text('ALTA'), findsOneWidget);
      expect(find.text(descreverInsulina('Rápida', 6).toUpperCase()), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve anotar a insulina lenta só com a dose', (tester) async {
      await montar(tester, usaInsulina: true);

      await tocar(tester, find.text('INSULINA LENTA (22\u00A0HORAS)'));
      expect(find.text('1. QUANTAS UNIDADES?'), findsOneWidget);
      expect(find.textContaining('GLICEMIA?'), findsNothing);
      expect(find.textContaining('QUAL INSULINA?'), findsNothing);
      await tester.enterText(find.byType(TextField), '14');
      await tocar(tester, find.text('SALVAR'));

      expect(find.text(descreverInsulina('Lenta', 14).toUpperCase()), findsOneWidget);
      // A insulina lenta não conta como medição de glicemia.
      expect(find.text('HOJE: 0 DE 4 MEDIÇÕES'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar a orientação quando a última glicemia estiver baixa', (tester) async {
      await salvar('Ao acordar', DateTime(2026, 10, 25, 7, 0), glicose: 62);
      await montar(tester);

      expect(find.text('GLICEMIA BAIXA'), findsOneWidget);
      expect(find.textContaining('meça de novo em 15 minutos'), findsOneWidget);
      expect(find.text('BAIXA'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve corrigir: confirmar, apagar o valor errado e anotar de novo', (tester) async {
      await salvar('Ao acordar', DateTime(2026, 10, 25, 7, 0), glicose: 300);
      await montar(tester);
      expect(find.text('MUITO ALTA'), findsOneWidget);

      await tocar(tester, find.text('CORRIGIR'));
      expect(find.text('CORRIGIR AO ACORDAR?'), findsOneWidget);

      await tocar(tester, find.text('APAGAR E ANOTAR DE NOVO'));
      // Abriu a anotacao do mesmo momento.
      expect(find.text('1. QUAL FOI A SUA GLICEMIA?'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '130');
      await tocar(tester, find.text('SALVAR'));

      expect(find.text(formatarGlicemia(300)), findsNothing);
      expect(find.text(formatarGlicemia(130)), findsOneWidget);
      final registros =
          await fakeFirestore.collection('registros_diarios').get();
      expect(registros.docs.single.data()['nivelGlicose'], 130);

      await desmontar(tester);
    });

    testWidgets('Deve deixar o momento pendente se voltar sem anotar depois de corrigir', (tester) async {
      await salvar('Ao acordar', DateTime(2026, 10, 25, 7, 0), glicose: 300);
      await montar(tester);

      await tocar(tester, find.text('CORRIGIR'));
      await tocar(tester, find.text('APAGAR E ANOTAR DE NOVO'));
      await tocar(tester, find.text('Voltar'));

      expect(find.text(formatarGlicemia(300)), findsNothing);
      expect(find.text('TOQUE AQUI PARA ANOTAR'), findsNWidgets(4));

      await desmontar(tester);
    });

    testWidgets('Não deve apagar nada se cancelar a correção', (tester) async {
      await salvar('Ao acordar', DateTime(2026, 10, 25, 7, 0), glicose: 300);
      await montar(tester);

      await tocar(tester, find.text('CORRIGIR'));
      await tocar(tester, find.text('CANCELAR'));

      expect(find.text(formatarGlicemia(300)), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve anotar uma medição avulsa em "ANOTAR OUTRA MEDIÇÃO"', (tester) async {
      await montar(tester);

      await tocar(tester, find.text('ANOTAR OUTRA MEDIÇÃO'));
      expect(find.text('OUTRA MEDIÇÃO'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '95');
      await tocar(tester, find.text('SALVAR'));

      expect(find.text('OUTRA MEDIÇÃO'), findsOneWidget);
      expect(find.text(formatarGlicemia(95)), findsOneWidget);
      expect(find.text('HOJE: 0 DE 4 MEDIÇÕES'), findsOneWidget);

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
          'Ao acordar: anotado às 07:05. Glicemia 110 miligramas por '
          'decilitro, na faixa. Insulina rápida, 4 unidades.',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Corrigir AO ACORDAR'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Antes do almoço: ainda não anotado. Toque para anotar.'),
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
      await rolarAte(tester, find.text('MUITO BAIXA'));
      expect(tester.takeException(), isNull);

      await tocar(tester, find.text('ANTES DO JANTAR'));
      await tocar(tester, find.text('SIM'));
      await rolarAte(tester, find.text('SALVAR'));
      expect(tester.takeException(), isNull);

      await desmontar(tester);
    });
  });
}
