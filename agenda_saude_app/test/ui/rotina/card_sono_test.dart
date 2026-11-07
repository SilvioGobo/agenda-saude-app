import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/core/theme/app_theme.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_sono.dart';
import 'package:agenda_saude_app/ui/rotina/card_sono.dart';
import 'package:agenda_saude_app/ui/rotina/sono_viewmodel.dart';

// Leitura do dia que sempre falha (ex.: indice composto ainda nao publicado).
class _RepositorioSemLeitura extends DadosMedicosRepository {
  _RepositorioSemLeitura(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Stream<List<RegistroSono>> streamSonoDoDia(String pacienteId, DateTime dia) =>
      Stream.error(Exception('indice faltando'));
}

void main() {
  group('CardSono Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;

    final hoje = DateTime(2026, 10, 25, 9, 0);
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
    });

    Future<void> registrarSono(double horas, int qualidade) {
      return dadosRepository.salvarRegistro(RegistroSono(
        id: '',
        pacienteId: paciente.id,
        dataHora: DateTime(2026, 10, 25, 7, 0),
        dataFim: DateTime(2026, 10, 25, 7, 0),
        horasTotais: horas,
        qualidade: qualidade,
      ));
    }

    Future<void> montar(
      WidgetTester tester, {
      DadosMedicosRepository? repositorio,
      double escalaTexto = 1,
      Size tamanho = const Size(800, 1600),
    }) async {
      tester.view.physicalSize = tamanho;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.claro,
          // Simula a opcao "tamanho da fonte" do celular.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escalaTexto)),
            child: child!,
          ),
          home: ChangeNotifierProvider(
            create: (_) => SonoViewModel(
              paciente: paciente,
              dadosRepository: repositorio ?? dadosRepository,
              agora: () => hoje,
            ),
            child: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: CardSono(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Desmonta a tela para o ViewModel cancelar o timer da meia-noite.
    Future<void> desmontar(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
    }

    testWidgets('Deve lembrar de registrar e dizer a meta quando ainda não há noite registrada', (
      tester,
    ) async {
      await montar(tester);

      expect(find.text('Sono'), findsOneWidget);
      expect(find.text('Ainda não registrado'), findsOneWidget);
      expect(find.textContaining('A meta é de 7 a 9 horas por noite.'),
          findsOneWidget);
      expect(find.text('Registrar sono'), findsOneWidget);
      expect(find.text('Corrigir o sono de hoje'), findsNothing);
      expect(find.text('META DE SONO ATINGIDA'), findsNothing);
      expect(find.text('ABAIXO DA META DE SONO'), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar a noite registrada, a qualidade e a meta atingida', (
      tester,
    ) async {
      await registrarSono(7.5, 4);
      await montar(tester);

      expect(find.text('7 h 30 min'), findsOneWidget);
      expect(find.text('Qualidade: Bom (4 de 5)'), findsOneWidget);
      expect(find.text('Meta: 7 a 9 horas por noite.'), findsOneWidget);
      expect(find.text('META DE SONO ATINGIDA'), findsOneWidget);
      expect(find.text('Corrigir o sono de hoje'), findsOneWidget);
      expect(find.text('Registrar sono'), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Deve avisar com texto e ícone quando dormiu menos que a meta', (
      tester,
    ) async {
      await registrarSono(5.5, 2);
      await montar(tester);

      expect(find.text('5 h 30 min'), findsOneWidget);
      expect(find.text('Qualidade: Ruim (2 de 5)'), findsOneWidget);
      expect(find.text('ABAIXO DA META DE SONO'), findsOneWidget);
      expect(find.byIcon(Icons.info_rounded), findsOneWidget);
      expect(find.text('META DE SONO ATINGIDA'), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Deve registrar a noite pela tela própria e avisar que foi salva', (
      tester,
    ) async {
      await montar(tester);

      await tester.tap(find.text('Registrar sono'));
      await tester.pumpAndSettle();
      expect(find.text('1. QUANTAS HORAS VOCÊ DORMIU?'), findsOneWidget);

      await tester.tap(find.text('Mais'));
      await tester.tap(find.text('5 - Muito bom'));
      await tester.pump();
      await tester.tap(find.text('SALVAR'));
      await tester.pumpAndSettle();

      // De volta à Rotina: o aviso, e o cartão já com a noite nova.
      expect(find.text('Sono registrado.'), findsOneWidget);
      expect(find.text('1. QUANTAS HORAS VOCÊ DORMIU?'), findsNothing);
      expect(find.text('7 h 30 min'), findsOneWidget);
      expect(find.text('Qualidade: Muito bom (5 de 5)'), findsOneWidget);
      expect(find.text('Corrigir o sono de hoje'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve corrigir a noite de hoje abrindo a tela com o que já foi registrado', (
      tester,
    ) async {
      await registrarSono(6, 2);
      await montar(tester);

      await tester.tap(find.text('Corrigir o sono de hoje'));
      await tester.pumpAndSettle();
      expect(find.text('Corrigir o sono'), findsOneWidget);
      expect(find.text('6 h'), findsOneWidget);

      await tester.tap(find.text('Mais'));
      await tester.tap(find.text('Mais'));
      await tester.tap(find.text('3 - Regular'));
      await tester.pump();
      await tester.tap(find.text('SALVAR'));
      await tester.pumpAndSettle();

      expect(find.text('7 h'), findsOneWidget);
      expect(find.text('Qualidade: Regular (3 de 5)'), findsOneWidget);
      // A mesma noite, corrigida: continua um registro so.
      expect(
        (await fakeFirestore.collection('registros_diarios').get()).docs,
        hasLength(1),
      );

      await desmontar(tester);
    });

    testWidgets('Não deve avisar nada ao voltar sem salvar', (tester) async {
      await montar(tester);

      await tester.tap(find.text('Registrar sono'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('Sono registrado.'), findsNothing);
      expect(find.text('Ainda não registrado'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve esconder o resumo e desligar o botão quando a leitura do dia falha', (
      tester,
    ) async {
      await montar(tester, repositorio: _RepositorioSemLeitura(fakeFirestore));

      expect(find.textContaining('Não foi possível carregar o seu sono'),
          findsOneWidget);
      expect(find.text('Ainda não registrado'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.bySubtype<FilledButton>()).onPressed,
        isNull,
      );

      await desmontar(tester);
    });

    testWidgets('Deve falar o resumo numa frase só para o leitor de tela', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await registrarSono(7.5, 4);
      await montar(tester);

      expect(
        find.bySemanticsLabel('Sono: dormiu 7 horas e 30 minutos. '
            'Qualidade: Bom (4 de 5).'),
        findsOneWidget,
      );

      await desmontar(tester);
      semantica.dispose();
    });

    testWidgets('Não estoura com a fonte do celular em 200%', (tester) async {
      // Celular pequeno (360x640) com a fonte no maximo: qualquer overflow
      // vira erro e reprova o teste.
      await registrarSono(7.5, 4);
      await montar(tester, escalaTexto: 2, tamanho: const Size(360, 640));

      expect(find.text('Sono'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await desmontar(tester);
    });
  });
}
