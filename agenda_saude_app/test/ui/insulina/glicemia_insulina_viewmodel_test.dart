import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_diabete.dart';
import 'package:agenda_saude_app/ui/insulina/glicemia_insulina_viewmodel.dart';

// Falha ao apagar, para exercitar a mensagem de erro.
class _RepositorioQueFalha extends DadosMedicosRepository {
  _RepositorioQueFalha(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Future<void> removerRegistro(String registroId) =>
      Future.error(Exception('sem conexao'));
}

// Leitura do dia que sempre falha (ex.: indice composto ainda nao publicado).
class _RepositorioSemLeitura extends DadosMedicosRepository {
  _RepositorioSemLeitura(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Stream<List<RegistroDiabete>> streamDiabeteDoDia(
    String pacienteId,
    DateTime dia,
  ) =>
      Stream.error(Exception('indice faltando'));
}

void main() {
  group('GlicemiaInsulinaViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    final agora = DateTime(2026, 10, 25, 15, 0);

    Paciente criarPaciente({bool usaInsulina = false}) => Paciente(
          id: 'paciente_01',
          nome: 'José Silva',
          email: 'jose@email.com',
          perfil: 'Paciente',
          possuiDiabetes: true,
          tipoDiabetes: 'Tipo 2',
          usaInsulina: usaInsulina,
          possuiCardiopatia: false,
          codigoVinculo: 'ABC123',
        );

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
    });

    GlicemiaInsulinaViewModel criar({
      bool usaInsulina = false,
      DadosMedicosRepository? repositorio,
    }) {
      return GlicemiaInsulinaViewModel(
        paciente: criarPaciente(usaInsulina: usaInsulina),
        dadosRepository: repositorio ?? dadosRepository,
        agora: () => agora,
      );
    }

    Future<void> salvar(
      String momento,
      DateTime dataHora, {
      double? glicose,
      double? dose,
      String pacienteId = 'paciente_01',
    }) {
      return dadosRepository.salvarRegistro(RegistroDiabete(
        id: '',
        pacienteId: pacienteId,
        dataHora: dataHora,
        nivelGlicose: glicose,
        momento: momento,
        doseInsulina: dose,
        tipoInsulina: dose == null ? null : 'Rápida',
      ));
    }

    // Deixa o stream do Firestore entregar o que foi gravado.
    Future<void> aguardar() => Future<void>.delayed(Duration.zero);

    test('Deve começar carregando e mostrar as quatro medições pendentes', () async {
      final viewModel = criar();
      expect(viewModel.carregando, isTrue);

      await aguardar();

      expect(viewModel.carregando, isFalse);
      expect(viewModel.itensDoDia.length, 4);
      expect(viewModel.itensDoDia.every((item) => !item.feito), isTrue);
      expect(viewModel.medicoesFeitas, 0);
      expect(viewModel.totalMedicoes, 4);
      viewModel.dispose();
    });

    test('Deve incluir a insulina lenta no checklist de quem usa insulina', () async {
      final viewModel = criar(usaInsulina: true);
      await aguardar();

      expect(viewModel.itensDoDia.length, 5);
      expect(viewModel.itensDoDia.last.momento.nome, 'Insulina lenta (22h)');
      // A insulina lenta não conta como medição.
      expect(viewModel.totalMedicoes, 4);
      viewModel.dispose();
    });

    test('Deve marcar como feito o momento registrado hoje', () async {
      await salvar('Ao acordar', DateTime(2026, 10, 25, 7, 0), glicose: 110);
      await salvar('Antes do almoço', DateTime(2026, 10, 25, 11, 30), glicose: 150, dose: 6);
      // Registro de ontem não conta.
      await salvar('Antes do jantar', DateTime(2026, 10, 24, 18, 0), glicose: 130);

      final viewModel = criar(usaInsulina: true);
      await aguardar();

      final itens = viewModel.itensDoDia;
      expect(itens[0].feito, isTrue);
      expect(itens[0].registro!.nivelGlicose, 110);
      expect(itens[1].registro!.doseInsulina, 6);
      expect(itens[2].feito, isFalse);
      expect(viewModel.medicoesFeitas, 2);
      viewModel.dispose();
    });

    test('Deve listar as medições avulsas em ordem de horário', () async {
      await salvar('Outra medição', DateTime(2026, 10, 25, 14, 0), glicose: 90);
      await salvar('Outra medição', DateTime(2026, 10, 25, 9, 0), glicose: 200);

      final viewModel = criar();
      await aguardar();

      expect(viewModel.outrasMedicoes.map((r) => r.nivelGlicose), [200, 90]);
      expect(viewModel.medicoesFeitas, 0);
      viewModel.dispose();
    });

    test('Deve avisar hipoglicemia só quando a medição mais recente estiver baixa', () async {
      await salvar('Ao acordar', DateTime(2026, 10, 25, 7, 0), glicose: 65);
      final viewModel = criar(usaInsulina: true);
      await aguardar();

      expect(viewModel.hipoglicemiaNaUltimaMedicao, isTrue);
      expect(viewModel.ultimaGlicemia!.nivelGlicose, 65);

      // Insulina lenta (sem glicemia) não muda a última medição.
      await salvar('Insulina lenta (22h)', DateTime(2026, 10, 25, 8, 0), dose: 12);
      await aguardar();
      expect(viewModel.hipoglicemiaNaUltimaMedicao, isTrue);

      await salvar('Outra medição', DateTime(2026, 10, 25, 7, 20), glicose: 95);
      await aguardar();
      expect(viewModel.hipoglicemiaNaUltimaMedicao, isFalse);
      viewModel.dispose();
    });

    test('Deve apagar um registro e voltar o momento para pendente', () async {
      await salvar('Ao acordar', DateTime(2026, 10, 25, 7, 0), glicose: 110);
      final viewModel = criar();
      await aguardar();

      final apagou =
          await viewModel.apagarRegistro(viewModel.itensDoDia.first.registro!);
      await aguardar();

      expect(apagou, isTrue);
      expect(viewModel.itensDoDia.first.feito, isFalse);
      expect(
        (await fakeFirestore.collection('registros_diarios').get()).docs,
        isEmpty,
      );
      viewModel.dispose();
    });

    test('Deve mostrar mensagem de erro se não conseguir apagar', () async {
      await salvar('Ao acordar', DateTime(2026, 10, 25, 7, 0), glicose: 110);
      final viewModel = criar(repositorio: _RepositorioQueFalha(fakeFirestore));
      await aguardar();

      final apagou =
          await viewModel.apagarRegistro(viewModel.itensDoDia.first.registro!);

      expect(apagou, isFalse);
      expect(viewModel.mensagemErro, contains('Não foi possível apagar'));
      viewModel.dispose();
    });

    test('Deve sinalizar erro de leitura quando o stream falha', () async {
      final viewModel =
          criar(repositorio: _RepositorioSemLeitura(fakeFirestore));
      await aguardar();

      expect(viewModel.carregando, isFalse);
      expect(viewModel.erroDeLeitura, isTrue);
      viewModel.dispose();
    });
  });
}
