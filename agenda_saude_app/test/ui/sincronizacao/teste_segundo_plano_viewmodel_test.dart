import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/ui/sincronizacao/card_teste_segundo_plano.dart';
import 'package:agenda_saude_app/ui/sincronizacao/teste_segundo_plano_viewmodel.dart';

import '../../core/services/fake_health_service.dart';
import '../../core/services/fake_leitura_segundo_plano_service.dart';

void main() {
  group('TesteSegundoPlanoViewModel Testes', () {
    late FakeHealthService healthService;
    late FakeLeituraSegundoPlanoService leituraSegundoPlano;

    TesteSegundoPlanoViewModel criar() => TesteSegundoPlanoViewModel(
          healthService: healthService,
          leituraSegundoPlano: leituraSegundoPlano,
        );

    setUp(() {
      healthService = FakeHealthService();
      leituraSegundoPlano = FakeLeituraSegundoPlanoService();
    });

    test('Deve verificar o recurso, a permissão e se a leitura está ligada', () async {
      healthService
        ..segundoPlanoDisponivel = true
        ..permissaoSegundoPlano = false;
      leituraSegundoPlano.ligada = true;
      final viewModel = criar();
      expect(viewModel.verificando, isTrue);

      await viewModel.verificar();

      expect(viewModel.verificando, isFalse);
      expect(viewModel.disponivel, isTrue);
      expect(viewModel.permissaoConcedida, isFalse);
      expect(viewModel.ligado, isTrue);
    });

    test('Deve pedir a permissão de ler com o app fechado', () async {
      final viewModel = criar();
      await viewModel.verificar();

      await viewModel.pedirPermissao();

      expect(healthService.solicitacoesSegundoPlano, 1);
      expect(viewModel.permissaoConcedida, isTrue);
      expect(viewModel.mensagem, 'Permissão concedida.');
    });

    test('Deve ligar, ler uma vez e desligar a leitura periódica', () async {
      final viewModel = criar();
      await viewModel.verificar();

      await viewModel.ligar();
      expect(leituraSegundoPlano.ligada, isTrue);
      expect(viewModel.ligado, isTrue);

      await viewModel.lerUmaVezAgora();
      expect(leituraSegundoPlano.leiturasAvulsas, 1);

      await viewModel.desligar();
      expect(leituraSegundoPlano.ligada, isFalse);
      expect(viewModel.ligado, isFalse);
    });

    test('Deve mostrar a falha em vez de quebrar', () async {
      leituraSegundoPlano.erro = Exception('sem WorkManager');
      final viewModel = criar();
      await viewModel.verificar();

      await viewModel.ligar();

      expect(viewModel.ligado, isFalse);
      expect(viewModel.mensagem, contains('Falhou'));
    });

    testWidgets('Cartão mostra a situação e o botão de pedir permissão', (tester) async {
      healthService
        ..segundoPlanoDisponivel = true
        ..permissaoSegundoPlano = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: [
            CardTesteSegundoPlano.comProviders(
              healthService: healthService,
              leituraSegundoPlano: leituraSegundoPlano,
            ),
          ]),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('TESTE B2: BPM COM O APP FECHADO'), findsOneWidget);
      expect(find.text('DISPONÍVEL'), findsOneWidget);
      expect(find.text('NÃO CONCEDIDA'), findsOneWidget);
      expect(find.text('DESLIGADA'), findsOneWidget);

      await tester.tap(find.text('PEDIR PERMISSÃO'));
      await tester.pumpAndSettle();
      expect(find.text('CONCEDIDA'), findsOneWidget);
      expect(find.text('PEDIR PERMISSÃO'), findsNothing);

      await tester.tap(find.text('LIGAR LEITURA A CADA 15 MIN'));
      await tester.pumpAndSettle();
      expect(find.text('LIGADA'), findsOneWidget);
      expect(find.text('DESLIGAR LEITURA'), findsOneWidget);
    });

    test('Cartão fica escondido sem o --dart-define=TESTE_B2=true', () {
      expect(CardTesteSegundoPlano.habilitado, isFalse);
    });
  });
}
