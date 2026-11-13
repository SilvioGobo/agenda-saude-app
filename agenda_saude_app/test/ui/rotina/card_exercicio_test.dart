import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/core/theme/app_theme.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_exercicio.dart';
import 'package:agenda_saude_app/ui/rotina/card_exercicio.dart';
import 'package:agenda_saude_app/ui/rotina/exercicio_viewmodel.dart';

// Leitura da semana que sempre falha (ex.: indice composto nao publicado).
class _RepositorioSemLeitura extends DadosMedicosRepository {
  _RepositorioSemLeitura(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Stream<List<RegistroExercicio>> streamExerciciosDaSemana(
    String pacienteId,
    DateTime dia,
  ) =>
      Stream.error(Exception('indice faltando'));
}

// Nao consegue apagar (ex.: sem internet).
class _RepositorioQueNaoApaga extends DadosMedicosRepository {
  _RepositorioQueNaoApaga(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Future<void> removerRegistro(String registroId) =>
      throw Exception('sem conexao');
}

void main() {
  group('CardExercicio Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;

    // Quarta-feira, 28/10/2026: a semana vai de domingo 25/10 a sabado 31/10.
    final hoje = DateTime(2026, 10, 28, 15, 0);
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

    Future<void> registrar(
      DateTime quando,
      int minutos, {
      String tipo = 'Caminhada',
      String intensidade = 'Moderada',
    }) {
      return dadosRepository.salvarRegistro(RegistroExercicio(
        id: '',
        pacienteId: paciente.id,
        dataHora: quando,
        tipoExercicio: tipo,
        duracaoMinutos: minutos,
        intensidade: intensidade,
      ));
    }

    Future<void> montar(
      WidgetTester tester, {
      DadosMedicosRepository? repositorio,
      double escalaTexto = 1,
      Size tamanho = const Size(800, 2800),
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
            create: (_) => ExercicioViewModel(
              paciente: paciente,
              dadosRepository: repositorio ?? dadosRepository,
              agora: () => hoje,
            ),
            child: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: CardExercicio(),
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

    // O "Apagar" da pergunta de confirmacao, e nao o de cada exercicio na
    // lista, que continua na tela por tras do dialogo. (`.icon` cria uma
    // subclasse privada de FilledButton, que o byType exato nao acha.)
    Finder confirmarApagar() => find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Apagar'),
        );

    testWidgets('Deve mostrar que ainda não há exercício e quanto falta para a meta', (
      tester,
    ) async {
      await montar(tester);

      expect(find.text('Exercício'), findsOneWidget);
      expect(find.text('Nenhum exercício hoje'), findsOneWidget);
      expect(find.text('Nesta semana: 0 de 150 min'), findsOneWidget);
      expect(find.text('Registrar exercício'), findsOneWidget);
      expect(find.text('Apagar'), findsNothing);
      expect(find.text('META DA SEMANA ATINGIDA'), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Deve listar os exercícios de hoje e somar a semana', (
      tester,
    ) async {
      await registrar(DateTime(2026, 10, 28, 7, 0), 30);
      await registrar(DateTime(2026, 10, 28, 12, 0), 45,
          tipo: 'Hidroginástica', intensidade: 'Leve');
      await registrar(DateTime(2026, 10, 26, 8, 0), 40);
      await montar(tester);

      expect(find.text('Hoje: 1 h 15 min'), findsOneWidget);
      expect(find.text('Hidroginástica'), findsOneWidget);
      expect(find.text('45 min · Leve'), findsOneWidget);
      expect(find.text('Caminhada'), findsOneWidget);
      expect(find.text('30 min · Moderada'), findsOneWidget);
      // O de segunda-feira conta na semana, mas nao aparece na lista de hoje.
      expect(find.text('40 min · Moderada'), findsNothing);
      expect(find.text('Nesta semana: 115 de 150 min'), findsOneWidget);
      expect(find.text('Apagar'), findsNWidgets(2));

      await desmontar(tester);
    });

    testWidgets('Deve mostrar a semana completa sem selo de meta', (
      tester,
    ) async {
      await registrar(DateTime(2026, 10, 26, 8, 0), 120);
      await registrar(DateTime(2026, 10, 28, 7, 0), 30);
      await montar(tester);

      expect(find.text('META DA SEMANA ATINGIDA'), findsNothing);
      expect(find.textContaining('Faltam'), findsNothing);
      expect(find.text('Nesta semana: 150 de 150 min'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve registrar um exercício pela tela própria e avisar que foi salvo', (
      tester,
    ) async {
      await montar(tester);

      await tester.tap(find.text('Registrar exercício'));
      await tester.pumpAndSettle();
      expect(find.text('1. QUE EXERCÍCIO VOCÊ FEZ?'), findsOneWidget);

      await tester.tap(find.text('Dança'));
      await tester.tap(find.text('Mais'));
      await tester.tap(find.text('Intensa'));
      await tester.pump();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      // De volta à Rotina: o aviso, e o cartão já com o exercício novo.
      expect(find.text('Exercício registrado.'), findsOneWidget);
      expect(find.text('1. QUE EXERCÍCIO VOCÊ FEZ?'), findsNothing);
      expect(find.text('Dança'), findsOneWidget);
      expect(find.text('35 min · Intensa'), findsOneWidget);
      expect(find.text('Hoje: 35 min'), findsOneWidget);
      expect(find.text('Nesta semana: 35 de 150 min'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Não deve avisar nada ao cancelar', (tester) async {
      await montar(tester);

      await tester.tap(find.text('Registrar exercício'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Exercício registrado.'), findsNothing);
      expect(find.text('Nenhum exercício hoje'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve apagar um exercício depois de confirmar', (tester) async {
      await registrar(DateTime(2026, 10, 28, 7, 0), 30);
      await montar(tester);

      await tester.tap(find.text('Apagar'));
      await tester.pumpAndSettle();
      expect(find.text('Apagar este exercício?'), findsOneWidget);
      expect(find.textContaining('Caminhada, 30 min.'), findsOneWidget);

      await tester.tap(confirmarApagar());
      await tester.pumpAndSettle();

      expect(find.text('Nenhum exercício hoje'), findsOneWidget);
      expect(find.text('Nesta semana: 0 de 150 min'), findsOneWidget);
      expect(
        (await fakeFirestore.collection('registros_diarios').get()).docs,
        isEmpty,
      );

      await desmontar(tester);
    });

    testWidgets('Não deve apagar nada se a pessoa mantiver o exercício', (
      tester,
    ) async {
      await registrar(DateTime(2026, 10, 28, 7, 0), 30);
      await montar(tester);

      await tester.tap(find.text('Apagar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manter'));
      await tester.pumpAndSettle();

      expect(find.text('Apagar este exercício?'), findsNothing);
      expect(find.text('Hoje: 30 min'), findsOneWidget);
      expect(
        (await fakeFirestore.collection('registros_diarios').get()).docs,
        hasLength(1),
      );

      await desmontar(tester);
    });

    testWidgets('Deve avisar quando não consegue apagar e manter o exercício', (
      tester,
    ) async {
      await registrar(DateTime(2026, 10, 28, 7, 0), 30);
      await montar(tester, repositorio: _RepositorioQueNaoApaga(fakeFirestore));

      await tester.tap(find.text('Apagar'));
      await tester.pumpAndSettle();
      await tester.tap(confirmarApagar());
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível apagar. Tente de novo.'),
          findsOneWidget);
      expect(find.text('Hoje: 30 min'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve esconder o resumo e desligar o botão quando a leitura falha', (
      tester,
    ) async {
      await montar(tester, repositorio: _RepositorioSemLeitura(fakeFirestore));

      expect(find.textContaining('Não foi possível carregar o seu exercício'),
          findsOneWidget);
      expect(find.text('Nenhum exercício hoje'), findsNothing);
      expect(find.textContaining('Nesta semana'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.bySubtype<FilledButton>().first)
            .onPressed,
        isNull,
      );

      await desmontar(tester);
    });

    testWidgets('Deve falar o resumo numa frase só para o leitor de tela', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await registrar(DateTime(2026, 10, 28, 7, 0), 90);
      await montar(tester);

      expect(
        find.bySemanticsLabel('Exercício: hoje 1 hora e 30 minutos. '
            'Nesta semana, 90 de 150 minutos.'),
        findsOneWidget,
      );

      await desmontar(tester);
      semantica.dispose();
    });

    testWidgets('Não estoura com a fonte do celular em 200%', (tester) async {
      // Celular pequeno (360x640) com a fonte no maximo: qualquer overflow
      // vira erro e reprova o teste.
      await registrar(DateTime(2026, 10, 28, 7, 0), 30, tipo: 'Hidroginástica');
      await montar(tester, escalaTexto: 2, tamanho: const Size(360, 640));

      expect(find.text('Exercício'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await desmontar(tester);
    });
  });
}
