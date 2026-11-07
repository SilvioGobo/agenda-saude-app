import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/domain/medicacao/dose_planejada.dart';
import 'package:agenda_saude_app/domain/models/medicamento.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_base.dart';
import 'package:agenda_saude_app/domain/models/registro_medicacao.dart';
import 'package:agenda_saude_app/ui/rotina/medicacao_viewmodel.dart';

// Falha ao gravar ou apagar enquanto `falhando` for verdadeiro; e, se `espera`
// existir, so grava depois dela (para testar o toque duplo).
class _RepositorioDeTeste extends DadosMedicosRepository {
  bool falhando = false;
  Future<void>? espera;
  int gravacoes = 0;

  _RepositorioDeTeste(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Future<void> salvarRegistro(RegistroBase registro) async {
    gravacoes++;
    await espera;
    if (falhando) throw Exception('sem conexao');
    return super.salvarRegistro(registro);
  }

  @override
  Future<void> removerRegistro(String registroId) {
    if (falhando) throw Exception('sem conexao');
    return super.removerRegistro(registroId);
  }
}

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

// Nao consegue gravar a lista de remedios.
class _PacienteRepositoryQueFalha extends PacienteRepository {
  _PacienteRepositoryQueFalha(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Future<void> salvarMedicamentos(
    String pacienteId,
    List<Medicamento> medicamentos,
  ) =>
      throw Exception('sem conexao');
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
  horarios: ['12:00', '20:00'],
);

void main() {
  group('MedicacaoViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late _RepositorioDeTeste dadosRepository;
    late Paciente paciente;
    late DateTime agora;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = _RepositorioDeTeste(fakeFirestore);
      paciente = Paciente(
        id: 'paciente_01',
        nome: 'José Silva',
        email: 'jose@email.com',
        perfil: 'Paciente',
        possuiDiabetes: false,
        possuiCardiopatia: false,
        codigoVinculo: 'ABC123',
        medicamentos: const [_losartana, _metformina],
      );
      agora = DateTime(2026, 10, 25, 9, 30);
    });

    MedicacaoViewModel criar({
      DadosMedicosRepository? repositorio,
      PacienteRepository? pacienteRepository,
      void Function(Paciente)? aoAtualizar,
      Paciente? pacienteDaTela,
    }) {
      return MedicacaoViewModel(
        paciente: pacienteDaTela ?? paciente,
        dadosRepository: repositorio ?? dadosRepository,
        pacienteRepository:
            pacienteRepository ?? PacienteRepository(firestore: fakeFirestore),
        aoAtualizarPaciente: aoAtualizar,
        agora: () => agora,
      );
    }

    // Deixa o stream do Firestore entregar o que foi gravado.
    Future<void> aguardar() => Future<void>.delayed(Duration.zero);

    DosePlanejada dose(MedicacaoViewModel viewModel, String nome, String horario) =>
        viewModel.doses.firstWhere((d) => d.nome == nome && d.horario == horario);

    Future<List<Map<String, dynamic>>> gravados() async {
      final snapshot = await fakeFirestore.collection('registros_diarios').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    }

    test('Deve começar carregando e com todas as doses por tomar', () async {
      final viewModel = criar();

      expect(viewModel.carregando, isTrue);

      await aguardar();

      expect(viewModel.carregando, isFalse);
      expect(viewModel.total, 3);
      expect(viewModel.tomadas, 0);
      expect(viewModel.todasTomadas, isFalse);
      expect(viewModel.progresso, 0);
      viewModel.dispose();
    });

    test('Deve listar uma dose por remédio e horário, em ordem de horário', () async {
      final viewModel = criar();
      await aguardar();

      expect(
        viewModel.doses.map((d) => '${d.nome} ${d.horario}'),
        ['Losartana 08:00', 'Metformina 12:00', 'Metformina 20:00'],
      );
      viewModel.dispose();
    });

    test('Deve marcar uma dose como tomada e gravar o registro dela', () async {
      final viewModel = criar();
      await aguardar();

      await viewModel.alternar(dose(viewModel, 'Losartana', '08:00'));
      await aguardar();

      expect(viewModel.estaTomada(dose(viewModel, 'Losartana', '08:00')), isTrue);
      expect(viewModel.estaTomada(dose(viewModel, 'Metformina', '12:00')), isFalse);
      expect(viewModel.tomadas, 1);
      expect(viewModel.progresso, closeTo(1 / 3, 0.0001));
      final dados = (await gravados()).single;
      expect(dados['tipo'], 'medicacao');
      expect(dados['pacienteId'], 'paciente_01');
      expect(dados['medicamentoId'], 'm1');
      expect(dados['horario'], '08:00');
      expect(dados['nome'], 'Losartana');
      expect(dados['dose'], '50 mg');
      viewModel.dispose();
    });

    test('Deve desmarcar a dose quando ela já estava tomada', () async {
      final viewModel = criar();
      await aguardar();
      final losartana = dose(viewModel, 'Losartana', '08:00');

      await viewModel.alternar(losartana);
      await aguardar();
      await viewModel.alternar(losartana);
      await aguardar();

      expect(viewModel.estaTomada(losartana), isFalse);
      expect(viewModel.tomadas, 0);
      expect(await gravados(), isEmpty);
      viewModel.dispose();
    });

    test('Deve tratar o mesmo remédio em dois horários como duas doses', () async {
      final viewModel = criar();
      await aguardar();

      await viewModel.alternar(dose(viewModel, 'Metformina', '12:00'));
      await aguardar();

      expect(viewModel.estaTomada(dose(viewModel, 'Metformina', '12:00')), isTrue);
      expect(viewModel.estaTomada(dose(viewModel, 'Metformina', '20:00')), isFalse);
      viewModel.dispose();
    });

    test('Deve concluir quando todas as doses do dia foram tomadas', () async {
      final viewModel = criar();
      await aguardar();

      for (final d in viewModel.doses) {
        await viewModel.alternar(d);
      }
      await aguardar();

      expect(viewModel.tomadas, 3);
      expect(viewModel.todasTomadas, isTrue);
      expect(viewModel.progresso, 1);
      viewModel.dispose();
    });

    test('Deve contar só as doses de hoje do próprio paciente', () async {
      await dadosRepository.salvarRegistro(RegistroMedicacao(
        id: '',
        pacienteId: 'paciente_01',
        dataHora: DateTime(2026, 10, 24, 8, 5),
        medicamentoId: 'm1',
        horario: '08:00',
        nome: 'Losartana',
      ));
      await dadosRepository.salvarRegistro(RegistroMedicacao(
        id: '',
        pacienteId: 'outro_paciente',
        dataHora: DateTime(2026, 10, 25, 8, 5),
        medicamentoId: 'm1',
        horario: '08:00',
        nome: 'Losartana',
      ));

      final viewModel = criar();
      await aguardar();

      expect(viewModel.tomadas, 0);
      viewModel.dispose();
    });

    test('Deve valer a primeira marcação quando a dose foi marcada duas vezes', () async {
      for (final hora in [10, 8]) {
        await dadosRepository.salvarRegistro(RegistroMedicacao(
          id: '',
          pacienteId: 'paciente_01',
          dataHora: DateTime(2026, 10, 25, hora, 5),
          medicamentoId: 'm1',
          horario: '08:00',
          nome: 'Losartana',
        ));
      }

      final viewModel = criar();
      await aguardar();

      final registro = viewModel.registroDa(dose(viewModel, 'Losartana', '08:00'))!;
      expect(registro.dataHora, DateTime(2026, 10, 25, 8, 5));
      expect(viewModel.tomadas, 1);

      // Desmarcar apaga as duas marcacoes.
      await viewModel.alternar(dose(viewModel, 'Losartana', '08:00'));
      await aguardar();
      expect(viewModel.tomadas, 0);
      viewModel.dispose();
    });

    test('Não deve marcar duas vezes quando a dose é tocada de novo antes de gravar', () async {
      final viewModel = criar();
      await aguardar();
      final resposta = Completer<void>();
      dadosRepository.espera = resposta.future;
      final losartana = dose(viewModel, 'Losartana', '08:00');

      final primeiro = viewModel.alternar(losartana);
      final segundo = viewModel.alternar(losartana);
      resposta.complete();
      await Future.wait([primeiro, segundo]);
      await aguardar();

      expect(dadosRepository.gravacoes, 1);
      expect(await gravados(), hasLength(1));
      viewModel.dispose();
    });

    test('Deve avisar quando não conseguir gravar a dose, e limpar o aviso na tentativa seguinte', () async {
      final viewModel = criar();
      await aguardar();
      dadosRepository.falhando = true;
      final losartana = dose(viewModel, 'Losartana', '08:00');

      await viewModel.alternar(losartana);

      expect(viewModel.mensagemErro, 'Não foi possível salvar. Tente de novo.');
      expect(viewModel.estaTomada(losartana), isFalse);

      dadosRepository.falhando = false;
      await viewModel.alternar(losartana);
      await aguardar();

      expect(viewModel.mensagemErro, isNull);
      expect(viewModel.estaTomada(losartana), isTrue);
      viewModel.dispose();
    });

    test('Deve avisar quando não conseguir desmarcar, e manter a dose tomada', () async {
      final viewModel = criar();
      await aguardar();
      final losartana = dose(viewModel, 'Losartana', '08:00');
      await viewModel.alternar(losartana);
      await aguardar();
      dadosRepository.falhando = true;

      await viewModel.alternar(losartana);

      expect(viewModel.mensagemErro, isNotNull);
      expect(viewModel.estaTomada(losartana), isTrue);
      viewModel.dispose();
    });

    test('Deve gravar a lista de remédios, mostrá-la e avisar o painel', () async {
      await PacienteRepository(firestore: fakeFirestore).salvarPaciente(paciente);
      Paciente? atualizado;
      final viewModel = criar(aoAtualizar: (novo) => atualizado = novo);
      await aguardar();

      final salvou = await viewModel.salvarMedicamentos(const [_losartana]);

      expect(salvou, isTrue);
      expect(viewModel.total, 1);
      expect(viewModel.doses.single.nome, 'Losartana');
      expect(atualizado!.medicamentos.map((m) => m.id), ['m1']);
      final gravado = await PacienteRepository(firestore: fakeFirestore)
          .getPaciente('paciente_01');
      expect(gravado!.medicamentos.map((m) => m.id), ['m1']);
      viewModel.dispose();
    });

    test('Deve manter a lista antiga quando não consegue gravar a nova', () async {
      Paciente? atualizado;
      final viewModel = criar(
        pacienteRepository: _PacienteRepositoryQueFalha(fakeFirestore),
        aoAtualizar: (novo) => atualizado = novo,
      );
      await aguardar();

      final salvou = await viewModel.salvarMedicamentos(const []);

      expect(salvou, isFalse);
      expect(viewModel.total, 3);
      expect(atualizado, isNull);
      viewModel.dispose();
    });

    test('Deve marcar erro de leitura quando o Firestore falha ao carregar o dia', () async {
      final viewModel = criar(repositorio: _RepositorioSemLeitura(fakeFirestore));
      await aguardar();

      expect(viewModel.carregando, isFalse);
      expect(viewModel.erroDeLeitura, isTrue);
      viewModel.dispose();
    });

    test('Deve zerar as marcações quando o dia vira, sem reabrir a tela', () async {
      await dadosRepository.salvarRegistro(RegistroMedicacao(
        id: '',
        pacienteId: 'paciente_01',
        dataHora: DateTime(2026, 10, 25, 8, 5),
        medicamentoId: 'm1',
        horario: '08:00',
        nome: 'Losartana',
      ));
      // Faltam 300 ms para a meia-noite; o relogio do teste ja passa dela
      // quando o timer da virada dispara.
      agora = DateTime(2026, 10, 25, 23, 59, 59, 700);
      final viewModel = criar();
      await aguardar();
      expect(viewModel.tomadas, 1);

      agora = DateTime(2026, 10, 26, 0, 0, 0, 100);
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(viewModel.tomadas, 0);
      expect(viewModel.carregando, isFalse);
      viewModel.dispose();
    });

    test('Sem remédios cadastrados, não há doses nem dia concluído', () async {
      final viewModel =
          criar(pacienteDaTela: paciente.copyWith(medicamentos: const []));
      await aguardar();

      expect(viewModel.doses, isEmpty);
      expect(viewModel.total, 0);
      expect(viewModel.todasTomadas, isFalse);
      expect(viewModel.progresso, 0);
      viewModel.dispose();
    });
  });
}
