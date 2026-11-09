import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/auth_repository.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/batimento_cardiaco.dart';
import 'package:agenda_saude_app/domain/models/limites_alerta.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/paciente/paciente_viewmodel.dart';

// Conta as saidas em vez de chamar o Firebase Auth de verdade.
class _AuthRepositoryFalso extends AuthRepository {
  int saidas = 0;

  @override
  Future<void> sair() async {
    saidas++;
  }
}

void main() {
  group('PacienteViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    late Paciente paciente;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
      paciente = Paciente(
        id: 'paciente_01',
        nome: 'José Silva',
        email: 'jose@email.com',
        perfil: 'Paciente',
        possuiDiabetes: false,
        possuiCardiopatia: false,
        codigoVinculo: 'ABC123',
      );
    });

    test('Deve exibir o primeiro nome do paciente', () {
      final viewModel = PacienteViewModel(
        paciente: paciente,
        dadosRepository: dadosRepository,
      );

      expect(viewModel.primeiroNome, 'José');
    });

    test('Deve indicar status "sem leitura" quando não há batimentos salvos', () {
      final viewModel = PacienteViewModel(
        paciente: paciente,
        dadosRepository: dadosRepository,
      );

      expect(viewModel.ultimoBatimento, isNull);
      expect(viewModel.statusCardiaco, StatusCardiaco.semLeitura);
    });

    test('Deve indicar status "estável" quando o BPM está na zona de segurança', () async {
      final viewModel = PacienteViewModel(
        paciente: paciente,
        dadosRepository: dadosRepository,
      );

      await dadosRepository.salvarBatimento(BatimentoCardiaco(
        id: '',
        pacienteId: paciente.id,
        bpm: 72,
        timestamp: DateTime.now(),
      ));
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.ultimoBatimento?.bpm, 72);
      expect(viewModel.statusCardiaco, StatusCardiaco.estavel);
    });

    test('Deve indicar status "alto" quando o BPM passa do máximo da zona', () async {
      final viewModel = PacienteViewModel(
        paciente: paciente,
        dadosRepository: dadosRepository,
      );

      await dadosRepository.salvarBatimento(BatimentoCardiaco(
        id: '',
        pacienteId: paciente.id,
        bpm: 128,
        timestamp: DateTime.now(),
      ));
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.statusCardiaco, StatusCardiaco.alto);
    });

    test('Deve indicar status "baixo" quando o BPM fica abaixo do mínimo da zona', () async {
      final viewModel = PacienteViewModel(
        paciente: paciente,
        dadosRepository: dadosRepository,
      );

      await dadosRepository.salvarBatimento(BatimentoCardiaco(
        id: '',
        pacienteId: paciente.id,
        bpm: 45,
        timestamp: DateTime.now(),
      ));
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.statusCardiaco, StatusCardiaco.baixo);
      expect(viewModel.bpmMinimo, 60);
    });

    test('Deve usar uma zona de segurança mais estreita para pacientes cardiopatas', () async {
      final pacienteCardiopata = Paciente(
        id: 'paciente_02',
        nome: 'Maria Souza',
        email: 'maria@email.com',
        perfil: 'Paciente',
        possuiDiabetes: false,
        possuiCardiopatia: true,
        codigoVinculo: 'XYZ789',
      );
      final viewModel = PacienteViewModel(
        paciente: pacienteCardiopata,
        dadosRepository: dadosRepository,
      );

      // 95 BPM é estável para a zona padrão, mas fica fora da zona mais
      // estreita usada para cardiopatas (UC04.4).
      await dadosRepository.salvarBatimento(BatimentoCardiaco(
        id: '',
        pacienteId: pacienteCardiopata.id,
        bpm: 95,
        timestamp: DateTime.now(),
      ));
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.statusCardiaco, StatusCardiaco.alto);
      expect(viewModel.bpmMaximo, 90);
    });

    test('Deve considerar apenas o batimento mais recente do paciente', () async {
      final viewModel = PacienteViewModel(
        paciente: paciente,
        dadosRepository: dadosRepository,
      );

      await dadosRepository.salvarBatimento(BatimentoCardiaco(
        id: '',
        pacienteId: paciente.id,
        bpm: 70,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      ));
      await dadosRepository.salvarBatimento(BatimentoCardiaco(
        id: '',
        pacienteId: paciente.id,
        bpm: 130,
        timestamp: DateTime.now(),
      ));
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.ultimoBatimento?.bpm, 130);
    });

    test('Deve encerrar a sessão ao sair da conta', () async {
      final authRepository = _AuthRepositoryFalso();
      final viewModel = PacienteViewModel(
        paciente: paciente,
        dadosRepository: dadosRepository,
        authRepository: authRepository,
      );

      await viewModel.sair();

      expect(authRepository.saidas, 1);
    });

    test('Deve trocar o paciente e avisar quem escuta ao atualizar', () {
      final viewModel = PacienteViewModel(
        paciente: paciente,
        dadosRepository: dadosRepository,
      );
      var avisos = 0;
      viewModel.addListener(() => avisos++);

      viewModel.atualizarPaciente(paciente.copyWith(pesoKg: 72));

      expect(viewModel.paciente.pesoKg, 72);
      expect(avisos, 1);
    });

    group('Limites de alerta (RF 06.1)', () {
      const limites = LimitesAlerta(
        bpmMinimo: 50,
        bpmMaximo: 120,
        atualizadoPor: 'cuidador_01',
      );

      setUp(() async {
        await fakeFirestore
            .collection('usuarios')
            .doc('paciente_01')
            .set({'perfil': 'Paciente'});
      });

      Future<void> aguardar() => Future<void>.delayed(Duration.zero);

      test('Deve mudar a zona do painel quando o acompanhante salva os limites', () async {
        final viewModel = PacienteViewModel(
          paciente: paciente,
          dadosRepository: dadosRepository,
        );
        await dadosRepository.salvarBatimento(BatimentoCardiaco(
          id: '',
          pacienteId: 'paciente_01',
          bpm: 110,
          timestamp: DateTime.now(),
        ));
        await aguardar();
        expect(viewModel.statusCardiaco, StatusCardiaco.alto);

        await dadosRepository.salvarLimitesAlerta('paciente_01', limites);
        await aguardar();
        expect(viewModel.bpmMinimo, 50);
        expect(viewModel.bpmMaximo, 120);
        expect(viewModel.statusCardiaco, StatusCardiaco.estavel);
        expect(viewModel.paciente.limitesAlerta, limites);

        await dadosRepository.salvarLimitesAlerta('paciente_01', null);
        await aguardar();
        expect(viewModel.bpmMaximo, 100);
        expect(viewModel.statusCardiaco, StatusCardiaco.alto);
        viewModel.dispose();
      });

      test('Não deve voltar aos limites antigos quando outra tela devolve o paciente', () async {
        final viewModel = PacienteViewModel(
          paciente: paciente,
          dadosRepository: dadosRepository,
        );
        await dadosRepository.salvarLimitesAlerta('paciente_01', limites);
        await aguardar();

        // Minha Rotina recebeu o paciente antes da mudanca dos limites.
        viewModel.atualizarPaciente(paciente.copyWith(pesoKg: 72));

        expect(viewModel.paciente.pesoKg, 72);
        expect(viewModel.paciente.limitesAlerta, limites);
        viewModel.dispose();
      });
    });
  });
}
