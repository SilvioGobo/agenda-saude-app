import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/sincronizacao/card_leitura_app_fechado.dart';
import 'package:agenda_saude_app/ui/sincronizacao/sincronizacao_bpm_viewmodel.dart';

import '../../core/services/fake_health_service.dart';
import '../../core/services/fake_leitura_segundo_plano_service.dart';

void main() {
  group('CardLeituraAppFechado Testes', () {
    late FakeHealthService healthService;
    late FakeLeituraSegundoPlanoService leituraComAppFechado;
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
      leituraComAppFechado = FakeLeituraSegundoPlanoService();
      viewModel = SincronizacaoBpmViewModel(
        paciente: paciente,
        healthService: healthService,
        dadosRepository:
            DadosMedicosRepository(firestore: FakeFirebaseFirestore()),
        leituraComAppFechado: leituraComAppFechado,
        agora: () => DateTime(2026, 11, 7, 14, 5),
        plataformaSuportada: true,
        intervalo: const Duration(hours: 1),
      );
    });

    Future<void> montar(WidgetTester tester, {double escalaTexto = 1}) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escalaTexto)),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                ChangeNotifierProvider.value(
                  value: viewModel,
                  child: const CardLeituraAppFechado(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('Deve mostrar DESLIGADA e ligar ao permitir a leitura', (tester) async {
      await viewModel.iniciar();
      await montar(tester);

      expect(find.text('COM O APP FECHADO'), findsOneWidget);
      expect(find.text('DESLIGADA'), findsOneWidget);

      await tester.tap(find.text('PERMITIR LEITURA COM O APP FECHADO'));
      await tester.pumpAndSettle();

      expect(find.text('LIGADA'), findsOneWidget);
      expect(find.text('PERMITIR LEITURA COM O APP FECHADO'), findsNothing);
      expect(leituraComAppFechado.ligada, true);
      viewModel.dispose();
    });

    testWidgets('Deve explicar quando a permissão é negada', (tester) async {
      healthService.concederSegundoPlanoAoSolicitar = false;
      await viewModel.iniciar();
      await montar(tester);

      await tester.tap(find.text('PERMITIR LEITURA COM O APP FECHADO'));
      await tester.pumpAndSettle();

      expect(find.text('DESLIGADA'), findsOneWidget);
      expect(find.textContaining('Permissão não concedida'), findsOneWidget);
      viewModel.dispose();
    });

    testWidgets('Deve mostrar LIGADA, sem botão, quando o paciente já permitiu', (tester) async {
      healthService.permissaoSegundoPlano = true;
      await viewModel.iniciar();
      await montar(tester);

      expect(find.text('LIGADA'), findsOneWidget);
      expect(find.textContaining('a cada 15 minutos'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      viewModel.dispose();
    });

    testWidgets('Deve avisar quando o celular não tem o recurso', (tester) async {
      healthService.segundoPlanoDisponivel = false;
      await viewModel.iniciar();
      await montar(tester);

      expect(find.text('NÃO FUNCIONA NESTE CELULAR'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      viewModel.dispose();
    });

    testWidgets('Não deve aparecer sem o smartwatch conectado', (tester) async {
      healthService.permissaoConcedida = false;
      await viewModel.iniciar();
      await montar(tester);

      expect(find.text('COM O APP FECHADO'), findsNothing);
      viewModel.dispose();
    });

    testWidgets('Não deve estourar com a fonte do celular em 200%', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await viewModel.iniciar();

      await montar(tester, escalaTexto: 2);

      expect(tester.takeException(), isNull);
      expect(find.text('PERMITIR LEITURA COM O APP FECHADO'), findsOneWidget);
      viewModel.dispose();
    });
  });
}
