import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/core/services/health_service.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/sincronizacao/card_smartwatch.dart';
import 'package:agenda_saude_app/ui/sincronizacao/sincronizacao_bpm_viewmodel.dart';

import '../../core/services/fake_health_service.dart';
import '../../core/services/fake_leitura_segundo_plano_service.dart';

void main() {
  group('Explicação dos batimentos Testes', () {
    late FakeHealthService healthService;
    late SincronizacaoBpmViewModel viewModel;

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
      healthService = FakeHealthService();
      viewModel = SincronizacaoBpmViewModel(
        paciente: paciente,
        healthService: healthService,
        dadosRepository: DadosMedicosRepository(firestore: FakeFirebaseFirestore()),
        leituraComAppFechado: FakeLeituraSegundoPlanoService(),
        agora: () => DateTime(2026, 9, 19, 14, 5),
        plataformaSuportada: true,
        intervalo: const Duration(hours: 1),
      );
    });

    // Abre a explicacao pelo "Como funciona?" do card de "Meu smartwatch".
    Future<void> abrirExplicacao(
      WidgetTester tester, {
      double escalaTexto = 1,
    }) async {
      await viewModel.iniciar();
      await tester.pumpWidget(
        MaterialApp(
          // Simula a opcao "tamanho da fonte" do celular.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(escalaTexto),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: viewModel,
              child: ListView(children: const [CardSmartwatch()]),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Como funciona?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Como funciona?'));
      await tester.pumpAndSettle();
    }

    Future<void> tocar(WidgetTester tester, String texto) async {
      await tester.ensureVisible(find.text(texto));
      await tester.pumpAndSettle();
      await tester.tap(find.text(texto));
      await tester.pumpAndSettle();
    }

    testWidgets('Deve explicar o caminho dos batimentos e onde fica o Saúde Connect',
        (tester) async {
      await abrirExplicacao(tester);

      expect(find.text('Como o app recebe seus batimentos'), findsOneWidget);
      expect(find.textContaining('não se liga direto no relógio'), findsOneWidget);
      expect(find.text('Se os batimentos não aparecem'), findsOneWidget);
      expect(find.text('Onde fica o Saúde Connect'), findsOneWidget);
      expect(find.textContaining('procure por "Saúde Connect"'), findsOneWidget);
      // Em alguns celulares o nome e outro: a explicacao cita os dois.
      expect(find.textContaining('"Conexão Saúde" ou "Health Connect"'),
          findsOneWidget);

      await tocar(tester, 'Fechar');

      expect(find.text('Como o app recebe seus batimentos'), findsNothing);
      viewModel.dispose();
    });

    testWidgets('Deve abrir o Saúde Connect sem parar a leitura dos batimentos',
        (tester) async {
      await abrirExplicacao(tester);

      await tocar(tester, 'Abrir o Saúde Connect');

      expect(healthService.aberturasDasConfiguracoes, 1);
      expect(find.textContaining('Não deu para abrir'), findsNothing);
      expect(viewModel.estado, EstadoSincronizacao.ativa);
      viewModel.dispose();
    });

    testWidgets('Deve dizer onde procurar quando o Saúde Connect não abre',
        (tester) async {
      healthService.abreConfiguracoes = false;
      await abrirExplicacao(tester);

      await tocar(tester, 'Abrir o Saúde Connect');

      expect(find.textContaining('Não deu para abrir por aqui'), findsOneWidget);
      expect(viewModel.estado, EstadoSincronizacao.ativa);
      viewModel.dispose();
    });

    testWidgets('Não deve oferecer abrir o Saúde Connect quando ele não está instalado',
        (tester) async {
      healthService.status = StatusHealthConnect.naoInstalado;
      await abrirExplicacao(tester);

      expect(find.text('Como o app recebe seus batimentos'), findsOneWidget);
      expect(find.text('Abrir o Saúde Connect'), findsNothing);
      viewModel.dispose();
    });

    testWidgets('Não deve estourar o layout com a fonte do celular em 200%',
        (tester) async {
      // Celular pequeno (360x640) com a fonte no maximo: qualquer overflow
      // vira erro e reprova o teste.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await abrirExplicacao(tester, escalaTexto: 2);

      // Rola a explicacao inteira, ate o ultimo botao.
      await tester.ensureVisible(find.text('Fechar'));
      await tester.pumpAndSettle();
      expect(find.text('Abrir o Saúde Connect'), findsOneWidget);
      viewModel.dispose();
    });
  });
}
