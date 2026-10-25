import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/services/localizacao_service.dart';
import 'package:agenda_saude_app/data/repositories/localizacao_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/localizacao/compartilhamento_localizacao_viewmodel.dart';
import 'package:agenda_saude_app/ui/localizacao/minha_localizacao_view.dart';

import '../../core/services/fake_localizacao_service.dart';

void main() {
  group('MinhaLocalizacaoView Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late LocalizacaoRepository localizacaoRepository;
    late FakeLocalizacaoService localizacaoService;
    late CompartilhamentoLocalizacaoViewModel viewModel;

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
      fakeFirestore = FakeFirebaseFirestore();
      localizacaoRepository = LocalizacaoRepository(firestore: fakeFirestore);
      localizacaoService = FakeLocalizacaoService();
    });

    Future<void> montar(WidgetTester tester, {double escalaTexto = 1}) async {
      viewModel = CompartilhamentoLocalizacaoViewModel(
        paciente: paciente,
        localizacaoService: localizacaoService,
        localizacaoRepository: localizacaoRepository,
        plataformaSuportada: true,
        intervalo: const Duration(hours: 1),
      )..iniciar();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escalaTexto)),
            child: child!,
          ),
          home: MinhaLocalizacaoView.comViewModel(viewModel),
        ),
      );
      await tester.pumpAndSettle();
    }

    // O ViewModel vem do painel (ChangeNotifierProvider.value), entao o
    // teste e quem o descarta, para cancelar o envio periodico (timer).
    Future<void> desmontar(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      viewModel.dispose();
    }

    testWidgets('Deve ligar o compartilhamento pelo botão grande',
        (tester) async {
      await montar(tester);

      expect(find.text('Minha localização'), findsOneWidget);
      expect(find.text('Localização não compartilhada'), findsOneWidget);
      expect(find.text('Parar de compartilhar'), findsNothing);

      await tester.tap(find.text('Compartilhar minha localização'));
      await tester.pumpAndSettle();

      expect(find.text('Compartilhando sua localização'), findsOneWidget);
      expect(find.textContaining('Última atualização às 14:00'), findsOneWidget);
      expect(find.text('Compartilhar minha localização'), findsNothing);
      expect(find.text('Parar de compartilhar'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve pedir confirmação antes de parar de compartilhar',
        (tester) async {
      await montar(tester);
      await tester.tap(find.text('Compartilhar minha localização'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Parar de compartilhar'));
      await tester.pumpAndSettle();
      expect(find.text('Parar de compartilhar?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Compartilhando sua localização'), findsOneWidget);

      await tester.tap(find.text('Parar de compartilhar'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Parar de compartilhar'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Localização não compartilhada'), findsOneWidget);
      expect(find.text('Compartilhar minha localização'), findsOneWidget);
      final salva = await localizacaoRepository.getLocalizacao(paciente.id);
      expect(salva!.ativo, false);

      await desmontar(tester);
    });

    testWidgets('Deve levar às configurações quando a permissão está bloqueada',
        (tester) async {
      localizacaoService
        ..permissao = PermissaoLocalizacao.bloqueada
        ..respostaAoSolicitar = PermissaoLocalizacao.bloqueada;
      await montar(tester);

      await tester.tap(find.text('Compartilhar minha localização'));
      await tester.pumpAndSettle();

      expect(find.text('Permita o acesso à localização'), findsOneWidget);
      await tester.tap(find.text('Abrir configurações'));
      await tester.pumpAndSettle();

      expect(localizacaoService.aberturasDasConfiguracoesDoApp, 1);

      await desmontar(tester);
    });

    testWidgets('Deve oferecer ligar o GPS quando ele está desligado',
        (tester) async {
      localizacaoService.gps = false;
      await montar(tester);

      await tester.tap(find.text('Compartilhar minha localização'));
      await tester.pumpAndSettle();

      expect(find.text('Localização do celular desligada'), findsOneWidget);
      // O compartilhamento ja esta ligado: da para desistir dele aqui.
      expect(find.text('Parar de compartilhar'), findsOneWidget);

      await tester.tap(find.text('Ligar localização'));
      await tester.pumpAndSettle();

      expect(localizacaoService.aberturasDasConfiguracoesDeLocalizacao, 1);

      await desmontar(tester);
    });

    testWidgets('Não deve estourar o layout com a fonte do celular em 200%',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      localizacaoService.gps = false;

      await montar(tester, escalaTexto: 2);
      await tester.scrollUntilVisible(
        find.text('Compartilhar minha localização'),
        200,
      );
      await tester.ensureVisible(find.text('Compartilhar minha localização'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compartilhar minha localização'));
      await tester.pumpAndSettle();

      // Estado com mais texto: titulo, explicacao e dois botoes. A tela
      // ficou rolada para baixo, entao volta ate o titulo do card.
      await tester.scrollUntilVisible(
        find.text('Localização do celular desligada'),
        -200,
      );
      expect(find.text('Localização do celular desligada'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Parar de compartilhar'), 200);
      await tester.scrollUntilVisible(find.textContaining('Só quem'), 200);
      expect(find.textContaining('Só quem'), findsOneWidget);

      await desmontar(tester);
    });
  });
}
