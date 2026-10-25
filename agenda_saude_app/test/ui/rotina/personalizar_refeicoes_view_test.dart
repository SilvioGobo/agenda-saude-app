import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/data/repositories/alimentos_repository.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/domain/metas/metas_personalizadas.dart';
import 'package:agenda_saude_app/domain/models/item_refeicao.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/refeicao_planejada.dart';
import 'package:agenda_saude_app/domain/models/registro_refeicao.dart';
import 'package:agenda_saude_app/ui/rotina/card_refeicoes.dart';
import 'package:agenda_saude_app/ui/rotina/refeicoes_viewmodel.dart';

import '../../helpers/catalogo_de_teste.dart';

// O paciente chega a esta tela pelo botao "Personalizar refeicoes" do cartao,
// entao os testes abrem o cartao e tocam nele.
void main() {
  group('PersonalizarRefeicoesView Testes', () {
    final hoje = DateTime(2026, 10, 25, 15, 0);

    const metas = MetasPersonalizadas(
      imc: 24.7,
      classificacaoImc: ClassificacaoImc.adequado,
      hidratacaoMl: 2000,
      sonoMinHoras: 7,
      sonoMaxHoras: 9,
      passos: 8000,
      exercicioMinutosSemana: 150,
      calorias: 1800,
      carboidratosG: 225,
      proteinasG: 90,
      gordurasG: 60,
      fibrasG: 25,
      gorduraSaturadaMaxG: 20,
      acucarLivreMaxG: 45,
      sodioMaxMg: 2000,
    );

    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    late PacienteRepository pacienteRepository;
    late List<Paciente> atualizacoes;

    Paciente criarPaciente({
      bool diabetes = false,
      List<RefeicaoPlanejada>? refeicoes,
      MetasPersonalizadas? metas,
    }) {
      return Paciente(
        id: 'paciente_01',
        nome: 'José Silva',
        email: 'jose@email.com',
        perfil: 'Paciente',
        possuiDiabetes: diabetes,
        possuiCardiopatia: false,
        codigoVinculo: 'ABC123',
        refeicoes: refeicoes,
        metas: metas,
      );
    }

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
      pacienteRepository = PacienteRepository(firestore: fakeFirestore);
      atualizacoes = [];
    });

    Future<void> abrirEditor(
      WidgetTester tester, {
      Paciente? paciente,
      AlimentosRepository? alimentos,
      double escalaTexto = 1,
      Size tamanhoTela = const Size(800, 3200),
    }) async {
      tester.view.physicalSize = tamanhoTela;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final pacienteDaTela = paciente ?? criarPaciente();
      await pacienteRepository.salvarPaciente(pacienteDaTela);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(escalaTexto)),
            child: child!,
          ),
          home: ChangeNotifierProvider(
            create: (_) => RefeicoesViewModel(
              paciente: pacienteDaTela,
              dadosRepository: dadosRepository,
              pacienteRepository: pacienteRepository,
              alimentosRepository: alimentos ?? alimentosRepositoryDeTeste(),
              aoAtualizarPaciente: atualizacoes.add,
              agora: () => hoje,
            ),
            child: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: CardRefeicoes(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Personalizar refeições'));
      await tester.pumpAndSettle();
    }

    // Desmonta a tela para o ViewModel cancelar o timer da meia-noite.
    Future<void> desmontar(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
    }

    // Cada refeicao tem um campo de nome seguido de um campo de quantidade
    // por alimento.
    Finder campos() => find.byType(TextFormField);

    Future<Map<String, dynamic>> pacienteSalvo() async {
      final doc = await fakeFirestore
          .collection('usuarios')
          .doc('paciente_01')
          .get();
      return doc.data()!;
    }

    // Toca em "Adicionar alimento" da refeicao de indice [refeicao], procura
    // [busca] e escolhe o resultado de nome [nome].
    Future<void> adicionarAlimento(
      WidgetTester tester, {
      required int refeicao,
      required String busca,
      required String nome,
    }) async {
      final botao = find.text('Adicionar alimento').at(refeicao);
      await tester.ensureVisible(botao);
      await tester.tap(botao);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), busca);
      await tester.pumpAndSettle();
      await tester.tap(find.text(nome));
      await tester.pumpAndSettle();
    }

    final planoComAlimentos = [
      const RefeicaoPlanejada(
        id: 'cafe',
        nome: 'Café',
        itens: [
          ItemRefeicao(
            alimentoId: idPaoFrances,
            nome: 'Pão, trigo, francês',
            quantidadeG: 50,
          ),
          ItemRefeicao(
            alimentoId: idBananaPrata,
            nome: 'Banana, prata, crua',
            quantidadeG: 100,
          ),
        ],
      ),
      const RefeicaoPlanejada(id: 'almoco', nome: 'Almoço'),
    ];

    testWidgets('Deve abrir com o nome de cada refeição do plano', (
      tester,
    ) async {
      await abrirEditor(tester);

      expect(find.text('Minhas refeições'), findsOneWidget);
      expect(find.text('Voltar'), findsOneWidget);
      expect(campos(), findsNWidgets(4));
      expect(find.text('Café da manhã'), findsOneWidget);
      expect(find.text('Almoço'), findsOneWidget);
      expect(find.text('Jantar'), findsOneWidget);
      expect(find.text('Adicionar alimento'), findsNWidgets(4));
      expect(find.text('Remover refeição'), findsNWidgets(4));
      expect(find.text('Adicionar refeição'), findsOneWidget);
      expect(find.text('Voltar ao padrão'), findsOneWidget);
      expect(find.text('Salvar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      // Sem alimentos ainda nao ha o que somar.
      expect(find.text('Seu dia com estas refeições'), findsNothing);

      await desmontar(tester);
    });

    testWidgets(
      'Deve mostrar os alimentos já cadastrados com quantidade e nutrientes',
      (tester) async {
        await abrirEditor(
          tester,
          paciente: criarPaciente(refeicoes: planoComAlimentos),
        );

        // 4 campos: nome do cafe, 2 quantidades, nome do almoco.
        expect(campos(), findsNWidgets(4));
        expect(find.text('Pão, trigo, francês'), findsOneWidget);
        expect(find.text('Banana, prata, crua'), findsOneWidget);
        expect(find.text('50'), findsOneWidget);
        expect(find.text('100'), findsOneWidget);
        // 50 g de pao: 150 kcal; 100 g de banana: 98 kcal.
        expect(
          find.text(
            '150 kcal · carboidratos 29 g · proteínas 4 g · gorduras 2 g',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            '98 kcal · carboidratos 26 g · proteínas 1 g · gorduras 0 g',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Total da refeição: 248 kcal · carboidratos 55 g · proteínas 5 g · gorduras 2 g',
          ),
          findsOneWidget,
        );

        await desmontar(tester);
      },
    );

    testWidgets('Deve mostrar o dia inteiro frente às metas', (tester) async {
      await abrirEditor(
        tester,
        paciente: criarPaciente(refeicoes: planoComAlimentos, metas: metas),
      );

      expect(find.text('Seu dia com estas refeições'), findsOneWidget);
      expect(find.text('248 de 1.800 kcal'), findsOneWidget);
      expect(find.text('55 de 225 g'), findsOneWidget);
      expect(find.text('324 de 2.000 mg (limite)'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets(
      'Deve adicionar um alimento pela busca, com 100 g, e mostrar os nutrientes',
      (tester) async {
        await abrirEditor(tester);

        await adicionarAlimento(
          tester,
          refeicao: 1,
          busca: 'arroz tipo 1 cozido',
          nome: 'Arroz, tipo 1, cozido',
        );

        expect(find.text('Escolher alimento'), findsNothing);
        expect(find.text('Minhas refeições'), findsOneWidget);
        expect(find.text('Arroz, tipo 1, cozido'), findsOneWidget);
        expect(find.text('100'), findsOneWidget);
        expect(
          find.text(
            '128 kcal · carboidratos 28 g · proteínas 3 g · gorduras 0 g',
          ),
          findsOneWidget,
        );
        expect(find.text('Seu dia com estas refeições'), findsOneWidget);

        await desmontar(tester);
      },
    );

    testWidgets('Deve recalcular os totais ao mudar a quantidade', (
      tester,
    ) async {
      await abrirEditor(tester);
      await adicionarAlimento(
        tester,
        refeicao: 1,
        busca: 'arroz tipo 1 cozido',
        nome: 'Arroz, tipo 1, cozido',
      );

      await tester.enterText(campos().at(2), '200');
      await tester.pump();

      expect(
        find.text(
          '256 kcal · carboidratos 56 g · proteínas 5 g · gorduras 0 g',
        ),
        findsOneWidget,
      );
      expect(find.text('256 kcal'), findsOneWidget); // linha do resumo do dia

      await tester.enterText(campos().at(2), '62,5');
      await tester.pump();

      expect(
        find.text('80 kcal · carboidratos 18 g · proteínas 2 g · gorduras 0 g'),
        findsOneWidget,
      );

      await desmontar(tester);
    });

    testWidgets('Deve gravar os alimentos ao salvar e mostrá-los na rotina', (
      tester,
    ) async {
      await abrirEditor(tester);
      await adicionarAlimento(
        tester,
        refeicao: 1,
        busca: 'feijao carioca',
        nome: 'Feijão, carioca, cozido',
      );
      await tester.enterText(campos().at(2), '120');

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      // De volta a rotina, com o alimento e as calorias (76 kcal x 1,2).
      expect(find.text('Minhas refeições'), findsNothing);
      expect(find.text('Feijão, carioca, cozido - 120 g'), findsOneWidget);
      expect(find.text('91 kcal'), findsOneWidget);

      final salvo = await pacienteSalvo();
      final almoco = (salvo['refeicoes'] as List).cast<Map>()[1];
      expect(almoco['id'], 'almoco');
      final item = (almoco['itens'] as List).cast<Map>().single;
      expect(item['alimentoId'], idFeijaoCarioca);
      expect(item['nome'], 'Feijão, carioca, cozido');
      expect(item['quantidadeG'], 120);
      expect(atualizacoes.single.planoDeRefeicoes[1].itens.length, 1);

      await desmontar(tester);
    });

    testWidgets('Deve tirar um alimento sem trocar a quantidade dos outros', (
      tester,
    ) async {
      await abrirEditor(tester);
      await adicionarAlimento(
        tester,
        refeicao: 1,
        busca: 'arroz tipo 1 cozido',
        nome: 'Arroz, tipo 1, cozido',
      );
      await adicionarAlimento(
        tester,
        refeicao: 1,
        busca: 'feijao carioca',
        nome: 'Feijão, carioca, cozido',
      );
      await tester.enterText(campos().at(2), '150'); // arroz
      await tester.enterText(campos().at(3), '80'); // feijao
      await tester.pump();

      await tester.tap(find.text('Tirar').first); // tira o arroz
      await tester.pumpAndSettle();

      expect(find.text('Arroz, tipo 1, cozido'), findsNothing);
      expect(find.text('Feijão, carioca, cozido'), findsOneWidget);
      // O campo que sobrou mostra a quantidade do feijao, nao a do arroz.
      expect(find.text('80'), findsOneWidget);
      expect(find.text('150'), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Não deve salvar com quantidade em branco ou zero', (
      tester,
    ) async {
      await abrirEditor(
        tester,
        paciente: criarPaciente(refeicoes: planoComAlimentos),
      );

      await tester.enterText(campos().at(1), '');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Informe a quantidade de cada alimento em gramas, de 1 a 2000.',
        ),
        findsOneWidget,
      );
      expect(find.text('Minhas refeições'), findsOneWidget);

      await tester.enterText(campos().at(1), '0');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Minhas refeições'), findsOneWidget);

      await tester.enterText(campos().at(1), '55');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Minhas refeições'), findsNothing);

      await desmontar(tester);
    });

    testWidgets(
      'Deve avisar e travar a escolha de alimentos se o catálogo não carregar',
      (tester) async {
        await abrirEditor(
          tester,
          alimentos: AlimentosRepository(
            lerTexto: () async => throw Exception('sem arquivo'),
          ),
        );

        expect(
          find.textContaining('A lista de alimentos não está disponível agora'),
          findsOneWidget,
        );
        final botao = tester.widget<OutlinedButton>(
          find.ancestor(
            of: find.text('Adicionar alimento').first,
            matching: find.bySubtype<OutlinedButton>(),
          ),
        );
        expect(botao.onPressed, isNull);
        // Ainda da para mudar os nomes.
        await tester.enterText(campos().at(0), 'Café reforçado');
        await tester.tap(find.text('Salvar'));
        await tester.pumpAndSettle();
        expect(find.text('Café reforçado'), findsOneWidget);

        await desmontar(tester);
      },
    );

    testWidgets('Deve renomear uma refeição e salvar', (tester) async {
      await abrirEditor(tester);

      await tester.enterText(campos().at(0), 'Café reforçado');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Minhas refeições'), findsNothing);
      expect(find.text('Café reforçado'), findsOneWidget);
      expect(find.text('Café da manhã'), findsNothing);

      final salvo = await pacienteSalvo();
      final refeicoes = (salvo['refeicoes'] as List).cast<Map>();
      expect(refeicoes.length, 4);
      expect(refeicoes.first['id'], 'cafe_da_manha');
      expect(refeicoes.first['nome'], 'Café reforçado');
      expect(atualizacoes.single.planoDeRefeicoes.first.nome, 'Café reforçado');

      await desmontar(tester);
    });

    testWidgets('Deve manter a refeição como feita depois de renomeá-la', (
      tester,
    ) async {
      await dadosRepository.salvarRegistro(
        RegistroRefeicao(
          id: '',
          pacienteId: 'paciente_01',
          dataHora: DateTime(2026, 10, 25, 12),
          refeicaoId: 'almoco',
          nome: 'Almoço',
        ),
      );
      await abrirEditor(tester);

      await tester.enterText(campos().at(1), 'Almoço em família');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Almoço em família'), findsOneWidget);
      expect(find.text('Feito'), findsOneWidget);
      expect(find.text('1 de 4 feitas'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve adicionar uma refeição nova e salvar', (tester) async {
      await abrirEditor(tester);

      await tester.tap(find.text('Adicionar refeição'));
      await tester.pumpAndSettle();
      expect(campos(), findsNWidgets(5));

      await tester.enterText(campos().at(4), 'Ceia');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Ceia'), findsOneWidget);
      expect(find.text('0 de 5 feitas'), findsOneWidget);
      final refeicoes = ((await pacienteSalvo())['refeicoes'] as List);
      expect(refeicoes.length, 5);

      await desmontar(tester);
    });

    testWidgets('Deve remover uma refeição e salvar', (tester) async {
      await abrirEditor(tester);

      await tester.tap(find.text('Remover refeição').first);
      await tester.pumpAndSettle();
      expect(campos(), findsNWidgets(3));

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Café da manhã'), findsNothing);
      expect(find.text('0 de 3 feitas'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Não deve salvar uma refeição sem nome', (tester) async {
      await abrirEditor(tester);

      await tester.tap(find.text('Adicionar refeição'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Dê um nome para todas as refeições.'), findsOneWidget);
      expect(find.text('Minhas refeições'), findsOneWidget);
      expect((await pacienteSalvo())['refeicoes'], isNull);

      // O aviso some quando o nome e digitado.
      await tester.enterText(campos().at(4), 'Ceia');
      await tester.pump();
      expect(find.text('Dê um nome para todas as refeições.'), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Não deve salvar um plano sem nenhuma refeição', (
      tester,
    ) async {
      await abrirEditor(tester);

      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Remover refeição').first);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Deixe pelo menos uma refeição.'), findsOneWidget);
      expect(campos(), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Cancelar não deve mudar nem gravar nada', (tester) async {
      await abrirEditor(tester);

      await tester.enterText(campos().at(0), 'Outro nome');
      await adicionarAlimento(
        tester,
        refeicao: 1,
        busca: 'arroz tipo 1 cozido',
        nome: 'Arroz, tipo 1, cozido',
      );
      await tester.tap(find.text('Remover refeição').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Minhas refeições'), findsNothing);
      expect(find.text('Café da manhã'), findsOneWidget);
      expect(find.text('0 de 4 feitas'), findsOneWidget);
      expect((await pacienteSalvo())['refeicoes'], isNull);
      expect(atualizacoes, isEmpty);

      await desmontar(tester);
    });

    testWidgets(
      'Voltar ao padrão deve restaurar as refeições e tirar os alimentos',
      (tester) async {
        await abrirEditor(
          tester,
          paciente: criarPaciente(refeicoes: planoComAlimentos),
        );
        expect(find.text('Pão, trigo, francês'), findsOneWidget);

        await tester.tap(find.text('Voltar ao padrão'));
        await tester.pumpAndSettle();

        expect(campos(), findsNWidgets(4));
        expect(find.text('Café da manhã'), findsOneWidget);
        expect(find.text('Jantar'), findsOneWidget);
        expect(find.text('Pão, trigo, francês'), findsNothing);

        await desmontar(tester);
      },
    );

    testWidgets('Não deve deixar passar do máximo de refeições', (
      tester,
    ) async {
      await abrirEditor(tester, paciente: criarPaciente(diabetes: true));
      expect(campos(), findsNWidgets(6));

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Adicionar refeição'));
        await tester.pumpAndSettle();
      }

      expect(campos(), findsNWidgets(8));
      expect(find.textContaining('máximo de 8 refeições'), findsOneWidget);
      final botao = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Adicionar refeição'),
          matching: find.bySubtype<OutlinedButton>(),
        ),
      );
      expect(botao.onPressed, isNull);

      await desmontar(tester);
    });

    testWidgets('Não deve estourar o layout com a fonte do celular em 200%', (
      tester,
    ) async {
      await abrirEditor(
        tester,
        paciente: criarPaciente(refeicoes: planoComAlimentos, metas: metas),
        escalaTexto: 2,
        tamanhoTela: const Size(360, 740),
      );

      expect(tester.takeException(), isNull);

      await desmontar(tester);
    });
  });
}
