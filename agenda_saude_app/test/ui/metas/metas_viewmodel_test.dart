import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/domain/metas/calculadora_metas.dart';
import 'package:agenda_saude_app/domain/metas/metas_personalizadas.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/metas/metas_viewmodel.dart';

// Simula a perda de conexao ao gravar.
class _RepositorioQueFalha extends PacienteRepository {
  _RepositorioQueFalha(FakeFirebaseFirestore firestore)
    : super(firestore: firestore);

  @override
  Future<void> atualizarMetas(
    String pacienteId,
    MetasPersonalizadas metas, {
    double? pesoKg,
    String? nivelAtividadeFisica,
  }) {
    throw Exception('sem conexao');
  }
}

void main() {
  group('MetasViewModel Testes', () {
    final hoje = DateTime(2026, 10, 25);

    late FakeFirebaseFirestore fakeFirestore;
    late PacienteRepository repositorio;
    late List<Paciente> atualizacoes;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repositorio = PacienteRepository(firestore: fakeFirestore);
      atualizacoes = [];
    });

    // Idosa de 70 anos, 60 kg, sedentaria: 7 copos (1750 ml), 4000 passos,
    // 150 minutos de exercicio por semana. Ja salva no banco simulado.
    Future<Paciente> criarPaciente({
      int? limiteLiquidoMl,
      bool ajustada = false,
      String? sexo = 'Feminino',
      double? altura = 155,
    }) async {
      final semMetas = Paciente(
        id: 'paciente_01',
        nome: 'Maria Souza',
        email: 'maria@email.com',
        perfil: 'Paciente',
        possuiDiabetes: false,
        possuiCardiopatia: false,
        codigoVinculo: 'ABC123',
        triagemConcluida: true,
        dataNascimento: DateTime(1956, 3, 1),
        sexoBiologico: sexo,
        alturaCm: altura,
        pesoKg: 60,
        nivelAtividadeFisica: 'Sedentário',
        limiteLiquidoMl: limiteLiquidoMl,
      );
      var metas = CalculadoraMetas.calcular(semMetas, hoje: hoje);
      if (ajustada && metas != null) metas = metas.comAjustes(passos: 3000);
      final paciente = metas == null
          ? semMetas
          : semMetas.copyWith(metas: metas);
      await repositorio.salvarPaciente(paciente);
      return paciente;
    }

    MetasViewModel criar(Paciente paciente, {PacienteRepository? repo}) {
      return MetasViewModel(
        paciente: paciente,
        pacienteRepository: repo ?? repositorio,
        aoAtualizar: atualizacoes.add,
        agora: () => hoje,
      );
    }

    Future<Map<String, dynamic>> metasSalvas() async {
      final doc = await fakeFirestore
          .collection('usuarios')
          .doc('paciente_01')
          .get();
      return Map<String, dynamic>.from(doc.data()!['metas'] as Map);
    }

    test('Deve expor as metas calculadas do paciente', () async {
      final viewModel = criar(await criarPaciente());

      expect(viewModel.metas, isNotNull);
      expect(viewModel.metas!.hidratacaoCopos, 7);
      expect(viewModel.metas!.passos, 4000);
      expect(viewModel.precisaConfirmarRecalculo, false);
    });

    test(
      'Deve gravar os ajustes, marcar como ajustada e avisar quem escuta',
      () async {
        final viewModel = criar(await criarPaciente());

        final salvou = await viewModel.salvarAjustes(
          hidratacaoMl: 2000,
          passos: 5000,
          exercicioMinutosSemana: 120,
        );

        expect(salvou, true);
        expect(viewModel.metas!.hidratacaoMl, 2000);
        expect(viewModel.metas!.passos, 5000);
        expect(viewModel.metas!.exercicioMinutosSemana, 120);
        expect(viewModel.metas!.ajustadaManualmente, true);
        expect(viewModel.precisaConfirmarRecalculo, true);
        expect(viewModel.mensagemErro, isNull);
        expect(atualizacoes.single.metas!.passos, 5000);

        final salvas = await metasSalvas();
        expect(salvas['passos'], 5000);
        expect(salvas['ajustadaManualmente'], true);
        // As metas de alimentacao nao mudam com o ajuste.
        expect(salvas['calorias'], viewModel.metas!.calorias);
      },
    );

    test(
      'Não deve gravar nem marcar como ajustada quando nada mudou',
      () async {
        final paciente = await criarPaciente();
        final viewModel = criar(paciente);
        final metas = paciente.metas!;

        final salvou = await viewModel.salvarAjustes(
          hidratacaoMl: metas.hidratacaoMl,
          passos: metas.passos,
          exercicioMinutosSemana: metas.exercicioMinutosSemana,
        );

        expect(salvou, true);
        expect(viewModel.metas!.ajustadaManualmente, false);
        expect(atualizacoes, isEmpty);
        expect((await metasSalvas())['ajustadaManualmente'], false);
      },
    );

    test('Deve manter os ajustes dentro dos limites', () async {
      final viewModel = criar(await criarPaciente());

      await viewModel.salvarAjustes(
        hidratacaoMl: 99999,
        passos: 1,
        exercicioMinutosSemana: 9999,
      );

      expect(
        viewModel.metas!.hidratacaoMl,
        MetasViewModel.hidratacaoMaximaPadraoMl,
      );
      expect(viewModel.metas!.passos, MetasViewModel.passosMinimo);
      expect(
        viewModel.metas!.exercicioMinutosSemana,
        MetasViewModel.exercicioMaximoMinutos,
      );
    });

    test('Deve limitar a água ao que o médico permitiu', () async {
      final viewModel = criar(await criarPaciente(limiteLiquidoMl: 2000));

      expect(viewModel.hidratacaoMaximaMl, 2000);

      await viewModel.salvarAjustes(
        hidratacaoMl: 3000,
        passos: 4000,
        exercicioMinutosSemana: 150,
      );

      expect(viewModel.metas!.hidratacaoMl, 2000);
    });

    test(
      'Deve aceitar uma restrição de líquido menor que o mínimo de ajuste',
      () async {
        final viewModel = criar(await criarPaciente(limiteLiquidoMl: 600));

        // 600 ml fecham 2 copos de 250 ml.
        expect(viewModel.hidratacaoMaximaMl, 500);
        expect(viewModel.hidratacaoMinimaAjusteMl, 500);
      },
    );

    test(
      'Deve recalcular com o novo peso e nível de atividade e gravar tudo',
      () async {
        final paciente = await criarPaciente();
        final viewModel = criar(paciente);

        final recalculou = await viewModel.recalcular(
          pesoTexto: '90,5',
          nivelAtividade: 'Moderado',
        );

        expect(recalculou, true);
        expect(viewModel.paciente.pesoKg, 90.5);
        expect(viewModel.paciente.nivelAtividadeFisica, 'Moderado');
        // 30 ml/kg x 90,5 kg = 2715 ml -> 11 copos.
        expect(viewModel.metas!.hidratacaoMl, 2750);
        expect(viewModel.metas!.passos, 6000);
        expect(viewModel.metas!.calorias, isNot(paciente.metas!.calorias));
        expect(atualizacoes.single.pesoKg, 90.5);

        final doc = await fakeFirestore
            .collection('usuarios')
            .doc('paciente_01')
            .get();
        expect(doc.data()!['pesoKg'], 90.5);
        expect(doc.data()!['nivelAtividadeFisica'], 'Moderado');
        expect((doc.data()!['metas'] as Map)['hidratacaoMl'], 2750);
      },
    );

    test('Deve substituir os ajustes manuais ao recalcular', () async {
      final viewModel = criar(await criarPaciente(ajustada: true));
      expect(viewModel.precisaConfirmarRecalculo, true);

      await viewModel.recalcular(pesoTexto: '60', nivelAtividade: 'Sedentário');

      expect(viewModel.metas!.passos, 4000);
      expect(viewModel.metas!.ajustadaManualmente, false);
      expect(viewModel.precisaConfirmarRecalculo, false);
    });

    test('Deve respeitar a restrição de líquido ao recalcular', () async {
      final viewModel = criar(await criarPaciente(limiteLiquidoMl: 1500));

      await viewModel.recalcular(pesoTexto: '90', nivelAtividade: 'Leve');

      expect(viewModel.metas!.hidratacaoMl, 1500);
    });

    test('Deve recusar um peso inválido sem gravar nada', () async {
      final viewModel = criar(await criarPaciente());

      for (final peso in ['', 'abc', '10', '500']) {
        final recalculou = await viewModel.recalcular(
          pesoTexto: peso,
          nivelAtividade: 'Leve',
        );

        expect(recalculou, false, reason: 'peso "$peso"');
        expect(viewModel.mensagemErro, 'Confira o valor do peso.');
      }
      expect(atualizacoes, isEmpty);
      expect(viewModel.paciente.pesoKg, 60);
    });

    test('Deve avisar quando faltam dados do cadastro para calcular', () async {
      final viewModel = criar(await criarPaciente(altura: null));
      expect(viewModel.metas, isNull);

      final recalculou = await viewModel.recalcular(
        pesoTexto: '70',
        nivelAtividade: 'Leve',
      );

      expect(recalculou, false);
      expect(viewModel.mensagemErro, contains('Faltam dados do seu cadastro'));
      expect(atualizacoes, isEmpty);
    });

    test(
      'Deve mostrar erro e manter as metas quando a gravação falha',
      () async {
        final paciente = await criarPaciente();
        final viewModel = criar(
          paciente,
          repo: _RepositorioQueFalha(fakeFirestore),
        );

        final salvou = await viewModel.salvarAjustes(
          hidratacaoMl: 2000,
          passos: 5000,
          exercicioMinutosSemana: 150,
        );
        expect(salvou, false);
        expect(viewModel.mensagemErro, contains('Não foi possível salvar'));
        expect(viewModel.carregando, false);
        expect(viewModel.metas!.passos, 4000);

        final recalculou = await viewModel.recalcular(
          pesoTexto: '70',
          nivelAtividade: 'Leve',
        );
        expect(recalculou, false);
        expect(viewModel.mensagemErro, contains('Não foi possível recalcular'));
        expect(viewModel.paciente.pesoKg, 60);
        expect(atualizacoes, isEmpty);
      },
    );

    test('Não deve ajustar quando o paciente ainda não tem metas', () async {
      final viewModel = criar(await criarPaciente(altura: null));

      final salvou = await viewModel.salvarAjustes(
        hidratacaoMl: 2000,
        passos: 5000,
        exercicioMinutosSemana: 150,
      );

      expect(salvou, false);
    });
  });
}
