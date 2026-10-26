import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_diabete.dart';
import 'package:agenda_saude_app/ui/acompanhante/diabetes_acompanhante_viewmodel.dart';

void main() {
  group('DiabetesAcompanhanteViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    late DiabetesAcompanhanteViewModel viewModel;

    Paciente criarPaciente(String id, {required bool possuiDiabetes}) => Paciente(
          id: id,
          nome: 'Paciente $id',
          email: '$id@email.com',
          perfil: 'Paciente',
          possuiDiabetes: possuiDiabetes,
          possuiCardiopatia: false,
          codigoVinculo: 'ABC123',
        );

    Future<void> salvar(
      String pacienteId,
      DateTime dataHora, {
      double? glicose,
      double? dose,
    }) {
      return dadosRepository.salvarRegistro(RegistroDiabete(
        id: '',
        pacienteId: pacienteId,
        dataHora: dataHora,
        nivelGlicose: glicose,
        momento: 'Ao acordar',
        doseInsulina: dose,
        tipoInsulina: dose == null ? null : 'Lenta',
      ));
    }

    Future<void> aguardar() => Future<void>.delayed(Duration.zero);

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
      viewModel = DiabetesAcompanhanteViewModel(dadosRepository: dadosRepository);
    });

    tearDown(() => viewModel.dispose());

    test('Deve separar a última glicemia e a última dose de insulina', () async {
      await salvar('p1', DateTime(2026, 10, 24, 22, 0), dose: 14);
      await salvar('p1', DateTime(2026, 10, 25, 7, 0), glicose: 120);
      await salvar('p1', DateTime(2026, 10, 24, 18, 0), glicose: 200);

      viewModel.acompanharPacientes([criarPaciente('p1', possuiDiabetes: true)]);
      await aguardar();

      final resumo = viewModel.resumoDe('p1')!;
      expect(resumo.ultimaGlicemia!.nivelGlicose, 120);
      expect(resumo.ultimaInsulina!.doseInsulina, 14);
    });

    test('Deve ter resumo vazio para diabético sem registros', () async {
      viewModel.acompanharPacientes([criarPaciente('p1', possuiDiabetes: true)]);
      await aguardar();

      final resumo = viewModel.resumoDe('p1')!;
      expect(resumo.ultimaGlicemia, isNull);
      expect(resumo.ultimaInsulina, isNull);
    });

    test('Não deve acompanhar pacientes sem diabetes', () async {
      await salvar('p2', DateTime(2026, 10, 25, 7, 0), glicose: 120);

      viewModel.acompanharPacientes([criarPaciente('p2', possuiDiabetes: false)]);
      await aguardar();

      expect(viewModel.resumoDe('p2'), isNull);
    });

    test('Deve atualizar em tempo real e parar de acompanhar quem foi desvinculado', () async {
      final paciente = criarPaciente('p1', possuiDiabetes: true);
      viewModel.acompanharPacientes([paciente]);
      await aguardar();
      expect(viewModel.resumoDe('p1')!.ultimaGlicemia, isNull);

      await salvar('p1', DateTime(2026, 10, 25, 7, 0), glicose: 65);
      await aguardar();
      expect(viewModel.resumoDe('p1')!.ultimaGlicemia!.nivelGlicose, 65);

      viewModel.acompanharPacientes([]);
      expect(viewModel.resumoDe('p1'), isNull);
    });
  });
}
