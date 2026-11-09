import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/batimento_cardiaco.dart';
import 'package:agenda_saude_app/domain/models/limites_alerta.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_agua.dart';
import 'package:agenda_saude_app/domain/models/registro_refeicao.dart';
import 'package:agenda_saude_app/ui/acompanhante/status_paciente_viewmodel.dart';

void main() {
  group('StatusPacienteViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    late DateTime agora;
    StatusPacienteViewModel? viewModel;

    Paciente criarPaciente({bool possuiCardiopatia = false}) => Paciente(
          id: 'paciente_01',
          nome: 'José Silva',
          email: 'jose@email.com',
          perfil: 'Paciente',
          possuiDiabetes: false,
          possuiCardiopatia: possuiCardiopatia,
          codigoVinculo: 'ABC123',
        );

    StatusPacienteViewModel criar({
      bool possuiCardiopatia = false,
      Duration intervaloRelogio = const Duration(minutes: 1),
    }) {
      final criado = StatusPacienteViewModel(
        paciente: criarPaciente(possuiCardiopatia: possuiCardiopatia),
        dadosRepository: dadosRepository,
        agora: () => agora,
        intervaloRelogio: intervaloRelogio,
      )..iniciar();
      viewModel = criado;
      return criado;
    }

    Future<void> salvarBatimento(int bpm, DateTime timestamp) {
      return dadosRepository.salvarBatimento(BatimentoCardiaco(
        id: '',
        pacienteId: 'paciente_01',
        bpm: bpm,
        timestamp: timestamp,
      ));
    }

    Future<void> aguardar() => Future<void>.delayed(Duration.zero);

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
      agora = DateTime(2026, 11, 6, 15, 0);
      viewModel = null;
    });

    tearDown(() => viewModel?.dispose());

    test('Deve ficar carregando até a primeira leitura e mostrar SEM DADOS sem batimentos', () async {
      final vm = criar();
      expect(vm.carregando, isTrue);

      await aguardar();

      expect(vm.carregando, isFalse);
      expect(vm.ultimoBatimento, isNull);
      expect(vm.status, StatusSaude.semDados);
    });

    test('Deve mostrar ESTÁVEL com leitura recente dentro da zona', () async {
      await salvarBatimento(72, agora.subtract(const Duration(minutes: 3)));
      final vm = criar();
      await aguardar();

      expect(vm.ultimoBatimento!.bpm, 72);
      expect(vm.leituraRecente, isTrue);
      expect(vm.status, StatusSaude.estavel);
    });

    test('Deve mostrar ATENÇÃO com leitura acima ou abaixo da zona', () async {
      await salvarBatimento(128, agora.subtract(const Duration(minutes: 1)));
      final vm = criar();
      await aguardar();
      expect(vm.status, StatusSaude.atencao);

      await salvarBatimento(45, agora);
      await aguardar();
      expect(vm.ultimoBatimento!.bpm, 45);
      expect(vm.status, StatusSaude.atencao);
    });

    test('Deve usar a zona mais estreita para o cardiopata', () async {
      await salvarBatimento(95, agora);

      final semCardiopatia = StatusPacienteViewModel(
        paciente: criarPaciente(),
        dadosRepository: dadosRepository,
        agora: () => agora,
      )..iniciar();
      final cardiopata = criar(possuiCardiopatia: true);
      await aguardar();

      expect(semCardiopatia.status, StatusSaude.estavel);
      expect(cardiopata.status, StatusSaude.atencao);
      expect(cardiopata.bpmMaximo, 90);
      semCardiopatia.dispose();
    });

    test('Deve mostrar SEM DADOS quando a última leitura passou da validade', () async {
      await salvarBatimento(72, agora.subtract(const Duration(hours: 2)));
      final vm = criar();
      await aguardar();

      // A leitura antiga continua disponivel para o card mostrar o horario.
      expect(vm.ultimoBatimento!.bpm, 72);
      expect(vm.leituraRecente, isFalse);
      expect(vm.status, StatusSaude.semDados);
    });

    test('Deve atualizar em tempo real quando o smartwatch envia uma leitura nova', () async {
      await salvarBatimento(72, agora.subtract(const Duration(minutes: 5)));
      final vm = criar();
      await aguardar();
      expect(vm.status, StatusSaude.estavel);

      var notificacoes = 0;
      vm.addListener(() => notificacoes++);
      await salvarBatimento(130, agora);
      await aguardar();

      expect(vm.ultimoBatimento!.bpm, 130);
      expect(vm.status, StatusSaude.atencao);
      expect(notificacoes, greaterThan(0));
    });

    test('Deve trazer a última atividade da rotina, de qualquer tipo', () async {
      await dadosRepository.salvarRegistro(RegistroAgua(
        id: '',
        pacienteId: 'paciente_01',
        dataHora: agora.subtract(const Duration(hours: 2)),
        quantidadeML: 250,
      ));
      final vm = criar();
      await aguardar();
      expect(vm.ultimaAtividade, isA<RegistroAgua>());

      await dadosRepository.salvarRegistro(RegistroRefeicao(
        id: '',
        pacienteId: 'paciente_01',
        dataHora: agora.subtract(const Duration(minutes: 10)),
        refeicaoId: 'almoco',
        nome: 'Almoço',
      ));
      await aguardar();

      expect(vm.ultimaAtividade, isA<RegistroRefeicao>());
    });

    test('Deve virar SEM DADOS com o passar do tempo, mesmo sem leitura nova', () async {
      await salvarBatimento(72, agora.subtract(const Duration(minutes: 59)));
      final vm = criar(intervaloRelogio: const Duration(milliseconds: 10));
      await aguardar();
      expect(vm.status, StatusSaude.estavel);

      var notificacoes = 0;
      vm.addListener(() => notificacoes++);
      agora = agora.add(const Duration(minutes: 2));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notificacoes, greaterThan(0));
      expect(vm.status, StatusSaude.semDados);
    });

    test('Deve parar de escutar o Firestore ao ser descartado', () async {
      final vm = criar();
      await aguardar();
      var notificacoes = 0;
      vm.addListener(() => notificacoes++);

      vm.dispose();
      viewModel = null;
      await salvarBatimento(72, agora);
      await aguardar();

      expect(notificacoes, 0);
    });

    group('Limites de alerta (RF 06.1)', () {
      setUp(() async {
        await fakeFirestore.collection('usuarios').doc('paciente_01').set({
          'nome': 'José Silva',
          'perfil': 'Paciente',
        });
      });

      test('Deve usar os limites do paciente no status e na zona do card', () async {
        await dadosRepository.salvarLimitesAlerta(
          'paciente_01',
          const LimitesAlerta(bpmMinimo: 50, bpmMaximo: 120),
        );
        await salvarBatimento(110, agora.subtract(const Duration(minutes: 2)));
        final vm = criar();
        await aguardar();

        expect(vm.bpmMinimo, 50);
        expect(vm.bpmMaximo, 120);
        // 110 esta fora da zona padrao (ate 100), mas dentro da do paciente.
        expect(vm.status, StatusSaude.estavel);
      });

      test('Deve mudar o status quando os limites mudam no Firestore', () async {
        await salvarBatimento(110, agora.subtract(const Duration(minutes: 2)));
        final vm = criar();
        await aguardar();
        expect(vm.status, StatusSaude.atencao);

        // Outro acompanhante (ou este, por outro celular) salva os limites.
        await dadosRepository.salvarLimitesAlerta(
          'paciente_01',
          const LimitesAlerta(bpmMinimo: 50, bpmMaximo: 120),
        );
        await aguardar();
        expect(vm.status, StatusSaude.estavel);
        expect(vm.pacienteAtual.limitesAlerta?.bpmMaximo, 120);

        await dadosRepository.salvarLimitesAlerta('paciente_01', null);
        await aguardar();
        expect(vm.status, StatusSaude.atencao);
        expect(vm.pacienteAtual.limitesAlerta, isNull);
      });

      test('Deve trocar os limites na hora quando o acompanhante acabou de salvar', () async {
        final vm = criar();
        await aguardar();
        var notificacoes = 0;
        vm.addListener(() => notificacoes++);

        vm.usarLimites(const LimitesAlerta(bpmMinimo: 45, bpmMaximo: 130));

        expect(vm.bpmMinimo, 45);
        expect(vm.bpmMaximo, 130);
        expect(notificacoes, 1);
      });
    });
  });
}
