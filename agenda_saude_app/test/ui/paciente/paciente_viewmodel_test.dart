import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/batimento_cardiaco.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/paciente/paciente_viewmodel.dart';

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

    test('Deve indicar status "atenção" quando o BPM sai da zona de segurança', () async {
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

      expect(viewModel.statusCardiaco, StatusCardiaco.atencao);
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

      expect(viewModel.statusCardiaco, StatusCardiaco.atencao);
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
  });
}
