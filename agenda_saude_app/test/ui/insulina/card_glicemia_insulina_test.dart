import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_diabete.dart';
import 'package:agenda_saude_app/ui/insulina/card_glicemia_insulina.dart';
import 'package:agenda_saude_app/ui/insulina/formatacao_diabete.dart';
import 'package:agenda_saude_app/ui/insulina/glicemia_insulina_viewmodel.dart';
import 'package:agenda_saude_app/ui/rotina/hidratacao_viewmodel.dart';
import 'package:agenda_saude_app/ui/rotina/rotina_view.dart';

void main() {
  group('CardGlicemiaInsulina Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    final hoje = DateTime(2026, 10, 25, 15, 0);

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
    });

    // Monta a Minha Rotina com o cartao resumido de glicemia.
    Future<void> montar(WidgetTester tester, {double escalaTexto = 1}) async {
      final paciente = Paciente(
        id: 'paciente_01',
        nome: 'José Silva',
        email: 'jose@email.com',
        perfil: 'Paciente',
        possuiDiabetes: true,
        tipoDiabetes: 'Tipo 1',
        usaInsulina: true,
        possuiCardiopatia: false,
        codigoVinculo: 'ABC123',
      );
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

    Future<void> tocar(WidgetTester tester, Finder alvo) async {
      await tester.ensureVisible(alvo);
      await tester.pumpAndSettle();
      await tester.tap(alvo);
      await tester.pumpAndSettle();
    }

    Future<void> salvar(String momento, DateTime dataHora, double glicose) {
      return dadosRepository.salvarRegistro(RegistroDiabete(
        id: '',
        pacienteId: 'paciente_01',
        dataHora: dataHora,
        nivelGlicose: glicose,
        momento: momento,
      ));
    }

    Finder botaoAbrir() => find.text('ANOTAR OU VER MEDIÇÕES');

    testWidgets('Deve mostrar só o resumo na Rotina, sem o checklist', (tester) async {
      await montar(tester);

      expect(find.text('GLICEMIA E INSULINA'), findsOneWidget);
      expect(find.text('HOJE: 0 DE 4 MEDIÇÕES'), findsOneWidget);
      expect(botaoAbrir(), findsOneWidget);
      // O checklist fica na tela propria.
      expect(find.text('AO ACORDAR'), findsNothing);
      expect(find.text('TOQUE AQUI PARA ANOTAR'), findsNothing);
      expect(find.textContaining('ÚLTIMA:'), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Deve ocupar pouco espaço na Rotina', (tester) async {
      await salvar('Ao acordar', DateTime(2026, 10, 25, 7, 0), 60);
      await montar(tester);

      final cartao = find.ancestor(
        of: find.byType(CardGlicemiaInsulina),
        matching: find.byType(RotinaView),
      );
      expect(cartao, findsOneWidget);
      // Mesmo com o alerta de glicemia baixa, cabe em menos de meia tela.
      expect(tester.getSize(find.byType(CardGlicemiaInsulina)).height,
          lessThan(360));

      await desmontar(tester);
    });

    testWidgets('Deve mostrar uma bolinha cheia por medição feita', (tester) async {
      await salvar('Ao acordar', DateTime(2026, 10, 25, 7, 0), 110);
      await salvar('Antes do almoço', DateTime(2026, 10, 25, 11, 30), 130);
      await montar(tester);

      expect(find.text('HOJE: 2 DE 4 MEDIÇÕES'), findsOneWidget);
      expect(find.byIcon(Icons.circle), findsNWidgets(2));
      expect(find.byIcon(Icons.circle_outlined), findsNWidgets(2));

      await desmontar(tester);
    });

    testWidgets('Não deve mostrar alerta quando a última glicemia está na faixa', (tester) async {
      await salvar('Ao acordar', DateTime(2026, 10, 25, 7, 0), 112);
      await montar(tester);

      expect(find.textContaining('ÚLTIMA:'), findsNothing);
      expect(find.text('NA FAIXA'), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar a última glicemia baixa já na Rotina', (tester) async {
      await salvar('Ao acordar', DateTime(2026, 10, 25, 7, 0), 60);
      await montar(tester);

      expect(find.text('ÚLTIMA: ${formatarGlicemia(60)}'), findsOneWidget);
      expect(find.text('BAIXA'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar a última glicemia alta já na Rotina', (tester) async {
      await salvar('Antes do almoço', DateTime(2026, 10, 25, 11, 30), 190);
      await montar(tester);

      expect(find.text('ÚLTIMA: ${formatarGlicemia(190)}'), findsOneWidget);
      expect(find.text('ALTA'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve abrir a tela completa e atualizar o resumo ao voltar', (tester) async {
      await montar(tester);

      await tocar(tester, botaoAbrir());
      expect(find.text('AO ACORDAR'), findsOneWidget);

      await tocar(tester, find.text('AO ACORDAR'));
      await tester.enterText(find.byType(TextField), '112');
      await tocar(tester, find.text('NÃO'));
      await tocar(tester, find.text('SALVAR'));
      expect(find.text('ANOTADO ÀS 15:00'), findsOneWidget);

      await tocar(tester, find.text('Voltar'));
      expect(botaoAbrir(), findsOneWidget);
      expect(find.text('HOJE: 1 DE 4 MEDIÇÕES'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve falar o resumo e o alerta para o leitor de tela', (tester) async {
      final semantica = tester.ensureSemantics();
      await salvar('Ao acordar', DateTime(2026, 10, 25, 7, 0), 60);
      await montar(tester);

      expect(
        find.bySemanticsLabel('Glicemia e Insulina: 1 de 4 medições feitas hoje.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Atenção: última glicemia 60 miligramas por decilitro, baixa.',
        ),
        findsOneWidget,
      );

      await desmontar(tester);
      semantica.dispose();
    });

    testWidgets('Não deve estourar o layout com a fonte do celular em 200%', (tester) async {
      await salvar('Ao acordar', DateTime(2026, 10, 25, 7, 0), 40);
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await montar(tester, escalaTexto: 2);

      // A lista so monta o que esta perto da tela: rola ate o botao.
      await tester.scrollUntilVisible(
        botaoAbrir(),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('MUITO BAIXA'), findsOneWidget);

      await desmontar(tester);
    });
  });
}
