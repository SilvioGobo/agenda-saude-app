import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/domain/medicacao/remedio.dart';
import 'package:agenda_saude_app/domain/metas/calculadora_metas.dart';
import 'package:agenda_saude_app/domain/models/medicamento.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/refeicao_planejada.dart';
import 'package:agenda_saude_app/ui/triagem/triagem_viewmodel.dart';

void main() {
  group('TriagemViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late PacienteRepository pacienteRepository;
    late Paciente pacienteRecemCadastrado;
    late TriagemViewModel viewModel;

    void preencherDadosBasicos() {
      viewModel.definirDataNascimento(DateTime(1960, 5, 10));
      viewModel.selecionarSexoBiologico('Feminino');
      viewModel.definirAltura('165');
      viewModel.definirPeso('70');
      viewModel.selecionarNivelAtividadeFisica('Leve');
    }

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      pacienteRepository = PacienteRepository(firestore: fakeFirestore);
      pacienteRecemCadastrado = Paciente(
        id: 'paciente_001',
        nome: 'Maria Souza',
        email: 'maria@email.com',
        perfil: 'Paciente',
        possuiDiabetes: false,
        possuiCardiopatia: false,
        codigoVinculo: 'ABC123',
      );
      viewModel = TriagemViewModel(
        paciente: pacienteRecemCadastrado,
        pacienteRepository: pacienteRepository,
      );
    });

    test('Deve exigir as respostas de diabetes e cardiopatia', () async {
      final sucesso = await viewModel.concluirTriagem();

      expect(sucesso, false);
      expect(viewModel.mensagemErro, isNotNull);
    });

    test('Deve exigir o tipo e o uso de insulina quando responder sim para diabetes', () async {
      viewModel.responderDiabetes(true);
      viewModel.responderCardiopatia(false);
      preencherDadosBasicos();

      final sucesso = await viewModel.concluirTriagem();

      expect(sucesso, false);
      expect(viewModel.mensagemErro, isNotNull);
    });

    test('Deve exigir resposta sobre marcapasso quando responder sim para cardiopatia', () async {
      viewModel.responderDiabetes(false);
      viewModel.responderCardiopatia(true);
      preencherDadosBasicos();

      final sucesso = await viewModel.concluirTriagem();

      expect(sucesso, false);
      expect(viewModel.mensagemErro, isNotNull);
    });

    test('Deve exigir data de nascimento, sexo, altura, peso e atividade física', () async {
      viewModel.responderDiabetes(false);
      viewModel.responderCardiopatia(false);

      final sucesso = await viewModel.concluirTriagem();

      expect(sucesso, false);
      expect(viewModel.mensagemErro, isNotNull);
    });

    test('Deve rejeitar altura e peso fora de uma faixa razoável', () async {
      viewModel.responderDiabetes(false);
      viewModel.responderCardiopatia(false);
      viewModel.definirDataNascimento(DateTime(1960, 5, 10));
      viewModel.selecionarSexoBiologico('Feminino');
      viewModel.definirAltura('0');
      viewModel.definirPeso('70');
      viewModel.selecionarNivelAtividadeFisica('Leve');

      final sucesso = await viewModel.concluirTriagem();

      expect(sucesso, false);
      expect(viewModel.mensagemErro, isNotNull);
    });

    test('Deve limpar o tipo e o uso de insulina ao mudar a resposta de diabetes para não', () {
      viewModel.responderDiabetes(true);
      viewModel.selecionarTipoDiabetes('Tipo 1');
      viewModel.responderUsaInsulina(true);
      viewModel.responderDiabetes(false);

      expect(viewModel.tipoDiabetes, isNull);
      expect(viewModel.usaInsulina, isNull);
    });

    test('Deve manter o telefone do cadastro ao concluir a triagem', () async {
      // A triagem grava o paciente inteiro por cima do documento: o telefone
      // digitado no cadastro nao pode se perder ai.
      final comTelefone = TriagemViewModel(
        paciente: Paciente(
          id: 'paciente_001',
          nome: 'Maria Souza',
          email: 'maria@email.com',
          perfil: 'Paciente',
          telefone: '67999990000',
          possuiDiabetes: false,
          possuiCardiopatia: false,
          codigoVinculo: 'ABC123',
        ),
        pacienteRepository: pacienteRepository,
      );
      comTelefone.responderDiabetes(false);
      comTelefone.responderCardiopatia(false);
      comTelefone.definirDataNascimento(DateTime(1960, 5, 10));
      comTelefone.selecionarSexoBiologico('Feminino');
      comTelefone.definirAltura('165');
      comTelefone.definirPeso('70');
      comTelefone.selecionarNivelAtividadeFisica('Leve');

      final sucesso = await comTelefone.concluirTriagem();

      expect(sucesso, true);
      expect(comTelefone.pacienteAtualizado!.telefone, '67999990000');
      final pacienteSalvo = await pacienteRepository.getPaciente('paciente_001');
      expect(pacienteSalvo!.telefone, '67999990000');
      expect(pacienteSalvo.temTelefone, true);
    });

    test('Deve salvar a triagem completa com diabetes Tipo 2, insulina e cardiopatia com marcapasso', () async {
      viewModel.responderDiabetes(true);
      viewModel.selecionarTipoDiabetes('Tipo 2');
      viewModel.responderUsaInsulina(true);
      viewModel.definirTipoInsulina('NPH');

      viewModel.responderCardiopatia(true);
      viewModel.definirTipoCardiopatia('Hipertensão');
      viewModel.responderUsaMarcapasso(true);
      viewModel.responderRestricaoLiquido(true);
      viewModel.definirLimiteLiquido('1,5');

      preencherDadosBasicos();
      viewModel.adicionarAlergiaAlimento('Camarão');
      viewModel.adicionarAlergiaRemedio('Dipirona');
      viewModel.definirOutrasAlergias(' Látex ');
      viewModel.adicionarMedicamentoEmUso(
        const Remedio(nome: 'Losartana potássica', substancias: ['Losartana']),
      );
      viewModel.adicionarMedicamentoEmUso(
        const Remedio(nome: 'Sinvastatina', substancias: ['Sinvastatina']),
      );

      final sucesso = await viewModel.concluirTriagem();

      expect(sucesso, true);
      expect(viewModel.mensagemErro, isNull);

      final pacienteSalvo =
          await pacienteRepository.getPaciente('paciente_001');

      expect(pacienteSalvo, isNotNull);
      expect(pacienteSalvo!.possuiDiabetes, true);
      expect(pacienteSalvo.tipoDiabetes, 'Tipo 2');
      expect(pacienteSalvo.usaInsulina, true);
      expect(pacienteSalvo.tipoInsulina, 'NPH');
      expect(pacienteSalvo.possuiCardiopatia, true);
      expect(pacienteSalvo.tipoCardiopatia, 'Hipertensão');
      expect(pacienteSalvo.usaMarcapasso, true);
      expect(pacienteSalvo.dataNascimento, DateTime(1960, 5, 10));
      expect(pacienteSalvo.sexoBiologico, 'Feminino');
      expect(pacienteSalvo.alturaCm, 165);
      expect(pacienteSalvo.pesoKg, 70);
      expect(pacienteSalvo.nivelAtividadeFisica, 'Leve');
      expect(pacienteSalvo.alergiasAlimentos, ['Camarão']);
      expect(pacienteSalvo.alergiasRemedios, ['Dipirona']);
      expect(pacienteSalvo.alergias, 'Látex');
      expect(
        pacienteSalvo.medicamentosEmUso.map((r) => r.nome),
        ['Losartana potássica', 'Sinvastatina'],
      );
      expect(pacienteSalvo.medicamentosEmUso.first.substancias, ['Losartana']);
      expect(pacienteSalvo.triagemConcluida, true);
      expect(pacienteSalvo.limiteLiquidoMl, 1500);
      // A meta de agua calculada (2100 ml) e cortada pela restricao do medico.
      expect(pacienteSalvo.metas!.hidratacaoMl, 1500);
    });

    test('validarEAvancarSobreVoce deve falhar sem os dados básicos', () {
      expect(viewModel.validarEAvancarSobreVoce(), false);
      expect(viewModel.mensagemErro, isNotNull);
    });

    test('validarEAvancarSobreVoce deve passar com os dados básicos preenchidos', () {
      preencherDadosBasicos();

      expect(viewModel.validarEAvancarSobreVoce(), true);
      expect(viewModel.mensagemErro, isNull);
    });

    test('validarEAvancarDiabetes deve passar quando a resposta é não', () {
      viewModel.responderDiabetes(false);

      expect(viewModel.validarEAvancarDiabetes(), true);
      expect(viewModel.mensagemErro, isNull);
    });

    test('validarEAvancarDiabetes deve falhar sem responder', () {
      expect(viewModel.validarEAvancarDiabetes(), false);
      expect(viewModel.mensagemErro, isNotNull);
    });

    test('validarEAvancarCardiopatia deve passar quando a resposta é não', () {
      viewModel.responderCardiopatia(false);

      expect(viewModel.validarEAvancarCardiopatia(), true);
      expect(viewModel.mensagemErro, isNull);
    });

    test('validarEAvancarCardiopatia deve falhar sem responder', () {
      expect(viewModel.validarEAvancarCardiopatia(), false);
      expect(viewModel.mensagemErro, isNotNull);
    });

    test('Deve salvar a triagem sem nenhuma comorbidade e sem dados opcionais', () async {
      viewModel.responderDiabetes(false);
      viewModel.responderCardiopatia(false);
      preencherDadosBasicos();

      final sucesso = await viewModel.concluirTriagem();

      expect(sucesso, true);

      final pacienteSalvo =
          await pacienteRepository.getPaciente('paciente_001');

      expect(pacienteSalvo!.possuiDiabetes, false);
      expect(pacienteSalvo.tipoDiabetes, isNull);
      expect(pacienteSalvo.usaInsulina, isNull);
      expect(pacienteSalvo.possuiCardiopatia, false);
      expect(pacienteSalvo.usaMarcapasso, isNull);
      expect(pacienteSalvo.alergias, isNull);
      expect(pacienteSalvo.alergiasAlimentos, isEmpty);
      expect(pacienteSalvo.alergiasRemedios, isEmpty);
      expect(pacienteSalvo.medicamentosEmUso, isEmpty);
      expect(pacienteSalvo.triagemConcluida, true);
      expect(pacienteSalvo.limiteLiquidoMl, isNull);
    });

    test('Deve escolher alergias sem repetir e tirar as que não quer', () {
      viewModel.adicionarAlergiaAlimento('Camarão');
      viewModel.adicionarAlergiaAlimento('camarao');
      viewModel.adicionarAlergiaAlimento('Amendoim');
      viewModel.tirarAlergiaAlimento('Camarão');
      viewModel.adicionarAlergiaRemedio('Dipirona');
      viewModel.adicionarAlergiaRemedio('DIPIRONA');

      expect(viewModel.alergiasAlimentos, ['Amendoim']);
      expect(viewModel.alergiasRemedios, ['Dipirona']);
    });

    test('Deve apontar o remédio em uso que tem algo das alergias', () {
      const novalgina = Remedio(nome: 'Novalgina', substancias: ['Dipirona']);
      const losartana = Remedio(nome: 'Losartana', substancias: ['Losartana']);
      viewModel.adicionarMedicamentoEmUso(novalgina);
      viewModel.adicionarMedicamentoEmUso(novalgina);
      viewModel.adicionarMedicamentoEmUso(losartana);

      expect(viewModel.alergiaDoMedicamentoEmUso(novalgina), isNull);

      viewModel.adicionarAlergiaRemedio('Dipirona');

      expect(viewModel.medicamentosEmUso, [novalgina, losartana]);
      expect(viewModel.alergiaDoMedicamentoEmUso(novalgina), 'Dipirona');
      expect(viewModel.alergiaDoMedicamentoEmUso(losartana), isNull);

      viewModel.tirarMedicamentoEmUso(novalgina);
      expect(viewModel.medicamentosEmUso, [losartana]);
    });

    test('Deve calcular e salvar as metas ao concluir a triagem', () async {
      viewModel.responderDiabetes(false);
      viewModel.responderCardiopatia(false);
      preencherDadosBasicos();

      final sucesso = await viewModel.concluirTriagem();

      expect(sucesso, true);
      final metas = viewModel.pacienteAtualizado!.metas;
      expect(metas, isNotNull);
      expect(metas!.calorias, greaterThanOrEqualTo(1200));
      expect(metas.hidratacaoMl, greaterThanOrEqualTo(1500));
      expect(metas.ajustadaManualmente, false);

      final pacienteSalvo =
          await pacienteRepository.getPaciente('paciente_001');
      expect(pacienteSalvo!.metas, isNotNull);
      expect(pacienteSalvo.metas!.calorias, metas.calorias);
      expect(pacienteSalvo.metas!.passos, metas.passos);
    });

    test('Deve concluir a triagem sem metas quando os dados não permitem calcular', () async {
      viewModel.responderDiabetes(false);
      viewModel.responderCardiopatia(false);
      preencherDadosBasicos();
      viewModel.definirDataNascimento(DateTime.now().subtract(
        const Duration(days: 365 * 10),
      ));

      final sucesso = await viewModel.concluirTriagem();

      expect(sucesso, true);
      expect(viewModel.pacienteAtualizado!.metas, isNull);
      final pacienteSalvo =
          await pacienteRepository.getPaciente('paciente_001');
      expect(pacienteSalvo!.metas, isNull);
      expect(pacienteSalvo.triagemConcluida, true);
    });

    test('validarEAvancarCardiopatia deve exigir a resposta sobre restrição de líquido', () {
      viewModel.responderCardiopatia(true);
      viewModel.responderUsaMarcapasso(false);

      expect(viewModel.validarEAvancarCardiopatia(), false);
      expect(viewModel.mensagemErro, isNotNull);

      viewModel.responderRestricaoLiquido(false);

      expect(viewModel.validarEAvancarCardiopatia(), true);
    });

    test('validarEAvancarCardiopatia deve exigir um limite de litros plausível', () {
      viewModel.responderCardiopatia(true);
      viewModel.responderUsaMarcapasso(false);
      viewModel.responderRestricaoLiquido(true);

      expect(viewModel.validarEAvancarCardiopatia(), false);

      viewModel.definirLimiteLiquido('0,2');
      expect(viewModel.validarEAvancarCardiopatia(), false);

      viewModel.definirLimiteLiquido('6');
      expect(viewModel.validarEAvancarCardiopatia(), false);

      viewModel.definirLimiteLiquido('abc');
      expect(viewModel.validarEAvancarCardiopatia(), false);

      viewModel.definirLimiteLiquido('1,5');
      expect(viewModel.validarEAvancarCardiopatia(), true);
      expect(viewModel.mensagemErro, isNull);
    });

    test('Deve limpar a restrição de líquido ao mudar a resposta de cardiopatia para não', () {
      viewModel.responderCardiopatia(true);
      viewModel.responderRestricaoLiquido(true);
      viewModel.definirLimiteLiquido('2');
      viewModel.responderCardiopatia(false);

      expect(viewModel.possuiRestricaoLiquido, isNull);
      expect(viewModel.limiteLiquidoLitros, isNull);
    });

    test('Deve esquecer o limite de litros ao mudar a restrição de líquido para não', () {
      viewModel.responderCardiopatia(true);
      viewModel.responderRestricaoLiquido(true);
      viewModel.definirLimiteLiquido('2');
      viewModel.responderRestricaoLiquido(false);

      expect(viewModel.limiteLiquidoLitros, isNull);
    });
  });

  group('TriagemViewModel em "Meus dados" Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late PacienteRepository repositorio;
    late Paciente paciente;

    // Um paciente com a triagem feita, o plano de refeicoes, um remedio e as
    // metas com um ajuste feito a mao (passos).
    Paciente pacienteComTriagem() {
      final base = Paciente(
        id: 'paciente_001',
        nome: 'Maria Souza',
        email: 'maria@email.com',
        perfil: 'Paciente',
        codigoVinculo: 'ABC123',
        triagemConcluida: true,
        possuiDiabetes: true,
        tipoDiabetes: 'Tipo 2',
        usaInsulina: true,
        tipoInsulina: 'NPH',
        possuiCardiopatia: true,
        tipoCardiopatia: 'Hipertensão',
        usaMarcapasso: false,
        limiteLiquidoMl: 1500,
        dataNascimento: DateTime(1958, 3, 2),
        sexoBiologico: 'Feminino',
        alturaCm: 165,
        pesoKg: 70,
        nivelAtividadeFisica: 'Leve',
        alergiasAlimentos: const ['Camarão'],
        alergiasRemedios: const ['Dipirona'],
        alergias: 'Látex',
        medicamentosEmUso: const [
          Remedio(nome: 'Losartana potássica', substancias: ['Losartana']),
        ],
        refeicoes: const [RefeicaoPlanejada(id: 'r1', nome: 'Café')],
        medicamentos: const [
          Medicamento(id: 'm1', nome: 'Losartana', horarios: ['08:00']),
        ],
      );
      final metas = CalculadoraMetas.calcular(base)!.comAjustes(
        passos: 4000,
        hidratacaoMl: 1250,
      );
      return base.copyWith(metas: metas);
    }

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      repositorio = PacienteRepository(firestore: fakeFirestore);
      paciente = pacienteComTriagem();
      // O documento tem tambem o que o app grava fora do modelo (as tarefas
      // do dia da pendencia, B9).
      await fakeFirestore.collection('usuarios').doc(paciente.id).set({
        ...paciente.toJson(),
        'tarefasDiarias': [
          {'chave': 'm1@08:00', 'horario': '08:00'},
        ],
        'fusoHorarioMinutos': -240,
      });
    });

    TriagemViewModel editar() => TriagemViewModel(
          paciente: paciente,
          pacienteRepository: repositorio,
          edicao: true,
        );

    test('Deve abrir com as respostas que o paciente já deu', () {
      final viewModel = editar();

      expect(viewModel.possuiDiabetes, isTrue);
      expect(viewModel.tipoDiabetes, 'Tipo 2');
      expect(viewModel.usaInsulina, isTrue);
      expect(viewModel.tipoInsulina, 'NPH');
      expect(viewModel.possuiCardiopatia, isTrue);
      expect(viewModel.tipoCardiopatia, 'Hipertensão');
      expect(viewModel.usaMarcapasso, isFalse);
      expect(viewModel.possuiRestricaoLiquido, isTrue);
      expect(viewModel.limiteLiquidoLitros, 1.5);
      expect(viewModel.dataNascimento, DateTime(1958, 3, 2));
      expect(viewModel.sexoBiologico, 'Feminino');
      expect(viewModel.alturaCm, 165);
      expect(viewModel.pesoKg, 70);
      expect(viewModel.nivelAtividadeFisica, 'Leve');
      expect(viewModel.alergiasAlimentos, ['Camarão']);
      expect(viewModel.alergiasRemedios, ['Dipirona']);
      expect(viewModel.outrasAlergias, 'Látex');
      expect(viewModel.medicamentosEmUso.single.nome, 'Losartana potássica');
      // O primeiro acesso continua comecando em branco.
      expect(viewModel.possuiDiabetes, isNotNull);
      expect(
        TriagemViewModel(paciente: paciente, pacienteRepository: repositorio)
            .possuiDiabetes,
        isNull,
      );
    });

    test('Deve gravar só os dados da triagem, sem apagar o resto do documento',
        () async {
      final viewModel = editar()
        ..definirPeso('76,5')
        ..adicionarAlergiaAlimento('Amendoim')
        ..tirarAlergiaRemedio('Dipirona');

      expect(await viewModel.salvarAlteracoes(), isTrue);

      final gravado =
          (await fakeFirestore.collection('usuarios').doc(paciente.id).get())
              .data()!;
      expect(gravado['pesoKg'], 76.5);
      expect(gravado['alergiasAlimentos'], ['Camarão', 'Amendoim']);
      expect(gravado['alergiasRemedios'], isEmpty);
      // O que nao e da triagem continua la.
      expect(gravado['tarefasDiarias'], hasLength(1));
      expect(gravado['fusoHorarioMinutos'], -240);
      expect((gravado['refeicoes'] as List).single['nome'], 'Café');
      expect((gravado['medicamentos'] as List).single['nome'], 'Losartana');
      expect(gravado['codigoVinculo'], 'ABC123');
      // E o paciente devolvido para o painel tambem.
      final atualizado = viewModel.pacienteAtualizado!;
      expect(atualizado.pesoKg, 76.5);
      expect(atualizado.refeicoes!.single.nome, 'Café');
      expect(atualizado.medicamentos.single.nome, 'Losartana');
    });

    test('Deve recalcular as metas e manter o que o paciente ajustou à mão',
        () async {
      final antes = paciente.metas!;
      final viewModel = editar()..definirPeso('90');

      await viewModel.salvarAlteracoes();

      final metas = viewModel.pacienteAtualizado!.metas!;
      expect(metas.calorias, isNot(antes.calorias));
      expect(metas.passos, 4000);
      expect(metas.hidratacaoMl, 1250);
      expect(metas.ajustadaManualmente, isTrue);
    });

    test('A água ajustada à mão não passa da restrição nova do médico',
        () async {
      final viewModel = editar()..definirLimiteLiquido('1');

      await viewModel.salvarAlteracoes();

      final atualizado = viewModel.pacienteAtualizado!;
      expect(atualizado.limiteLiquidoMl, 1000);
      expect(atualizado.metas!.hidratacaoMl, 1000);
    });

    test('Tirar a cardiopatia apaga as respostas de dentro dela', () async {
      final viewModel = editar()..responderCardiopatia(false);

      await viewModel.salvarAlteracoes();

      final gravado = await repositorio.getPaciente(paciente.id);
      expect(gravado!.possuiCardiopatia, isFalse);
      expect(gravado.tipoCardiopatia, isNull);
      expect(gravado.usaMarcapasso, isNull);
      expect(gravado.limiteLiquidoMl, isNull);
    });

    test('Deve pedir o que falta e não gravar nada', () async {
      final viewModel = editar()
        ..responderCardiopatia(false)
        ..responderCardiopatia(true);

      expect(await viewModel.salvarAlteracoes(), isFalse);
      expect(viewModel.mensagemErro, 'Complete as perguntas sobre cardiopatia.');
      final gravado = await repositorio.getPaciente(paciente.id);
      expect(gravado!.usaMarcapasso, isFalse);
    });

    test('Deve avisar quando não consegue salvar', () async {
      final semDocumento = TriagemViewModel(
        paciente: paciente,
        pacienteRepository:
            PacienteRepository(firestore: FakeFirebaseFirestore()),
        edicao: true,
      );

      expect(await semDocumento.salvarAlteracoes(), isFalse);
      expect(
        semDocumento.mensagemErro,
        'Não foi possível salvar seus dados. Tente de novo.',
      );
      expect(semDocumento.carregando, isFalse);
    });
  });
}
