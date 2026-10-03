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

void main() {
  group('CardSmartwatch Testes', () {
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
        agora: () => DateTime(2026, 9, 19, 14, 5),
        plataformaSuportada: true,
        intervalo: const Duration(hours: 1),
      );
    });

    Future<void> montar(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: viewModel,
              child: const CardSmartwatch(),
            ),
          ),
        ),
      );
    }

    testWidgets('Deve mostrar botão de conectar e ativar ao tocar', (tester) async {
      healthService.permissaoConcedida = false;
      await viewModel.iniciar();
      await montar(tester);

      expect(find.text('Conecte seu smartwatch'), findsOneWidget);
      expect(find.text('Conectar smartwatch'), findsOneWidget);

      await tester.tap(find.text('Conectar smartwatch'));
      await tester.pumpAndSettle();

      expect(healthService.solicitacoesDePermissao, 1);
      expect(find.text('Smartwatch conectado'), findsOneWidget);
      expect(find.text('Última sincronização às 14:05.'), findsOneWidget);
      expect(find.text('Sincronizar agora'), findsOneWidget);

      // encerra o polling antes de o teste terminar (timer periodico)
      viewModel.dispose();
    });

    testWidgets('Deve oferecer instalar o Health Connect quando ausente',
        (tester) async {
      healthService.status = StatusHealthConnect.naoInstalado;
      await viewModel.iniciar();
      await montar(tester);

      expect(find.text('Health Connect necessário'), findsOneWidget);

      await tester.tap(find.text('Instalar Health Connect'));
      await tester.pump();

      expect(healthService.aberturasDaLoja, 1);
      viewModel.dispose();
    });

    testWidgets('Deve mostrar mensagem quando a plataforma não é suportada',
        (tester) async {
      final naoSuportado = SincronizacaoBpmViewModel(
        paciente: paciente,
        healthService: healthService,
        dadosRepository: DadosMedicosRepository(firestore: FakeFirebaseFirestore()),
        plataformaSuportada: false,
      );
      await naoSuportado.iniciar();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: naoSuportado,
              child: const CardSmartwatch(),
            ),
          ),
        ),
      );

      expect(find.text('Smartwatch indisponível'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      naoSuportado.dispose();
    });
  });
}
