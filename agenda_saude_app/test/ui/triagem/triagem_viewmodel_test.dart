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
    });
  });
}
