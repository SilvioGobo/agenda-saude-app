import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/domain/metas/metas_personalizadas.dart';
import 'package:agenda_saude_app/domain/models/item_refeicao.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/refeicao_planejada.dart';
import 'package:agenda_saude_app/domain/models/registro_base.dart';
import 'package:agenda_saude_app/domain/models/registro_refeicao.dart';
import 'package:agenda_saude_app/ui/rotina/card_refeicoes.dart';
import 'package:agenda_saude_app/ui/rotina/refeicoes_viewmodel.dart';

import '../../helpers/catalogo_de_teste.dart';

// Leitura do dia que sempre falha (ex.: indice composto ainda nao publicado).
class _RepositorioSemLeitura extends DadosMedicosRepository {
  _RepositorioSemLeitura(FakeFirebaseFirestore firestore)
    : super(firestore: firestore);

  @override
  Stream<List<RegistroRefeicao>> streamRefeicoesDoDia(
    String pacienteId,
    DateTime dia,
  ) => Stream.error(Exception('indice faltando'));
}

class _RepositorioQueFalha extends DadosMedicosRepository {
  _RepositorioQueFalha(FakeFirebaseFirestore firestore)
    : super(firestore: firestore);

  @override
  Future<void> salvarRegistro(RegistroBase registro) {
    throw Exception('sem conexao');
  }
}

void main() {
  group('CardRefeicoes Testes', () {
    final hoje = DateTime(2026, 10, 25, 15, 0);

    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    late PacienteRepository pacienteRepository;

    // Cafe (50 g de pao + 100 g de banana): 248 kcal. Almoco (150 g de arroz +
    // 100 g de feijao + 100 g de frango): 427 kcal. Ceia: sem alimentos.
    const planoComAlimentos = [
      RefeicaoPlanejada(
        id: 'cafe',
        nome: 'Café',
        itens: [
          ItemRefeicao(alimentoId: idPaoFrances, nome: 'Pão', quantidadeG: 50),
          ItemRefeicao(
            alimentoId: idBananaPrata,
            nome: 'Banana',
            quantidadeG: 100,
          ),
        ],
      ),
      RefeicaoPlanejada(
        id: 'almoco',
        nome: 'Almoço',
        itens: [
          ItemRefeicao(
            alimentoId: idArrozCozido,
            nome: 'Arroz',
            quantidadeG: 150,
          ),
          ItemRefeicao(
            alimentoId: idFeijaoCarioca,
            nome: 'Feijão',
            quantidadeG: 100,
          ),
          ItemRefeicao(
            alimentoId: idFrangoGrelhado,
            nome: 'Frango',
            quantidadeG: 100,
          ),
        ],
      ),
      RefeicaoPlanejada(id: 'ceia', nome: 'Ceia'),
    ];

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
    });

    // Tela alta para a lista inteira ser construida sem rolar.
    Future<void> montar(
      WidgetTester tester, {
      Paciente? paciente,
      DadosMedicosRepository? dados,
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
              dadosRepository: dados ?? dadosRepository,
              pacienteRepository: pacienteRepository,
              alimentosRepository: alimentosRepositoryDeTeste(),
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
    }

    // Desmonta a tela para o ViewModel cancelar o timer da meia-noite.
    Future<void> desmontar(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
    }

    Future<void> marcarNoBanco(String refeicaoId, String nome) {
      return dadosRepository.salvarRegistro(
        RegistroRefeicao(
          id: '',
          pacienteId: 'paciente_01',
          dataHora: DateTime(2026, 10, 25, 9),
          refeicaoId: refeicaoId,
          nome: nome,
        ),
      );
    }

    testWidgets('Deve mostrar o plano padrão com nenhuma refeição feita', (
      tester,
    ) async {
      await montar(tester);

      expect(find.text('Refeições'), findsOneWidget);
      expect(find.text('0 de 4 feitas'), findsOneWidget);
      expect(find.text('Café da manhã'), findsOneWidget);
      expect(find.text('Almoço'), findsOneWidget);
      expect(find.text('Lanche da tarde'), findsOneWidget);
      expect(find.text('Jantar'), findsOneWidget);
      expect(find.text('Ainda não feito'), findsNWidgets(4));
      expect(find.text('Feito'), findsNothing);
      expect(find.text('Personalizar refeições'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar seis refeições para quem tem diabetes', (
      tester,
    ) async {
      await montar(tester, paciente: criarPaciente(diabetes: true));

      expect(find.text('0 de 6 feitas'), findsOneWidget);
      expect(find.text('Lanche da manhã'), findsOneWidget);
      expect(find.text('Ceia'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve marcar a refeição como feita ao tocar nela e gravar', (
      tester,
    ) async {
      await montar(tester);

      await tester.tap(find.text('Almoço'));
      await tester.pumpAndSettle();

      expect(find.text('Feito'), findsOneWidget);
      expect(find.text('Ainda não feito'), findsNWidgets(3));
      expect(find.text('1 de 4 feitas'), findsOneWidget);

      final salvos = await fakeFirestore.collection('registros_diarios').get();
      expect(salvos.docs.single.data()['refeicaoId'], 'almoco');
      expect(salvos.docs.single.data()['tipo'], 'refeicao');

      await desmontar(tester);
    });

    testWidgets('Deve desmarcar a refeição ao tocar nela de novo', (
      tester,
    ) async {
      await marcarNoBanco('almoco', 'Almoço');
      await montar(tester);
      expect(find.text('1 de 4 feitas'), findsOneWidget);

      await tester.tap(find.text('Almoço'));
      await tester.pumpAndSettle();

      expect(find.text('Feito'), findsNothing);
      expect(find.text('0 de 4 feitas'), findsOneWidget);
      final salvos = await fakeFirestore.collection('registros_diarios').get();
      expect(salvos.docs, isEmpty);

      await desmontar(tester);
    });

    testWidgets('Deve avisar quando todas as refeições do dia foram feitas', (
      tester,
    ) async {
      await montar(tester);
      expect(find.text('REFEIÇÕES DE HOJE FEITAS'), findsNothing);

      for (final nome in [
        'Café da manhã',
        'Almoço',
        'Lanche da tarde',
        'Jantar',
      ]) {
        await tester.tap(find.text(nome));
        await tester.pumpAndSettle();
      }

      expect(find.text('4 de 4 feitas'), findsOneWidget);
      expect(find.text('REFEIÇÕES DE HOJE FEITAS'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar os alimentos e as calorias de cada refeição', (
      tester,
    ) async {
      await montar(
        tester,
        paciente: criarPaciente(refeicoes: planoComAlimentos),
      );

      expect(find.text('Café'), findsOneWidget);
      expect(find.text('Pão - 50 g'), findsOneWidget);
      expect(find.text('Banana - 100 g'), findsOneWidget);
      expect(find.text('248 kcal'), findsOneWidget);
      expect(find.text('Arroz - 150 g'), findsOneWidget);
      expect(find.text('427 kcal'), findsOneWidget);
      // A ceia ainda nao tem alimentos: sem calorias.
      expect(find.text('Ceia'), findsOneWidget);
      expect(find.text('0 de 3 feitas'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve resumir só o que já foi comido hoje frente às metas', (
      tester,
    ) async {
      await marcarNoBanco('cafe', 'Café');
      await montar(
        tester,
        paciente: criarPaciente(refeicoes: planoComAlimentos, metas: metas),
      );

      expect(find.text('O que você já comeu hoje'), findsOneWidget);
      // So o cafe (50 g de pao + 100 g de banana) foi feito.
      expect(find.text('248 de 1.800 kcal'), findsOneWidget);
      expect(find.text('55 de 225 g'), findsOneWidget);
      expect(find.text('5 de 90 g'), findsOneWidget);
      expect(find.text('2 de 60 g'), findsOneWidget);
      expect(find.text('324 de 2.000 mg (limite)'), findsOneWidget);
      expect(find.text('Acima do limite'), findsNothing);

      await tester.tap(find.text('Almoço'));
      await tester.pumpAndSettle();

      expect(find.text('675 de 1.800 kcal'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets(
      'Deve mostrar o resumo sem metas quando a conta não tem metas',
      (tester) async {
        await marcarNoBanco('cafe', 'Café');
        await montar(
          tester,
          paciente: criarPaciente(refeicoes: planoComAlimentos),
        );

        expect(find.text('O que você já comeu hoje'), findsOneWidget);
        expect(
          find.text('248 kcal'),
          findsNWidgets(2),
        ); // na refeicao e no resumo
        expect(find.textContaining(' de 1.800'), findsNothing);

        await desmontar(tester);
      },
    );

    testWidgets('Deve avisar por escrito quando o sódio passa do limite', (
      tester,
    ) async {
      await marcarNoBanco('sal', 'Tempero');
      await montar(
        tester,
        paciente: criarPaciente(
          metas: metas,
          refeicoes: const [
            RefeicaoPlanejada(
              id: 'sal',
              nome: 'Tempero',
              itens: [
                ItemRefeicao(
                  alimentoId: 517,
                  nome: 'Sal, grosso',
                  quantidadeG: 10,
                ),
              ],
            ),
          ],
        ),
      );

      // 10 g de sal grosso: 3.994 mg de sodio, acima do limite de 2.000 mg.
      expect(find.text('3.994 de 2.000 mg (limite)'), findsOneWidget);
      expect(find.text('Acima do limite'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets(
      'Deve explicar como ver as calorias quando não há alimentos cadastrados',
      (tester) async {
        await montar(tester);

        expect(
          find.textContaining('Cadastre os alimentos de cada refeição'),
          findsOneWidget,
        );
        expect(find.text('O que você já comeu hoje'), findsNothing);

        await desmontar(tester);
      },
    );

    testWidgets('Deve mostrar só os primeiros alimentos e contar os outros', (
      tester,
    ) async {
      await montar(
        tester,
        paciente: criarPaciente(
          refeicoes: [
            RefeicaoPlanejada(
              id: 'r1',
              nome: 'Almoço grande',
              itens: [
                for (var i = 1; i <= 6; i++)
                  ItemRefeicao(
                    alimentoId: idArrozCozido,
                    nome: 'Alimento $i',
                    quantidadeG: 10,
                  ),
              ],
            ),
          ],
        ),
      );

      expect(find.text('Alimento 4 - 10 g'), findsOneWidget);
      expect(find.text('Alimento 5 - 10 g'), findsNothing);
      expect(find.text('e mais 2 alimentos'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve explicar quando o plano não tem nenhuma refeição', (
      tester,
    ) async {
      await montar(tester, paciente: criarPaciente(refeicoes: const []));

      expect(
        find.textContaining('Você ainda não tem refeições'),
        findsOneWidget,
      );
      expect(find.text('REFEIÇÕES DE HOJE FEITAS'), findsNothing);
      expect(find.text('Personalizar refeições'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve esconder as refeições se não conseguir ler o dia', (
      tester,
    ) async {
      await montar(tester, dados: _RepositorioSemLeitura(fakeFirestore));

      expect(find.textContaining('Não foi possível carregar'), findsOneWidget);
      expect(find.text('Almoço'), findsNothing);
      expect(find.text('0 de 4 feitas'), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar erro quando não consegue marcar a refeição', (
      tester,
    ) async {
      await montar(tester, dados: _RepositorioQueFalha(fakeFirestore));

      await tester.tap(find.text('Almoço'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Não foi possível salvar'), findsOneWidget);
      expect(find.text('Feito'), findsNothing);

      await desmontar(tester);
    });

    testWidgets(
      'Deve falar o estado e a ação de cada refeição para o leitor de tela',
      (tester) async {
        final semantica = tester.ensureSemantics();
        await marcarNoBanco('jantar', 'Jantar');
        await montar(tester);

        expect(
          find.bySemanticsLabel(
            'Almoço, ainda não feita. Toque para marcar como feita.',
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Jantar, feita. Toque para desmarcar.'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Refeições: 1 de 4 feitas.'),
          findsOneWidget,
        );

        await desmontar(tester);
        semantica.dispose();
      },
    );

    testWidgets('Não deve estourar o layout com a fonte do celular em 200%', (
      tester,
    ) async {
      await montar(
        tester,
        paciente: criarPaciente(
          diabetes: true,
          refeicoes: const [
            RefeicaoPlanejada(
              id: 'r1',
              nome: 'Café da manhã reforçado',
              itens: [
                ItemRefeicao(
                  alimentoId: idPaoFrances,
                  nome: 'Pão, trigo, francês',
                  quantidadeG: 100,
                ),
                ItemRefeicao(
                  alimentoId: idBananaPrata,
                  nome: 'Banana, prata, crua',
                  quantidadeG: 120,
                ),
              ],
            ),
            RefeicaoPlanejada(id: 'r2', nome: 'Lanche da tarde'),
          ],
          metas: metas,
        ),
        escalaTexto: 2,
        tamanhoTela: const Size(360, 740),
      );
      await marcarNoBanco('r1', 'Café da manhã reforçado');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      await desmontar(tester);
    });
  });
}
