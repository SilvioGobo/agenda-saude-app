import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/data/repositories/auth_repository.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/batimento_cardiaco.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/paciente/paciente_view.dart';
import 'package:agenda_saude_app/ui/paciente/paciente_viewmodel.dart';
import 'package:agenda_saude_app/ui/sincronizacao/sincronizacao_bpm_viewmodel.dart';

import '../../core/services/fake_health_service.dart';

class _AuthRepositoryFalso extends AuthRepository {
  int saidas = 0;

  @override
  Future<void> sair() async {
    saidas++;
  }
}

void main() {
  group('PacienteView Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    late _AuthRepositoryFalso authRepository;

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
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
      authRepository = _AuthRepositoryFalso();
    });

    // `smartwatchSuportado: false` simula celular sem Health Connect; com
    // true, o smartwatch fica conectado (permissao concedida, sem leituras
    // novas) e o painel mostra o que estiver salvo no Firestore.
    Future<void> montar(
      WidgetTester tester, {
      bool smartwatchSuportado = true,
      double escalaTexto = 1,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          // Simula a opcao "tamanho da fonte" do celular.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escalaTexto)),
            child: child!,
          ),
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => PacienteViewModel(
                  paciente: paciente,
                  dadosRepository: dadosRepository,
                  authRepository: authRepository,
                ),
              ),
              ChangeNotifierProvider(
                create: (_) => SincronizacaoBpmViewModel(
                  paciente: paciente,
                  healthService: FakeHealthService(),
                  dadosRepository: dadosRepository,
                  plataformaSuportada: smartwatchSuportado,
                  intervalo: const Duration(hours: 1),
                )..iniciar(),
              ),
            ],
            child: const PacienteView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Desmonta o painel para os ViewModels cancelarem o polling (timer).
    Future<void> desmontar(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
    }

    Future<void> salvarBatimento(int bpm) {
      return dadosRepository.salvarBatimento(BatimentoCardiaco(
        id: '',
        pacienteId: paciente.id,
        bpm: bpm,
        timestamp: DateTime.now(),
      ));
    }

    testWidgets('Deve mostrar saudação e atalhos, sem código nem smartwatch na tela',
        (tester) async {
      await montar(tester);

      expect(find.text('Olá, José'), findsOneWidget);
      expect(find.text('Menu'), findsOneWidget);
      expect(find.text('Minha Rotina'), findsOneWidget);
      expect(find.text('Falar com Acompanhante'), findsOneWidget);
      expect(find.text('ABC123'), findsNothing);
      expect(find.text('Smartwatch conectado'), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar o BPM em destaque e o status estável', (tester) async {
      await salvarBatimento(72);
      await montar(tester);

      expect(find.text('72'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
      expect(find.textContaining('Medido às'), findsOneWidget);
      expect(find.text('ESTÁVEL'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar alerta quando o BPM está alto demais', (tester) async {
      await salvarBatimento(128);
      await montar(tester);

      expect(find.text('128'), findsOneWidget);
      expect(find.text('BATIMENTOS ALTOS'), findsOneWidget);
      expect(find.textContaining('acima de 100 por minuto'), findsOneWidget);
      expect(find.text('ESTÁVEL'), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar alerta quando o BPM está baixo demais', (tester) async {
      await salvarBatimento(45);
      await montar(tester);

      expect(find.text('BATIMENTOS BAIXOS'), findsOneWidget);
      expect(find.textContaining('abaixo de 60 por minuto'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar o problema do smartwatch no lugar do BPM',
        (tester) async {
      await salvarBatimento(72);
      await montar(tester, smartwatchSuportado: false);

      expect(find.text('Smartwatch indisponível'), findsOneWidget);
      expect(find.text('72'), findsNothing);
      expect(find.text('ESTÁVEL'), findsNothing);
    });

    testWidgets('Não deve estourar o layout com a fonte do celular em 200%',
        (tester) async {
      // Celular pequeno (360x640) com a fonte no maximo: qualquer overflow
      // vira erro e reprova o teste.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await salvarBatimento(128);
      await montar(tester, escalaTexto: 2);

      // Rola a tela inteira para montar (e medir) tudo, ate o ultimo botao.
      await tester.scrollUntilVisible(find.text('BATIMENTOS ALTOS'), 200);
      await tester.scrollUntilVisible(find.text('Falar com Acompanhante'), 200);
      expect(find.text('Falar com Acompanhante'), findsOneWidget);

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();
      final listaDoMenu = find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Sair da conta'),
        200,
        scrollable: listaDoMenu,
      );
      expect(find.text('Sair da conta'), findsOneWidget);

      await tester.ensureVisible(find.text('Meu código de vínculo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meu código de vínculo'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Copiar código'), 200);
      expect(find.text('Copiar código'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve abrir o menu e a tela do código de vínculo', (tester) async {
      await montar(tester);

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();

      expect(find.text('José Silva'), findsOneWidget);
      expect(find.text('Meu código de vínculo'), findsOneWidget);
      expect(find.text('Meu smartwatch'), findsOneWidget);
      expect(find.text('Conectado'), findsOneWidget);
      expect(find.text('Sair da conta'), findsOneWidget);

      await tester.tap(find.text('Meu código de vínculo'));
      await tester.pumpAndSettle();

      expect(find.text('ABC123'), findsOneWidget);
      expect(find.text('Copiar código'), findsOneWidget);

      // Voltar cai direto no painel, com o menu ja fechado.
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('Olá, José'), findsOneWidget);
      expect(find.text('Sair da conta'), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Deve abrir a tela do smartwatch pelo menu', (tester) async {
      await montar(tester);

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meu smartwatch'));
      await tester.pumpAndSettle();

      expect(find.text('Smartwatch conectado'), findsOneWidget);
      expect(find.text('Sincronizar agora'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve pedir confirmação antes de sair e não sair ao cancelar',
        (tester) async {
      await montar(tester);

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();

      expect(find.text('Sair da conta?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Sair da conta?'), findsNothing);
      expect(find.text('Olá, José'), findsOneWidget);
      expect(authRepository.saidas, 0);

      await desmontar(tester);
    });
  });
}
