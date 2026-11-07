import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/constants/momentos_glicemia.dart';
import 'package:agenda_saude_app/core/theme/app_theme.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/data/repositories/relatorios_repository.dart';
import 'package:agenda_saude_app/domain/models/alerta.dart';
import 'package:agenda_saude_app/domain/models/batimento_cardiaco.dart';
import 'package:agenda_saude_app/domain/models/item_refeicao.dart';
import 'package:agenda_saude_app/domain/models/medicamento.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/refeicao_planejada.dart';
import 'package:agenda_saude_app/domain/models/registro_agua.dart';
import 'package:agenda_saude_app/domain/models/registro_diabete.dart';
import 'package:agenda_saude_app/domain/models/registro_exercicio.dart';
import 'package:agenda_saude_app/domain/models/registro_medicacao.dart';
import 'package:agenda_saude_app/domain/models/registro_refeicao.dart';
import 'package:agenda_saude_app/domain/models/registro_sono.dart';
import 'package:agenda_saude_app/ui/insulina/formatacao_diabete.dart';
import 'package:agenda_saude_app/ui/relatorios/calendario_mensal.dart';
import 'package:agenda_saude_app/ui/relatorios/relatorios_view.dart';

import '../../helpers/catalogo_de_teste.dart';

// Leitura que falha enquanto `falhando` for verdadeiro (ex.: sem internet).
class _RepositorioQueFalha extends RelatoriosRepository {
  bool falhando = true;

  _RepositorioQueFalha(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Future<RegistrosDoPeriodo> registrosDoPeriodo(
    String pacienteId,
    DateTime inicio,
    DateTime fim, {
    required bool incluirDiabete,
  }) {
    if (falhando) throw Exception('sem conexao');
    return super.registrosDoPeriodo(
      pacienteId,
      inicio,
      fim,
      incluirDiabete: incluirDiabete,
    );
  }
}

void main() {
  group('RelatoriosView Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    late RelatoriosRepository relatoriosRepository;

    // 20/11/2026 (sexta): "ontem" e quinta, 19/11. Novembro de 2026 comeca
    // num domingo.
    final agora = DateTime(2026, 11, 20, 10);

    Paciente criarPaciente({
      bool diabetes = false,
      bool cardiopatia = false,
      List<RefeicaoPlanejada>? plano,
      List<Medicamento> medicamentos = const [],
    }) {
      return Paciente(
        id: 'paciente_01',
        nome: 'José Silva',
        email: 'jose@email.com',
        perfil: 'Paciente',
        medicamentos: medicamentos,
        possuiDiabetes: diabetes,
        usaInsulina: diabetes ? true : null,
        possuiCardiopatia: cardiopatia,
        codigoVinculo: 'ABC123',
        refeicoes: plano,
      );
    }

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
      relatoriosRepository = RelatoriosRepository(firestore: fakeFirestore);
    });

    // Tela alta para o ListView montar o relatorio inteiro de uma vez.
    Future<void> montar(
      WidgetTester tester, {
      Paciente? paciente,
      bool paraAcompanhante = false,
      RelatoriosRepository? repositorio,
      double escalaTexto = 1,
      Size tela = const Size(800, 5000),
    }) async {
      tester.view.physicalSize = tela;
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
          home: RelatoriosView.comProviders(
            paciente ?? criarPaciente(),
            paraAcompanhante: paraAcompanhante,
            relatoriosRepository: repositorio ?? relatoriosRepository,
            alimentosRepository: alimentosRepositoryDeTeste(),
            agora: () => agora,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> agua(DateTime dia, int copos) async {
      for (var i = 0; i < copos; i++) {
        await dadosRepository.salvarRegistro(RegistroAgua(
          id: '',
          pacienteId: 'paciente_01',
          dataHora: DateTime(dia.year, dia.month, dia.day, 8 + i),
          quantidadeML: 250,
        ));
      }
    }

    Future<void> refeicao(DateTime dia, String id, int hora) {
      return dadosRepository.salvarRegistro(RegistroRefeicao(
        id: '',
        pacienteId: 'paciente_01',
        dataHora: DateTime(dia.year, dia.month, dia.day, hora),
        refeicaoId: id,
        nome: id,
      ));
    }

    // A noite como o app grava: ao acordar, inicio e fim valem o instante do
    // registro, que decide o dia a que ela pertence.
    Future<void> sono(DateTime dia, double horas, int qualidade, {int hora = 6}) {
      final quando = DateTime(dia.year, dia.month, dia.day, hora);
      return dadosRepository.salvarRegistro(RegistroSono(
        id: '',
        pacienteId: 'paciente_01',
        dataHora: quando,
        dataFim: quando,
        horasTotais: horas,
        qualidade: qualidade,
      ));
    }

    Future<void> dose(DateTime dia, String medicamentoId, String horario, int hora, int minuto) {
      return dadosRepository.salvarRegistro(RegistroMedicacao(
        id: '',
        pacienteId: 'paciente_01',
        dataHora: DateTime(dia.year, dia.month, dia.day, hora, minuto),
        medicamentoId: medicamentoId,
        horario: horario,
        nome: medicamentoId,
      ));
    }

    Future<void> exercicio(
      DateTime dia,
      int hora,
      int minutos, {
      String tipo = 'Caminhada',
      String intensidade = 'Moderada',
    }) {
      return dadosRepository.salvarRegistro(RegistroExercicio(
        id: '',
        pacienteId: 'paciente_01',
        dataHora: DateTime(dia.year, dia.month, dia.day, hora, 10),
        tipoExercicio: tipo,
        duracaoMinutos: minutos,
        intensidade: intensidade,
      ));
    }

    Future<void> glicemia(
      DateTime dia,
      int hora,
      double? glicose, {
      String momento = 'Ao acordar',
      double? dose,
      String? tipo,
    }) {
      return dadosRepository.salvarRegistro(RegistroDiabete(
        id: '',
        pacienteId: 'paciente_01',
        dataHora: DateTime(dia.year, dia.month, dia.day, hora, 10),
        nivelGlicose: glicose,
        momento: momento,
        doseInsulina: dose,
        tipoInsulina: tipo,
      ));
    }

    Future<void> batimento(DateTime dia, int hora, int bpm) {
      return dadosRepository.salvarBatimento(BatimentoCardiaco(
        id: '',
        pacienteId: 'paciente_01',
        bpm: bpm,
        timestamp: DateTime(dia.year, dia.month, dia.day, hora),
      ));
    }

    Future<void> alerta(DateTime quando, String tipo, int bpm, String mensagem) {
      return dadosRepository.gerarAlerta(Alerta(
        id: '',
        pacienteId: 'paciente_01',
        tipo: tipo,
        mensagem: mensagem,
        bpm: bpm,
        dataHora: quando,
      ));
    }

    final ontem = DateTime(2026, 11, 19);

    // Um dia de um diabetico com tudo o que o relatorio mostra.
    Future<void> semearOntemDeDiabetico() async {
      await agua(ontem, 7);
      await refeicao(ontem, 'cafe_da_manha', 7);
      await refeicao(ontem, 'almoco', 12);
      await glicemia(ontem, 7, 112, dose: 6, tipo: 'Rápida');
      await glicemia(ontem, 11, 62, momento: 'Antes do almoço');
      await glicemia(
        ontem,
        22,
        null,
        momento: 'Insulina lenta (22h)',
        dose: 14,
        tipo: 'Lenta',
      );
      await batimento(ontem, 6, 55);
      await batimento(ontem, 12, 80);
      await batimento(ontem, 15, 120);
      await alerta(
        DateTime(2026, 11, 19, 15, 3),
        Alerta.tipoEmergencia,
        120,
        'BPM fora da zona',
      );
    }

    group('Cabeçalho e abas', () {
      testWidgets('Deve mostrar o título e a aba Ontem para o paciente', (tester) async {
        await montar(tester);

        expect(find.text('Meus relatórios'), findsOneWidget);
        expect(
          find.text('Veja como foram o seu dia anterior e o seu mês.'),
          findsOneWidget,
        );
        expect(find.text('Ontem'), findsOneWidget);
        expect(find.text('Mês'), findsOneWidget);
        expect(find.text('Quinta-feira, 19 de novembro'), findsOneWidget);
        expect(find.text('Resumo da rotina do dia de ontem'), findsOneWidget);
      });

      testWidgets('Deve falar do paciente pelo nome quando quem abre é o acompanhante', (tester) async {
        await montar(tester, paraAcompanhante: true);

        expect(find.text('Relatórios de José'), findsOneWidget);
        expect(
          find.text('Veja como foram o dia anterior e o mês de José.'),
          findsOneWidget,
        );
        expect(find.text('Meus relatórios'), findsNothing);
        // O conteudo e o mesmo.
        expect(find.text('Quinta-feira, 19 de novembro'), findsOneWidget);
      });
    });

    group('Ontem', () {
      testWidgets('Deve mostrar o dia do diabético com todos os cartões e os pontos de atenção', (tester) async {
        await semearOntemDeDiabetico();
        await montar(tester, paciente: criarPaciente(diabetes: true));

        // Situacao do dia.
        expect(find.text('ROTINA PARCIAL'), findsOneWidget);
        expect(
          find.text('Faltou: meta de água, refeições, glicemia e sono.'),
          findsOneWidget,
        );

        // Pontos de atencao: o que o acompanhante precisa ver primeiro.
        expect(find.text('PONTOS DE ATENÇÃO'), findsOneWidget);
        expect(
          find.textContaining(
            'Alerta de emergência nos batimentos às 15:03 (120 BPM).',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Glicemia baixa 1 vez: a menor foi ${formatarGlicemia(62)}.',
          ),
          findsOneWidget,
        );

        // Hidratacao.
        expect(find.text('Hidratação'), findsOneWidget);
        expect(find.text('1.750 ml de 2.000 ml'), findsOneWidget);
        expect(find.text('7 de 8 copos'), findsOneWidget);
        expect(find.text('Faltaram 250 ml para a meta.'), findsOneWidget);

        // Refeicoes do plano padrao de diabetico (6).
        expect(find.text('2 de 6 feitas'), findsOneWidget);
        expect(find.text('Café da manhã'), findsOneWidget);
        expect(find.text('Feito às 07:00'), findsOneWidget);
        expect(find.text('Feito às 12:00'), findsOneWidget);
        expect(find.text('Não feito'), findsNWidgets(4));
        // Sem alimentos cadastrados no plano padrao: sem estimativa.
        expect(find.text('Estimativa de nutrientes'), findsNothing);

        // Glicemia e insulina.
        expect(find.text('Glicemia e insulina'), findsOneWidget);
        expect(find.text('2 de 4 medições'), findsOneWidget);
        expect(find.text('AO ACORDAR'), findsOneWidget);
        expect(find.text('NA FAIXA'), findsOneWidget);
        expect(find.text('BAIXA'), findsOneWidget);
        expect(find.text('Não anotado'), findsNWidgets(2));
        expect(find.text(MomentoGlicemia.insulinaLenta.rotulo), findsOneWidget);
        expect(
          find.text('Insulina no dia: ${formatarDose(20)} em 2 aplicações.'),
          findsOneWidget,
        );

        // Sono: ninguem anotou a noite.
        expect(find.text('Sono'), findsOneWidget);
        expect(find.text('Nenhuma noite anotada'), findsOneWidget);
        expect(
          find.text('Meta de sono: 7 a 9 horas por noite.'),
          findsOneWidget,
        );

        // Batimentos e alertas do dia.
        expect(find.text('Batimentos'), findsOneWidget);
        expect(find.text('Média de 85 BPM'), findsOneWidget);
        expect(find.text('55 BPM'), findsOneWidget);
        expect(find.text('120 BPM'), findsOneWidget);
        expect(find.text('3'), findsOneWidget); // leituras
        expect(
          find.text('2 leituras fora da zona de segurança (60 a 100 BPM).'),
          findsOneWidget,
        );
        expect(find.text('Alertas do dia'), findsOneWidget);
        expect(
          find.text('15:03 · Emergência: BPM fora da zona'),
          findsOneWidget,
        );
      });

      testWidgets('Deve mostrar dia completo quando tudo foi cumprido, sem pontos de atenção', (tester) async {
        await agua(ontem, 8);
        for (final (id, hora) in [
          ('cafe_da_manha', 7),
          ('almoco', 12),
          ('lanche_da_tarde', 16),
          ('jantar', 19),
        ]) {
          await refeicao(ontem, id, hora);
        }
        await sono(ontem, 7.5, 4);
        await batimento(ontem, 9, 70);
        await montar(tester);

        expect(find.text('ROTINA COMPLETA'), findsOneWidget);
        expect(
          find.text('Tudo cumprido: meta de água, refeições e sono.'),
          findsOneWidget,
        );
        expect(find.text('META ATINGIDA'), findsOneWidget);
        expect(find.text('4 de 4 feitas'), findsOneWidget);
        // Sono: a noite de ontem, dentro da meta.
        expect(find.text('7 h 30 min'), findsOneWidget);
        expect(find.text('Qualidade: Bom (4 de 5).'), findsOneWidget);
        expect(find.text('META DE SONO ATINGIDA'), findsOneWidget);
        expect(
          find.text('Todas as leituras dentro da zona de segurança (60 a 100 BPM).'),
          findsOneWidget,
        );
        expect(find.text('Nenhum alerta neste dia.'), findsOneWidget);
        expect(find.text('PONTOS DE ATENÇÃO'), findsNothing);
        // Quem nao tem diabetes nao ve o cartao de glicemia.
        expect(find.text('Glicemia e insulina'), findsNothing);
      });

      testWidgets('Deve avisar com texto quando o sono ficou abaixo da meta, sem tirar o dia do completo', (tester) async {
        await sono(ontem, 5.5, 2);
        await montar(tester);

        expect(find.text('5 h 30 min'), findsOneWidget);
        expect(find.text('Qualidade: Ruim (2 de 5).'), findsOneWidget);
        expect(
          find.text('Dormiu menos que a meta de 7 a 9 horas por noite.'),
          findsOneWidget,
        );
        expect(find.text('META DE SONO ATINGIDA'), findsNothing);
        // Registrar a noite basta para o item "sono" do dia: o que faltou foi o
        // resto da rotina.
        expect(
          find.text('Cumprido: sono. Faltou: meta de água e refeições.'),
          findsOneWidget,
        );
      });

      testWidgets('Deve mostrar as doses de remédio do dia, tomadas e não tomadas', (tester) async {
        await dose(ontem, 'm1', '08:00', 8, 10);
        await montar(
          tester,
          paciente: criarPaciente(medicamentos: const [
            Medicamento(
              id: 'm1',
              nome: 'Losartana',
              dose: '50 mg',
              horarios: ['08:00'],
            ),
            Medicamento(
              id: 'm2',
              nome: 'Metformina',
              dose: '500 mg',
              horarios: ['12:00'],
            ),
          ]),
        );

        expect(find.text('Medicações'), findsOneWidget);
        expect(find.text('1 de 2 tomados'), findsOneWidget);
        expect(find.text('Losartana 50 mg · 08:00'), findsOneWidget);
        expect(find.text('Tomado às 08:10'), findsOneWidget);
        expect(find.text('Metformina 500 mg · 12:00'), findsOneWidget);
        expect(find.text('Não tomado'), findsOneWidget);
        // Os remedios entram no que o dia pedia: falta uma dose das duas.
        expect(
          find.text('Faltou: meta de água, remédios, refeições e sono.'),
          findsOneWidget,
        );
      });

      testWidgets('Sem remédios cadastrados, o relatório diz isso e não cobra doses', (tester) async {
        await agua(ontem, 8);
        await montar(tester);

        expect(find.text('Medicações'), findsOneWidget);
        expect(find.text('Nenhum remédio cadastrado'), findsOneWidget);
        expect(find.textContaining('remédios'), findsNothing);
      });

      testWidgets('Deve mostrar os exercícios do dia e o progresso da semana até ele', (tester) async {
        // Ontem foi quinta (19/11): a semana (domingo 15/11 a sabado 21/11) tem
        // 40 min na segunda e os 30 de ontem; o de sexta ainda nao conta.
        await exercicio(DateTime(2026, 11, 16), 8, 40);
        await exercicio(ontem, 7, 30, tipo: 'Hidroginástica', intensidade: 'Leve');
        await exercicio(DateTime(2026, 11, 20), 9, 60);
        await montar(tester);

        expect(find.text('Exercício'), findsOneWidget);
        expect(find.text('30 min'), findsOneWidget);
        expect(
          find.text('07:10 · Hidroginástica, 30 min, intensidade leve.'),
          findsOneWidget,
        );
        expect(
          find.text('Na semana, até este dia: 70 de 150 min.'),
          findsOneWidget,
        );
        expect(
          find.text('Faltavam 80 min para a meta da semana.'),
          findsOneWidget,
        );
        expect(find.text('META DA SEMANA ATINGIDA'), findsNothing);
        // So o exercicio: o dia tem registro, mas a rotina ficou incompleta.
        expect(find.text('ROTINA PARCIAL'), findsOneWidget);
        expect(
          find.text('Faltou: meta de água, refeições e sono.'),
          findsOneWidget,
        );
      });

      testWidgets('Deve mostrar a meta da semana atingida mesmo sem exercício no dia', (tester) async {
        await exercicio(DateTime(2026, 11, 16), 8, 90);
        await exercicio(DateTime(2026, 11, 17), 8, 60);
        await montar(tester);

        expect(find.text('Nenhum exercício anotado'), findsOneWidget);
        expect(
          find.text('Na semana, até este dia: 150 de 150 min.'),
          findsOneWidget,
        );
        expect(find.text('META DA SEMANA ATINGIDA'), findsOneWidget);
      });

      testWidgets('Deve avisar que nada foi anotado quando o dia está vazio', (tester) async {
        await montar(tester);

        expect(find.text('SEM REGISTROS'), findsOneWidget);
        expect(find.text('Nada da rotina foi anotado neste dia.'), findsOneWidget);
        expect(find.text('Nenhuma água anotada'), findsOneWidget);
        expect(find.text('Meta do dia: 2.000 ml.'), findsOneWidget);
        expect(find.text('0 de 4 feitas'), findsOneWidget);
        expect(find.text('Sem leituras'), findsOneWidget);
        expect(
          find.text('O smartwatch não registrou batimentos neste dia.'),
          findsOneWidget,
        );
        expect(find.text('Nenhum alerta neste dia.'), findsOneWidget);
        expect(find.text('PONTOS DE ATENÇÃO'), findsNothing);
      });

      testWidgets('Deve usar a zona de segurança mais estreita do cardiopata', (tester) async {
        await batimento(ontem, 9, 95);
        await montar(tester, paciente: criarPaciente(cardiopatia: true));

        expect(
          find.text('1 leitura fora da zona de segurança (60 a 90 BPM).'),
          findsOneWidget,
        );
      });

      testWidgets('Deve estimar os nutrientes pelos alimentos das refeições feitas', (tester) async {
        await refeicao(ontem, 'cafe', 7);
        await montar(
          tester,
          paciente: criarPaciente(
            plano: const [
              RefeicaoPlanejada(
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
              RefeicaoPlanejada(
                id: 'almoco',
                nome: 'Almoço',
                itens: [
                  ItemRefeicao(
                    alimentoId: idArrozCozido,
                    nome: 'Arroz, tipo 1, cozido',
                    quantidadeG: 100,
                  ),
                ],
              ),
            ],
          ),
        );

        expect(find.text('Estimativa de nutrientes'), findsOneWidget);
        // 50 g de pao (150 kcal) + 100 g de banana (98 kcal); o almoco nao foi feito.
        expect(find.text('248 kcal'), findsOneWidget);
        expect(
          find.text('Calculada pelos alimentos cadastrados em cada refeição feita.'),
          findsOneWidget,
        );
      });

      testWidgets('Deve mostrar o erro e se recuperar ao tentar de novo', (tester) async {
        await agua(ontem, 4);
        final repositorio = _RepositorioQueFalha(fakeFirestore);
        await montar(tester, repositorio: repositorio);

        expect(find.text('Não foi possível carregar'), findsOneWidget);
        // Sem numeros de um relatorio que nao carregou.
        expect(find.text('SEM REGISTROS'), findsNothing);
        expect(find.text('Hidratação'), findsNothing);

        repositorio.falhando = false;
        await tester.tap(find.text('Tentar novamente'));
        await tester.pumpAndSettle();

        expect(find.text('Não foi possível carregar'), findsNothing);
        expect(find.text('1.000 ml de 2.000 ml'), findsOneWidget);
      });
    });

    group('Mês', () {
      // Novembro: dia 3 completo, dia 4 parcial com emergencia; os outros
      // dias ate o 19 sem registro.
      Future<void> semearNovembro() async {
        final dia3 = DateTime(2026, 11, 3);
        await agua(dia3, 8);
        await refeicao(dia3, 'cafe_da_manha', 7);
        await refeicao(dia3, 'almoco', 12);
        await refeicao(dia3, 'lanche_da_tarde', 16);
        await refeicao(dia3, 'jantar', 19);
        await sono(dia3, 8, 4);
        await agua(DateTime(2026, 11, 4), 2);
        await alerta(
          DateTime(2026, 11, 4, 14, 30),
          Alerta.tipoEmergencia,
          131,
          'BPM alto',
        );
        // Hoje (dia 20) ainda nao terminou: nao entra.
        await agua(DateTime(2026, 11, 20), 8);
      }

      Future<void> abrirMes(WidgetTester tester) async {
        await tester.tap(find.text('Mês'));
        await tester.pumpAndSettle();
      }

      testWidgets('Deve abrir no mês atual, só com os dias já encerrados', (tester) async {
        await semearNovembro();
        await montar(tester);

        await abrirMes(tester);

        expect(find.text('Novembro de 2026'), findsOneWidget);
        // Dias 1 a 19: o dia 3 completo e o dia 4 parcial.
        expect(find.text('Rotina do mês'), findsOneWidget);
        expect(find.text('2 de 19 dias com registro'), findsOneWidget);
        expect(find.text('1 dia completo'), findsOneWidget);
        expect(find.text('1 dia parcial'), findsOneWidget);
        expect(find.text('17 dias sem registro'), findsOneWidget);
        expect(find.text('1 dia com alerta de saúde'), findsOneWidget);
      });

      testWidgets('Deve resumir hidratação, refeições e batimentos do mês', (tester) async {
        await semearNovembro();
        await montar(tester);

        await abrirMes(tester);

        // Agua: 2.000 ml no dia 3 e 500 ml no dia 4.
        expect(find.text('Média de 1.250 ml por dia'), findsOneWidget);
        expect(find.text('Meta de 2.000 ml batida em 1 de 19 dias'), findsOneWidget);
        expect(find.text('Água anotada em 2 de 19 dias'), findsOneWidget);
        // Refeicoes: 4 no dia 3, de 4 x 19 previstas.
        expect(find.text('4 de 76 feitas (5%)'), findsOneWidget);
        expect(
          find.text('Todas as refeições feitas em 1 de 19 dias'),
          findsOneWidget,
        );
        // Batimentos: so os alertas.
        expect(find.text('1 alerta no mês'), findsOneWidget);
        expect(find.text('Emergência: 1 vez (dia 4)'), findsOneWidget);
        // Quem nao tem diabetes nao ve a glicemia.
        expect(find.text('Glicemia e insulina'), findsNothing);
      });

      testWidgets('Deve mostrar a glicemia e a insulina do mês de quem tem diabetes', (tester) async {
        final dia2 = DateTime(2026, 11, 2);
        final dia3 = DateTime(2026, 11, 3);
        await glicemia(dia2, 7, 62, dose: 6, tipo: 'Rápida');
        await glicemia(dia3, 7, 300);
        await glicemia(dia3, 11, 110, momento: 'Antes do almoço');
        await montar(tester, paciente: criarPaciente(diabetes: true));

        await abrirMes(tester);

        expect(find.text('Glicemia e insulina'), findsOneWidget);
        expect(
          find.text('Média de ${formatarGlicemia((62 + 300 + 110) / 3)}'),
          findsOneWidget,
        );
        expect(find.text('Medições feitas: 3 de 76'), findsOneWidget);
        expect(
          find.text(
            'Na faixa de 70 a 180 mg/dL: 33% das medições (1 de 3)',
          ),
          findsOneWidget,
        );
        expect(find.text('Glicemia baixa 1 vez (dia 2)'), findsOneWidget);
        expect(
          find.text(
            'Glicemia muito alta, acima de 250 mg/dL: 1 vez (dia 3)',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Insulina: ${formatarDose(6)} no mês, em 1 de 19 dias'),
          findsOneWidget,
        );
        // Os dois dias com problema aparecem no calendario.
        expect(find.text('2 dias com alerta de saúde'), findsOneWidget);
      });

      testWidgets('Deve voltar e avançar entre os meses, sem passar do mês atual', (tester) async {
        await montar(tester);
        await abrirMes(tester);

        // OutlinedButton.icon cria uma subclasse do botao.
        OutlinedButton botao(String rotulo) => tester.widget<OutlinedButton>(
              find.ancestor(
                of: find.text(rotulo),
                matching: find.bySubtype<OutlinedButton>(),
              ),
            );
        expect(botao('Próximo mês').onPressed, isNull);

        await tester.tap(find.text('Mês anterior'));
        await tester.pumpAndSettle();

        expect(find.text('Outubro de 2026'), findsOneWidget);
        // Outubro tem 31 dias, todos encerrados.
        expect(find.text('0 de 31 dias com registro'), findsOneWidget);
        expect(find.text('31 dias sem registro'), findsOneWidget);
        expect(botao('Próximo mês').onPressed, isNotNull);

        await tester.tap(find.text('Próximo mês'));
        await tester.pumpAndSettle();

        expect(find.text('Novembro de 2026'), findsOneWidget);
        expect(botao('Próximo mês').onPressed, isNull);
      });

      testWidgets('Deve explicar que o mês ainda não tem dia encerrado no dia 1', (tester) async {
        // No dia 1 a tela abre no mes anterior; avancando, o mes atual ainda
        // nao terminou nenhum dia.
        tester.view.physicalSize = const Size(800, 5000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.claro,
            home: RelatoriosView.comProviders(
              criarPaciente(),
              relatoriosRepository: relatoriosRepository,
              alimentosRepository: alimentosRepositoryDeTeste(),
              agora: () => DateTime(2026, 12, 1, 9),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await abrirMes(tester);

        expect(find.text('Novembro de 2026'), findsOneWidget);

        await tester.tap(find.text('Próximo mês'));
        await tester.pumpAndSettle();

        expect(find.text('Dezembro de 2026'), findsOneWidget);
        expect(find.text('Mês em andamento'), findsOneWidget);
        expect(
          find.textContaining('Ainda não terminou nenhum dia deste mês'),
          findsOneWidget,
        );
        expect(find.byType(CalendarioMensal), findsNothing);
      });

      testWidgets('Deve abrir o relatório do dia tocado no calendário e voltar para o mês', (tester) async {
        await semearNovembro();
        await montar(tester);
        await abrirMes(tester);

        await tester.tap(
          find.descendant(
            of: find.byType(CalendarioMensal),
            matching: find.text('4'),
          ),
        );
        await tester.pumpAndSettle();

        // O dia 4 (quarta): 500 ml de agua, sem refeicoes e uma emergencia.
        expect(find.text('Quarta-feira, 4 de novembro'), findsOneWidget);
        expect(find.text('Como foi a sua rotina neste dia.'), findsOneWidget);
        expect(find.text('ROTINA PARCIAL'), findsOneWidget);
        expect(find.text('500 ml de 2.000 ml'), findsOneWidget);
        expect(
          find.textContaining('Alerta de emergência nos batimentos às 14:30'),
          findsOneWidget,
        );

        await tester.tap(find.text('Voltar'));
        await tester.pumpAndSettle();

        expect(find.text('Novembro de 2026'), findsOneWidget);
        expect(find.text('Meus relatórios'), findsOneWidget);
      });

      testWidgets('O acompanhante vê o dia tocado falando do paciente pelo nome', (tester) async {
        await semearNovembro();
        await montar(tester, paraAcompanhante: true);
        await abrirMes(tester);

        await tester.tap(
          find.descendant(
            of: find.byType(CalendarioMensal),
            matching: find.text('3'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Terça-feira, 3 de novembro'), findsOneWidget);
        expect(find.text('Como foi a rotina de José neste dia.'), findsOneWidget);
        expect(find.text('ROTINA COMPLETA'), findsOneWidget);
      });

      testWidgets('Não deve abrir nada ao tocar em hoje nem em um dia que ainda não chegou', (tester) async {
        await montar(tester);
        await abrirMes(tester);

        await tester.tap(
          find.descendant(
            of: find.byType(CalendarioMensal),
            matching: find.text('20'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(CalendarioMensal),
            matching: find.text('25'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Meus relatórios'), findsOneWidget);
        expect(find.text('Voltar'), findsOneWidget);
        expect(find.textContaining('neste dia.'), findsNothing);
      });

      testWidgets('Deve mostrar o erro do mês e se recuperar ao tentar de novo', (tester) async {
        final repositorio = _RepositorioQueFalha(fakeFirestore);
        await montar(tester, repositorio: repositorio);
        // A aba Ontem tambem falhou; deixa so o mes se recuperar.
        await abrirMes(tester);

        expect(find.text('Não foi possível carregar'), findsOneWidget);
        expect(find.text('Rotina do mês'), findsNothing);

        repositorio.falhando = false;
        await tester.tap(find.text('Tentar novamente'));
        await tester.pumpAndSettle();

        expect(find.text('Rotina do mês'), findsOneWidget);
      });

      testWidgets('Deve guardar o mês ao trocar de aba e voltar', (tester) async {
        await montar(tester);
        await abrirMes(tester);
        await tester.tap(find.text('Mês anterior'));
        await tester.pumpAndSettle();
        expect(find.text('Outubro de 2026'), findsOneWidget);

        await tester.tap(find.text('Ontem'));
        await tester.pumpAndSettle();
        expect(find.text('Quinta-feira, 19 de novembro'), findsOneWidget);
        await abrirMes(tester);

        expect(find.text('Outubro de 2026'), findsOneWidget);
      });
    });

    group('Fonte do celular em 200%', () {
      testWidgets('Não deve estourar o layout do dia nem do mês', (tester) async {
        await semearOntemDeDiabetico();
        await agua(DateTime(2026, 11, 3), 8);
        await alerta(
          DateTime(2026, 11, 3, 10),
          Alerta.tipoEmergencia,
          130,
          'BPM alto',
        );
        // Celular pequeno (360x640) com a fonte no maximo: qualquer overflow
        // vira erro e reprova o teste.
        await montar(
          tester,
          paciente: criarPaciente(diabetes: true),
          escalaTexto: 2,
          tela: const Size(360, 640),
        );

        await tester.scrollUntilVisible(find.text('Alertas do dia'), 300);
        expect(find.text('Alertas do dia'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Mês'),
          -300,
        );
        await tester.tap(find.text('Mês'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Batimentos'), 300);
        expect(find.text('Batimentos'), findsOneWidget);
      });
    });
  });
}
