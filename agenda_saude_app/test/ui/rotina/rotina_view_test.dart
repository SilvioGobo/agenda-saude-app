import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_agua.dart';
import 'package:agenda_saude_app/ui/rotina/hidratacao_viewmodel.dart';
import 'package:agenda_saude_app/ui/rotina/rotina_view.dart';

// Leitura do dia que sempre falha (ex.: indice composto ainda nao publicado).
class _RepositorioSemLeitura extends DadosMedicosRepository {
  _RepositorioSemLeitura(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Stream<List<RegistroAgua>> streamAguaDoDia(String pacienteId, DateTime dia) =>
      Stream.error(Exception('indice faltando'));
}

void main() {
  group('RotinaView Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;

    final paciente = Paciente(
      id: 'paciente_01',
      nome: 'José Silva',
      email: 'jose@email.com',
      perfil: 'Paciente',
      possuiDiabetes: false,
      possuiCardiopatia: false,
      codigoVinculo: 'ABC123',
    );
    final hoje = DateTime(2026, 10, 25, 15, 0);

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
    });

    Future<void> montar(
      WidgetTester tester, {
      DadosMedicosRepository? repositorio,
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
          home: ChangeNotifierProvider(
            create: (_) => HidratacaoViewModel(
              paciente: paciente,
              dadosRepository: repositorio ?? dadosRepository,
              agora: () => hoje,
            ),
            child: const RotinaView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Desmonta a tela para o ViewModel cancelar o timer da meia-noite.
    Future<void> desmontar(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
    }

    Future<void> salvarCopos(int quantidade) async {
      for (var i = 0; i < quantidade; i++) {
        await dadosRepository.salvarRegistro(RegistroAgua(
          id: '',
          pacienteId: paciente.id,
          dataHora: DateTime(2026, 10, 25, 6 + i, 0),
          quantidadeML: 250,
        ));
      }
    }

    // `.icon` cria uma subclasse privada, que o byType exato nao acha.
    Finder botaoMais() => find.bySubtype<FilledButton>();
    Finder botaoMenos() => find.bySubtype<OutlinedButton>();

    testWidgets('Deve mostrar o título, a hidratação zerada e o botão de tirar copo desativado',
        (tester) async {
      await montar(tester);

      expect(find.text('Voltar'), findsOneWidget);
      expect(find.text('Minha Rotina'), findsOneWidget);
      expect(find.text('Hidratação'), findsOneWidget);
      expect(find.text('0 de 8 copos'), findsOneWidget);
      expect(find.text('0 ml de 2000 ml'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(botaoMenos()).onPressed, isNull);
      expect(tester.widget<FilledButton>(botaoMais()).onPressed, isNotNull);
      expect(find.text('META DE HOJE ATINGIDA'), findsNothing);
      // Paciente sem diabetes na triagem não vê glicemia/insulina (RF008).
      expect(find.text('Glicemia e Insulina'), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Deve somar um copo ao tocar em "+ Copo" e gravar no Firestore',
        (tester) async {
      await montar(tester);

      await tester.tap(botaoMais());
      await tester.pumpAndSettle();

      expect(find.text('1 de 8 copos'), findsOneWidget);
      expect(find.text('250 ml de 2000 ml'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(botaoMenos()).onPressed, isNotNull);

      final salvos = await fakeFirestore.collection('registros_diarios').get();
      expect(salvos.docs.length, 1);

      await desmontar(tester);
    });

    testWidgets('Deve tirar um copo ao tocar em "- Copo"', (tester) async {
      await salvarCopos(3);
      await montar(tester);
      expect(find.text('3 de 8 copos'), findsOneWidget);

      await tester.tap(botaoMenos());
      await tester.pumpAndSettle();

      expect(find.text('2 de 8 copos'), findsOneWidget);
      expect(find.text('500 ml de 2000 ml'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar o progresso salvo ao abrir a tela', (tester) async {
      await salvarCopos(5);
      await montar(tester);

      expect(find.text('5 de 8 copos'), findsOneWidget);
      final barra = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(barra.value, closeTo(5 / 8, 0.0001));

      await desmontar(tester);
    });

    testWidgets('Deve avisar que a meta do dia foi atingida', (tester) async {
      await salvarCopos(7);
      await montar(tester);
      expect(find.text('META DE HOJE ATINGIDA'), findsNothing);

      await tester.tap(botaoMais());
      await tester.pumpAndSettle();

      expect(find.text('8 de 8 copos'), findsOneWidget);
      expect(find.text('META DE HOJE ATINGIDA'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve esconder o progresso e os botões se não conseguir ler a hidratação',
        (tester) async {
      await montar(tester, repositorio: _RepositorioSemLeitura(fakeFirestore));

      expect(find.textContaining('Não foi possível carregar'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(botaoMais(), findsNothing);
      expect(botaoMenos(), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Deve falar o progresso e o que cada botão faz para o leitor de tela',
        (tester) async {
      final semantica = tester.ensureSemantics();
      await salvarCopos(2);
      await montar(tester);

      expect(
        find.bySemanticsLabel('Hidratação: 2 de 8 copos, 500 de 2000 mililitros.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Adicionar um copo de água'), findsOneWidget);
      expect(find.bySemanticsLabel('Tirar um copo de água'), findsOneWidget);

      await desmontar(tester);
      semantica.dispose();
    });

    testWidgets('Não deve estourar o layout com a fonte do celular em 200%',
        (tester) async {
      await salvarCopos(8);
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await montar(tester, escalaTexto: 2);

      expect(tester.takeException(), isNull);
      expect(find.text('8 de 8 copos'), findsOneWidget);
      // Com a fonte grande os botões ficam um embaixo do outro, ambos visíveis.
      expect(botaoMais(), findsOneWidget);
      expect(botaoMenos(), findsOneWidget);
      expect(
        tester.getTopLeft(botaoMais()).dx,
        tester.getTopLeft(botaoMenos()).dx,
      );

      await desmontar(tester);
    });

    testWidgets('Deve voltar para a tela anterior ao tocar em "Voltar"',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider(
                      create: (_) => HidratacaoViewModel(
                        paciente: paciente,
                        dadosRepository: dadosRepository,
                        agora: () => hoje,
                      ),
                      child: const RotinaView(),
                    ),
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Minha Rotina'), findsOneWidget);

      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('Minha Rotina'), findsNothing);
      expect(find.text('Abrir'), findsOneWidget);
    });
  });
}
