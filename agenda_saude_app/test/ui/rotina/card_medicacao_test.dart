import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agenda_saude_app/core/theme/app_theme.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/domain/models/medicamento.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_medicacao.dart';
import 'package:agenda_saude_app/ui/acompanhante/formato_status_paciente.dart';
import 'package:agenda_saude_app/ui/rotina/card_medicacao.dart';
import 'package:agenda_saude_app/ui/rotina/medicacao_viewmodel.dart';
import 'package:agenda_saude_app/ui/rotina/meus_remedios_view.dart';

import '../../helpers/catalogo_de_teste.dart';
import '../shared/escolher_horario.dart';
import '../shared/escolher_na_busca.dart';

// Leitura do dia que sempre falha (ex.: indice composto nao publicado).
class _RepositorioSemLeitura extends DadosMedicosRepository {
  _RepositorioSemLeitura(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Stream<List<RegistroMedicacao>> streamMedicacoesDoDia(
    String pacienteId,
    DateTime dia,
  ) =>
      Stream.error(Exception('indice faltando'));
}

const _losartana = Medicamento(
  id: 'm1',
  nome: 'Losartana',
  dose: '50 mg',
  horarios: ['08:00'],
);
const _metformina = Medicamento(
  id: 'm2',
  nome: 'Metformina',
  dose: '500 mg',
  horarios: ['12:00'],
);
const _sinvastatina = Medicamento(
  id: 'm3',
  nome: 'Sinvastatina',
  dose: '20 mg',
  horarios: ['20:00'],
);

void main() {
  group('CardMedicacao Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;

    final hoje = DateTime(2026, 10, 25, 9, 30);

    Paciente criarPaciente(List<Medicamento> medicamentos) => Paciente(
          id: 'paciente_01',
          nome: 'José Silva',
          email: 'jose@email.com',
          perfil: 'Paciente',
          possuiDiabetes: false,
          possuiCardiopatia: false,
          codigoVinculo: 'ABC123',
          medicamentos: medicamentos,
        );

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
    });

    Future<void> montar(
      WidgetTester tester, {
      List<Medicamento> medicamentos = const [
        _losartana,
        _metformina,
        _sinvastatina,
      ],
      DadosMedicosRepository? repositorio,
      double escalaTexto = 1,
      Size tamanho = const Size(800, 2400),
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
            create: (_) => MedicacaoViewModel(
              paciente: criarPaciente(medicamentos),
              dadosRepository: repositorio ?? dadosRepository,
              pacienteRepository: PacienteRepository(firestore: fakeFirestore),
              agora: () => hoje,
            ),
            // "Meus remedios" abre pelo "Personalizar rotina"; aqui um botao
            // faz o papel dele, com o mesmo MedicacaoViewModel do cartao.
            child: Builder(
              builder: (context) => Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MeusRemediosView.comProviders(
                              context.read<MedicacaoViewModel>(),
                              carregarCatalogo: carregarRemediosPequeno,
                            ),
                          ),
                        ),
                        child: const Text('Abrir Meus remédios'),
                      ),
                      const CardMedicacao(),
                    ],
                  ),
                ),
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

    Future<void> marcarNoFirestore(String medicamentoId, String horario, DateTime quando) {
      return dadosRepository.salvarRegistro(RegistroMedicacao(
        id: '',
        pacienteId: 'paciente_01',
        dataHora: quando,
        medicamentoId: medicamentoId,
        horario: horario,
        nome: medicamentoId,
      ));
    }

    Finder linhaDa(String descricao) => find.ancestor(
          of: find.text(descricao),
          matching: find.byType(InkWell),
        );

    testWidgets('Deve mostrar uma linha por dose, em ordem de horário, com caixa de seleção', (
      tester,
    ) async {
      await montar(tester);

      expect(find.text('Medicações'), findsOneWidget);
      expect(find.text('0 de 3 tomados'), findsOneWidget);
      expect(find.text('Losartana 50 mg'), findsOneWidget);
      expect(find.text('Metformina 500 mg'), findsOneWidget);
      expect(find.text('Sinvastatina 20 mg'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('12:00'), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget);
      expect(find.text('Ainda não tomado'), findsNWidgets(3));
      expect(find.byIcon(Icons.check_box_outline_blank_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.check_box_rounded), findsNothing);
      // A ordem na tela e a dos horarios.
      expect(
        tester.getTopLeft(find.text('Losartana 50 mg')).dy,
        lessThan(tester.getTopLeft(find.text('Metformina 500 mg')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Metformina 500 mg')).dy,
        lessThan(tester.getTopLeft(find.text('Sinvastatina 20 mg')).dy),
      );

      await desmontar(tester);
    });

    testWidgets('Deve marcar a dose como tomada ao tocar, com a hora e a caixa marcada', (
      tester,
    ) async {
      await montar(tester);

      await tester.tap(linhaDa('Losartana 50 mg'));
      await tester.pumpAndSettle();

      expect(find.text('1 de 3 tomados'), findsOneWidget);
      expect(find.text('Tomado às 09:30'), findsOneWidget);
      expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);
      expect(find.text('Ainda não tomado'), findsNWidgets(2));
      final gravados = (await fakeFirestore.collection('registros_diarios').get()).docs;
      expect(gravados.single.data()['tipo'], 'medicacao');
      expect(gravados.single.data()['medicamentoId'], 'm1');

      await desmontar(tester);
    });

    testWidgets('Deve desmarcar a dose ao tocar de novo', (tester) async {
      await montar(tester);

      await tester.tap(linhaDa('Losartana 50 mg'));
      await tester.pumpAndSettle();
      await tester.tap(linhaDa('Losartana 50 mg'));
      await tester.pumpAndSettle();

      expect(find.text('0 de 3 tomados'), findsOneWidget);
      expect(find.byIcon(Icons.check_box_rounded), findsNothing);
      expect((await fakeFirestore.collection('registros_diarios').get()).docs,
          isEmpty);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar as doses que já foram tomadas hoje', (tester) async {
      await marcarNoFirestore('m1', '08:00', DateTime(2026, 10, 25, 8, 12));
      await marcarNoFirestore('m2', '12:00', DateTime(2026, 10, 25, 9, 0));
      await montar(tester);

      expect(find.text('2 de 3 tomados'), findsOneWidget);
      expect(find.text('Tomado às 08:12'), findsOneWidget);
      expect(find.text('Tomado às 09:00'), findsOneWidget);
      expect(find.text('Ainda não tomado'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Não deve mostrar selo quando todas as doses foram tomadas', (
      tester,
    ) async {
      await marcarNoFirestore('m1', '08:00', DateTime(2026, 10, 25, 8, 12));
      await marcarNoFirestore('m2', '12:00', DateTime(2026, 10, 25, 9, 0));
      await marcarNoFirestore('m3', '20:00', DateTime(2026, 10, 25, 9, 10));
      await montar(tester);

      expect(find.text('3 de 3 tomados'), findsOneWidget);
      expect(find.text('REMÉDIOS DE HOJE TOMADOS'), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Sem remédios cadastrados, deve explicar como cadastrar', (
      tester,
    ) async {
      await montar(tester, medicamentos: const []);

      expect(find.textContaining('Você ainda não cadastrou seus remédios'),
          findsOneWidget);
      expect(find.textContaining('tomados'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Deve esconder as marcações e desligar as linhas quando a leitura do dia falha', (
      tester,
    ) async {
      await montar(tester, repositorio: _RepositorioSemLeitura(fakeFirestore));

      expect(find.textContaining('Não foi possível carregar os seus remédios'),
          findsOneWidget);
      expect(find.text('Losartana 50 mg'), findsNothing);
      expect(find.textContaining('tomados'), findsNothing);

      await desmontar(tester);
    });

    testWidgets('"Meus remédios" deve mostrar o que o cartão está listando', (
      tester,
    ) async {
      await montar(tester);

      await tester.tap(find.text('Abrir Meus remédios'));
      await tester.pumpAndSettle();

      expect(
          find.text('Escolha cada remédio na lista e diga a dose e os '
              'horários em que você toma. Na rotina, você só marca quando '
              'tomar.'),
          findsOneWidget);
      expect(find.text('Losartana'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Fluxo completo: cadastra dois remédios com horários, marca um como tomado e o acompanhante vê', (
      tester,
    ) async {
      // A lista e gravada no documento do paciente (um update), que precisa
      // existir.
      await PacienteRepository(firestore: fakeFirestore)
          .salvarPaciente(criarPaciente(const []));
      await montar(tester, medicamentos: const []);

      // Cadastra os dois remedios em "Meus remedios".
      // Os nomes vem da busca; aqui, os digitados ("Usar").
      await tester.tap(find.text('Abrir Meus remédios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar remédio'));
      await tester.pumpAndSettle();
      await escolherNaBusca(tester, 'Losartana', 'Usar "Losartana"');
      await tester.tap(find.text('Adicionar remédio'));
      await tester.pumpAndSettle();
      await escolherNaBusca(tester, 'Metformina', 'Usar "Metformina"');

      Finder campo(String rotulo, int posicao) =>
          find.widgetWithText(TextFormField, rotulo).at(posicao);

      await tester.enterText(campo('Dose (opcional)', 0), '50 mg');
      await tester.tap(find.byTooltip('Adicionar horário').at(0));
      await tester.pumpAndSettle();
      await escolherNoSeletorDeHorario(tester, hora: 8, minuto: 0);
      await tester.enterText(campo('Dose (opcional)', 1), '500 mg');
      await tester.tap(find.byTooltip('Adicionar horário').at(1));
      await tester.pumpAndSettle();
      await escolherNoSeletorDeHorario(tester, hora: 12, minuto: 0);
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      // De volta ao cartao: as duas doses, ainda por tomar.
      expect(find.text('0 de 2 tomados'), findsOneWidget);
      expect(find.text('Losartana 50 mg'), findsOneWidget);
      expect(find.text('Metformina 500 mg'), findsOneWidget);

      // Marca a primeira como tomada.
      await tester.tap(linhaDa('Losartana 50 mg'));
      await tester.pumpAndSettle();
      expect(find.text('1 de 2 tomados'), findsOneWidget);
      expect(find.text('Tomado às 09:30'), findsOneWidget);

      // O acompanhante, que le a mesma colecao, ve o que foi tomado.
      final ultima =
          await dadosRepository.streamUltimaAtividade('paciente_01').first;
      expect(ultima, isA<RegistroMedicacao>());
      expect(descreverAtividade(ultima!).texto,
          'TOMOU O REMÉDIO: LOSARTANA 50 MG');
      // E a lista de remedios ficou gravada no documento do paciente.
      final gravado = await PacienteRepository(firestore: fakeFirestore)
          .getPaciente('paciente_01');
      expect(gravado!.medicamentos.map((m) => m.nome),
          ['Losartana', 'Metformina']);
      expect(gravado.medicamentos.first.horarios, ['08:00']);

      await desmontar(tester);
    });

    testWidgets('Deve falar cada dose por inteiro para o leitor de tela', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await marcarNoFirestore('m1', '08:00', DateTime(2026, 10, 25, 8, 12));
      await montar(tester);

      expect(
        find.bySemanticsLabel('Losartana 50 mg, às 08:00, tomado. '
            'Toque para desmarcar.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Metformina 500 mg, às 12:00, ainda não '
            'tomado. Toque para marcar como tomado.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Medicações: 1 de 3 doses tomadas.'),
        findsOneWidget,
      );

      await desmontar(tester);
      semantica.dispose();
    });

    testWidgets('Não estoura com a fonte do celular em 200%', (tester) async {
      // Celular pequeno (360x640) com a fonte no maximo: qualquer overflow
      // vira erro e reprova o teste.
      await marcarNoFirestore('m1', '08:00', DateTime(2026, 10, 25, 8, 12));
      await montar(tester, escalaTexto: 2, tamanho: const Size(360, 640));

      expect(find.text('Medicações'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await desmontar(tester);
    });
  });
}
