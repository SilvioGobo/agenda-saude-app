import 'dart:async';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/alimentos_repository.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/data/repositories/relatorios_repository.dart';
import 'package:agenda_saude_app/domain/models/alerta.dart';
import 'package:agenda_saude_app/domain/models/batimento_cardiaco.dart';
import 'package:agenda_saude_app/domain/models/item_refeicao.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/refeicao_planejada.dart';
import 'package:agenda_saude_app/domain/models/registro_agua.dart';
import 'package:agenda_saude_app/domain/models/registro_diabete.dart';
import 'package:agenda_saude_app/domain/models/registro_refeicao.dart';
import 'package:agenda_saude_app/domain/relatorios/resumo_do_dia.dart';
import 'package:agenda_saude_app/ui/relatorios/estado_relatorio.dart';
import 'package:agenda_saude_app/ui/relatorios/relatorio_dia_viewmodel.dart';

import '../../helpers/catalogo_de_teste.dart';

// Leitura que sempre falha (ex.: sem internet ou sem permissao) enquanto
// `falhando` for verdadeiro.
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
  group('RelatorioDiaViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    late RelatoriosRepository relatoriosRepository;
    late AlimentosRepository alimentosRepository;

    final dia = DateTime(2026, 11, 1);

    Paciente criarPaciente({
      bool diabetes = false,
      List<RefeicaoPlanejada>? plano = const [
        RefeicaoPlanejada(id: 'cafe', nome: 'Café'),
        RefeicaoPlanejada(id: 'almoco', nome: 'Almoço'),
      ],
    }) {
      return Paciente(
        id: 'paciente_01',
        nome: 'José Silva',
        email: 'jose@email.com',
        perfil: 'Paciente',
        possuiDiabetes: diabetes,
        possuiCardiopatia: false,
        codigoVinculo: 'ABC123',
        refeicoes: plano,
      );
    }

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
      relatoriosRepository = RelatoriosRepository(firestore: fakeFirestore);
      alimentosRepository = alimentosRepositoryDeTeste();
    });

    RelatorioDiaViewModel criar(
      Paciente paciente, {
      DateTime? data,
      RelatoriosRepository? repositorio,
      AlimentosRepository? alimentos,
    }) {
      return RelatorioDiaViewModel(
        paciente: paciente,
        dia: data ?? dia,
        relatoriosRepository: repositorio ?? relatoriosRepository,
        alimentosRepository: alimentos ?? alimentosRepository,
      );
    }

    Future<void> salvarCopos(int quantidade, {DateTime? quando}) async {
      final base = quando ?? DateTime(2026, 11, 1, 8);
      for (var i = 0; i < quantidade; i++) {
        await dadosRepository.salvarRegistro(RegistroAgua(
          id: '',
          pacienteId: 'paciente_01',
          dataHora: base.add(Duration(minutes: i)),
          quantidadeML: 250,
        ));
      }
    }

    test('Deve começar carregando, sem resumo, e guardar o dia sem a hora', () {
      final viewModel =
          criar(criarPaciente(), data: DateTime(2026, 11, 1, 15, 30));

      expect(viewModel.estado, EstadoRelatorio.carregando);
      expect(viewModel.resumo, isNull);
      expect(viewModel.dia, DateTime(2026, 11, 1));
      viewModel.dispose();
    });

    test('Deve montar o resumo do dia com os registros do paciente', () async {
      await salvarCopos(6);
      await dadosRepository.salvarRegistro(RegistroRefeicao(
        id: '',
        pacienteId: 'paciente_01',
        dataHora: DateTime(2026, 11, 1, 7),
        refeicaoId: 'cafe',
        nome: 'Café',
      ));
      await dadosRepository.salvarBatimento(BatimentoCardiaco(
        id: '',
        pacienteId: 'paciente_01',
        bpm: 130,
        timestamp: DateTime(2026, 11, 1, 15),
      ));
      await dadosRepository.gerarAlerta(Alerta(
        id: '',
        pacienteId: 'paciente_01',
        tipo: Alerta.tipoEmergencia,
        mensagem: 'BPM alto',
        bpm: 130,
        dataHora: DateTime(2026, 11, 1, 15),
      ));
      final viewModel = criar(criarPaciente());

      await viewModel.carregar();

      expect(viewModel.estado, EstadoRelatorio.pronto);
      final resumo = viewModel.resumo!;
      expect(resumo.hidratacao.totalMl, 1500);
      expect(resumo.refeicoes.feitas, 1);
      expect(resumo.diabetes, isNull);
      expect(resumo.batimentos.maximo, 130);
      expect(resumo.batimentos.foraDaZona, 1);
      expect(resumo.emergencias, 1);
      expect(resumo.situacao, SituacaoDoDia.parcial);
      viewModel.dispose();
    });

    test('Deve ler só o dia pedido e só o paciente dele', () async {
      await salvarCopos(2); // dia 1
      await salvarCopos(5, quando: DateTime(2026, 10, 31, 20)); // dia anterior
      await salvarCopos(5, quando: DateTime(2026, 11, 2, 8)); // dia seguinte
      await dadosRepository.salvarRegistro(RegistroAgua(
        id: '',
        pacienteId: 'outro_paciente',
        dataHora: DateTime(2026, 11, 1, 9),
        quantidadeML: 250,
      ));
      final viewModel = criar(criarPaciente());

      await viewModel.carregar();

      expect(viewModel.resumo!.hidratacao.totalMl, 500);
      viewModel.dispose();
    });

    test('Deve ler a glicemia só de quem tem diabetes', () async {
      await dadosRepository.salvarRegistro(RegistroDiabete(
        id: '',
        pacienteId: 'paciente_01',
        dataHora: DateTime(2026, 11, 1, 7),
        nivelGlicose: 112,
        momento: 'Ao acordar',
      ));
      final diabetico = criar(criarPaciente(diabetes: true));
      final semDiabetes = criar(criarPaciente());

      await diabetico.carregar();
      await semDiabetes.carregar();

      expect(diabetico.resumo!.diabetes!.glicemia.medicoes, 1);
      expect(semDiabetes.resumo!.diabetes, isNull);
      diabetico.dispose();
      semDiabetes.dispose();
    });

    test('Deve avisar os ouvintes ao terminar de carregar', () async {
      final viewModel = criar(criarPaciente());
      var avisos = 0;
      viewModel.addListener(() => avisos++);

      await viewModel.carregar();

      // Ao comecar a carregar, ao ficar pronto e quando o catalogo de alimentos
      // chega (que acrescenta os nutrientes).
      expect(avisos, 3);
      viewModel.dispose();
    });

    test('Deve ir para o erro quando a leitura falha, e se recuperar ao tentar de novo', () async {
      final repositorio = _RepositorioQueFalha(fakeFirestore);
      await salvarCopos(3);
      final viewModel = criar(criarPaciente(), repositorio: repositorio);

      await viewModel.carregar();

      expect(viewModel.estado, EstadoRelatorio.erro);
      expect(viewModel.resumo, isNull);

      repositorio.falhando = false;
      await viewModel.carregar();

      expect(viewModel.estado, EstadoRelatorio.pronto);
      expect(viewModel.resumo!.hidratacao.totalMl, 750);
      viewModel.dispose();
    });

    test('Não deve notificar nem estourar se a tela for fechada durante a leitura', () async {
      final viewModel = criar(criarPaciente());

      final leitura = viewModel.carregar();
      viewModel.dispose();

      await expectLater(leitura, completes);
    });

    group('Nutrientes', () {
      // Café: 50 g de pão (150 kcal) e 100 g de banana (98 kcal); o almoço
      // tem arroz, mas não foi marcado.
      final plano = [
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
        const RefeicaoPlanejada(
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
      ];

      Future<void> marcarCafe() {
        return dadosRepository.salvarRegistro(RegistroRefeicao(
          id: '',
          pacienteId: 'paciente_01',
          dataHora: DateTime(2026, 11, 1, 7),
          refeicaoId: 'cafe',
          nome: 'Café',
        ));
      }

      test('Deve somar só os alimentos das refeições marcadas como feitas', () async {
        await marcarCafe();
        final viewModel = criar(criarPaciente(plano: plano));

        await viewModel.carregar();

        expect(viewModel.temNutrientes, isTrue);
        expect(viewModel.nutrientesConsumidos.kcal, closeTo(248, 0.01));
        viewModel.dispose();
      });

      test('Não deve ter nutrientes quando nenhuma refeição tem alimentos cadastrados', () async {
        await marcarCafe();
        final viewModel = criar(criarPaciente());

        await viewModel.carregar();

        expect(viewModel.temNutrientes, isFalse);
        viewModel.dispose();
      });

      test('Deve mostrar o relatório antes de o catálogo chegar e acrescentar os nutrientes depois', () async {
        await marcarCafe();
        final catalogo = Completer<String>();
        final viewModel = criar(
          criarPaciente(plano: plano),
          alimentos: AlimentosRepository(lerTexto: () => catalogo.future),
        );

        final leitura = viewModel.carregar();
        for (var i = 0;
            i < 50 && viewModel.estado != EstadoRelatorio.pronto;
            i++) {
          await Future<void>.delayed(Duration.zero);
        }

        // O relatorio ja serve, sem os nutrientes.
        expect(viewModel.estado, EstadoRelatorio.pronto);
        expect(viewModel.resumo!.refeicoes.feitas, 1);
        expect(viewModel.temNutrientes, isFalse);

        var avisos = 0;
        viewModel.addListener(() => avisos++);
        catalogo.complete(File(arquivoDoCatalogo).readAsStringSync());
        await leitura;

        expect(viewModel.temNutrientes, isTrue);
        expect(viewModel.nutrientesConsumidos.kcal, closeTo(248, 0.01));
        expect(avisos, 1);
        viewModel.dispose();
      });

      test('Deve mostrar o relatório sem os nutrientes se o catálogo não carregar', () async {
        await marcarCafe();
        final viewModel = criar(
          criarPaciente(plano: plano),
          alimentos: AlimentosRepository(
            lerTexto: () async => throw Exception('asset ausente'),
          ),
        );

        await viewModel.carregar();

        expect(viewModel.estado, EstadoRelatorio.pronto);
        expect(viewModel.resumo!.refeicoes.feitas, 1);
        expect(viewModel.temNutrientes, isFalse);
        expect(viewModel.nutrientesConsumidos.kcal, 0);
        viewModel.dispose();
      });
    });
  });
}
