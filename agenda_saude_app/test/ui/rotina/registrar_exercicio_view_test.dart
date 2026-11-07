import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/theme/app_theme.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_base.dart';
import 'package:agenda_saude_app/ui/rotina/registrar_exercicio_view.dart';
import 'package:agenda_saude_app/ui/rotina/registrar_exercicio_viewmodel.dart';

// Nao consegue gravar (ex.: sem internet).
class _RepositorioQueFalha extends DadosMedicosRepository {
  _RepositorioQueFalha(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Future<void> salvarRegistro(RegistroBase registro) =>
      throw Exception('sem conexao');
}

void main() {
  group('RegistrarExercicioView Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    bool? resultado;

    final agora = DateTime(2026, 10, 25, 7, 30);
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
      resultado = null;
    });

    // Abre a tela por cima de outra, como o cartao da rotina faz, e guarda o
    // que ela devolve ao fechar. A tela de teste e alta para tudo ficar visivel.
    Future<void> abrir(
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
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  resultado = await Navigator.of(context).push(
                    RegistrarExercicioView.rota(
                      RegistrarExercicioViewModel(
                        paciente: paciente,
                        dadosRepository: repositorio ?? dadosRepository,
                        agora: () => agora,
                      ),
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
    }

    Future<List<Map<String, dynamic>>> gravados() async {
      final snapshot = await fakeFirestore.collection('registros_diarios').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    }

    Finder checkNo(String rotulo) => find.descendant(
          of: find.widgetWithText(OutlinedButton, rotulo),
          matching: find.byIcon(Icons.check_rounded),
        );

    testWidgets('Deve mostrar as três perguntas, os exercícios e as intensidades', (
      tester,
    ) async {
      await abrir(tester);

      expect(find.text('Registrar exercício'), findsOneWidget);
      expect(find.text('1. QUE EXERCÍCIO VOCÊ FEZ?'), findsOneWidget);
      for (final tipo in [
        'Caminhada',
        'Alongamento',
        'Hidroginástica',
        'Dança',
        'Bicicleta',
        'Fortalecimento',
        'Pilates ou yoga',
        'Outro',
      ]) {
        expect(find.text(tipo), findsOneWidget);
      }
      expect(find.text('2. POR QUANTO TEMPO?'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
      expect(find.text('3. COMO FOI A INTENSIDADE?'), findsOneWidget);
      expect(find.text('Leve'), findsOneWidget);
      expect(find.text('Moderada'), findsOneWidget);
      expect(find.text('Intensa'), findsOneWidget);
      expect(find.text('SALVAR'), findsOneWidget);
    });

    testWidgets('Deve explicar cada intensidade pelo teste da conversa', (
      tester,
    ) async {
      await abrir(tester);

      expect(find.text('Dá para conversar e até cantar.'), findsOneWidget);
      expect(find.text('Dá para conversar, mas não para cantar.'),
          findsOneWidget);
      expect(find.text('Só dá para falar frases curtas.'), findsOneWidget);
    });

    testWidgets('Deve mudar os minutos de 5 em 5', (tester) async {
      await abrir(tester);

      await tester.tap(find.text('Mais'));
      await tester.pump();
      expect(find.text('35 min'), findsOneWidget);

      await tester.tap(find.text('Menos'));
      await tester.tap(find.text('Menos'));
      await tester.pump();
      expect(find.text('25 min'), findsOneWidget);
    });

    testWidgets('Deve pedir o exercício e a intensidade ao salvar sem escolher', (
      tester,
    ) async {
      await abrir(tester);

      await tester.tap(find.text('SALVAR'));
      await tester.pumpAndSettle();

      expect(find.text('ESCOLHA QUAL EXERCÍCIO VOCÊ FEZ.'), findsOneWidget);
      expect(find.text('ESCOLHA COMO FOI A INTENSIDADE.'), findsOneWidget);
      expect(find.text('Registrar exercício'), findsOneWidget);
      expect(resultado, isNull);
      expect(await gravados(), isEmpty);
    });

    testWidgets('Deve marcar com um check o exercício e a intensidade escolhidos', (
      tester,
    ) async {
      await abrir(tester);

      await tester.tap(find.text('Dança'));
      await tester.tap(find.text('Moderada'));
      await tester.pump();

      expect(checkNo('Dança'), findsOneWidget);
      expect(checkNo('Moderada'), findsOneWidget);
      expect(checkNo('Caminhada'), findsNothing);
      expect(checkNo('Leve'), findsNothing);
    });

    testWidgets('Deve salvar o exercício e fechar devolvendo true', (tester) async {
      await abrir(tester);

      await tester.tap(find.text('Caminhada'));
      await tester.tap(find.text('Mais'));
      await tester.tap(find.text('Leve'));
      await tester.pump();
      await tester.tap(find.text('SALVAR'));
      await tester.pumpAndSettle();

      expect(resultado, isTrue);
      expect(find.text('Registrar exercício'), findsNothing);
      final dados = (await gravados()).single;
      expect(dados['tipo'], 'exercicio');
      expect(dados['tipoExercicio'], 'Caminhada');
      expect(dados['duracaoMinutos'], 35);
      expect(dados['intensidade'], 'Leve');
    });

    testWidgets('Deve voltar sem salvar ao tocar em "Voltar"', (tester) async {
      await abrir(tester);

      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();

      expect(resultado, isFalse);
      expect(find.text('Registrar exercício'), findsNothing);
      expect(await gravados(), isEmpty);
    });

    testWidgets('Deve avisar quando não consegue gravar e manter a tela aberta', (
      tester,
    ) async {
      await abrir(tester, repositorio: _RepositorioQueFalha(fakeFirestore));

      await tester.tap(find.text('Caminhada'));
      await tester.tap(find.text('Leve'));
      await tester.pump();
      await tester.tap(find.text('SALVAR'));
      await tester.pumpAndSettle();

      expect(find.text('NÃO FOI POSSÍVEL SALVAR. TENTE DE NOVO.'),
          findsOneWidget);
      expect(find.text('Registrar exercício'), findsOneWidget);
      expect(resultado, isNull);
    });

    testWidgets('Não estoura com a fonte do celular em 200%', (tester) async {
      // Celular pequeno (360x640) com a fonte no maximo: qualquer overflow
      // vira erro e reprova o teste.
      await abrir(tester, escalaTexto: 2, tamanho: const Size(360, 640));

      await tester.scrollUntilVisible(
        find.text('SALVAR'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('SALVAR'));
      await tester.pumpAndSettle();

      expect(find.text('SALVAR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
