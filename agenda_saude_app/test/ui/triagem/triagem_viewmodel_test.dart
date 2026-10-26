import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
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
      viewModel.definirAlergias('Dipirona');
      viewModel.definirMedicamentosEmUso('Losartana');

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
      expect(pacienteSalvo.alergias, 'Dipirona');
      expect(pacienteSalvo.medicamentosEmUso, 'Losartana');
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
      expect(pacienteSalvo.medicamentosEmUso, isNull);
      expect(pacienteSalvo.triagemConcluida, true);
      expect(pacienteSalvo.limiteLiquidoMl, isNull);
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
}
