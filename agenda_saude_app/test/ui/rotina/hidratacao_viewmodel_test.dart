import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/constants/meta_hidratacao.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/metas/metas_personalizadas.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_agua.dart';
import 'package:agenda_saude_app/domain/models/registro_base.dart';
import 'package:agenda_saude_app/ui/rotina/hidratacao_viewmodel.dart';

// Falha ao gravar ou apagar enquanto `falhando` for verdadeiro, para exercitar
// a mensagem de erro.
class _RepositorioQueFalha extends DadosMedicosRepository {
  bool falhando = true;

  _RepositorioQueFalha(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Future<void> salvarRegistro(RegistroBase registro) {
    if (falhando) throw Exception('sem conexao');
    return super.salvarRegistro(registro);
  }

  @override
  Future<void> removerRegistro(String registroId) {
    if (falhando) throw Exception('sem conexao');
    return super.removerRegistro(registroId);
  }
}

// Leitura do dia que sempre falha (ex.: indice composto ainda nao publicado).
class _RepositorioSemLeitura extends DadosMedicosRepository {
  _RepositorioSemLeitura(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Stream<List<RegistroAgua>> streamAguaDoDia(String pacienteId, DateTime dia) =>
      Stream.error(Exception('indice faltando'));
}


// Metas completas; so a agua muda de um teste para outro.
MetasPersonalizadas metasComAgua(int hidratacaoMl) {
  return MetasPersonalizadas(
    imc: 24.7,
    classificacaoImc: ClassificacaoImc.adequado,
    hidratacaoMl: hidratacaoMl,
    sonoMinHoras: 7,
    sonoMaxHoras: 9,
    passos: 8000,
    exercicioMinutosSemana: 150,
    calorias: 1800,
    carboidratosG: 225,
    proteinasG: 90,
    gordurasG: 60,
    fibrasG: 25,
    gorduraSaturadaMaxG: 20,
    acucarLivreMaxG: 45,
    sodioMaxMg: 2000,
  );
}

void main() {
  group('HidratacaoViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    late Paciente paciente;
    late DateTime agora;

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
      agora = DateTime(2026, 10, 25, 15, 0);
    });

    HidratacaoViewModel criar({DadosMedicosRepository? repositorio}) {
      return HidratacaoViewModel(
        paciente: paciente,
        dadosRepository: repositorio ?? dadosRepository,
        agora: () => agora,
      );
    }

    // Deixa o stream do Firestore entregar o que foi gravado.
    Future<void> aguardar() => Future<void>.delayed(Duration.zero);

    test('Deve começar carregando e zerado, e liberar a tela com o primeiro resultado', () async {
      final viewModel = criar();

      expect(viewModel.carregando, isTrue);

      await aguardar();

      expect(viewModel.carregando, isFalse);
      expect(viewModel.totalMl, 0);
      expect(viewModel.copos, 0);
      expect(viewModel.progresso, 0);
      expect(viewModel.metaAtingida, isFalse);
      expect(viewModel.podeRemover, isFalse);
      viewModel.dispose();
    });

    test('Deve gravar um copo de 250 ml ao adicionar e refletir no total', () async {
      final viewModel = criar();
      await aguardar();

      await viewModel.adicionarCopo();
      await aguardar();

      expect(viewModel.copos, 1);
      expect(viewModel.totalMl, MetaHidratacao.mlPorCopo);
      expect(viewModel.progresso, closeTo(1 / MetaHidratacao.copos, 0.0001));
      expect(viewModel.podeRemover, isTrue);

      final salvo = await fakeFirestore.collection('registros_diarios').get();
      expect(salvo.docs.single.data()['tipo'], 'agua');
      expect(salvo.docs.single.data()['pacienteId'], 'paciente_01');
      expect(salvo.docs.single.data()['quantidadeML'], 250);
      viewModel.dispose();
    });

    test('Deve remover só o copo mais recente ao tirar um copo', () async {
      final viewModel = criar();
      await aguardar();
      await dadosRepository.salvarRegistro(RegistroAgua(
        id: '',
        pacienteId: paciente.id,
        dataHora: DateTime(2026, 10, 25, 8, 0),
        quantidadeML: 100,
      ));
      await dadosRepository.salvarRegistro(RegistroAgua(
        id: '',
        pacienteId: paciente.id,
        dataHora: DateTime(2026, 10, 25, 12, 0),
        quantidadeML: 250,
      ));
      await aguardar();
      expect(viewModel.totalMl, 350);

      await viewModel.removerCopo();
      await aguardar();

      expect(viewModel.totalMl, 100);
      viewModel.dispose();
    });

    test('Não deve fazer nada ao tirar um copo sem nenhum registro no dia', () async {
      final viewModel = criar();
      await aguardar();

      await viewModel.removerCopo();
      await aguardar();

      expect(viewModel.totalMl, 0);
      expect(viewModel.mensagemErro, isNull);
      viewModel.dispose();
    });

    test('Deve contar só a água do dia de hoje do próprio paciente', () async {
      await dadosRepository.salvarRegistro(RegistroAgua(
        id: '',
        pacienteId: paciente.id,
        dataHora: DateTime(2026, 10, 24, 22, 0),
        quantidadeML: 250,
      ));
      await dadosRepository.salvarRegistro(RegistroAgua(
        id: '',
        pacienteId: 'outro_paciente',
        dataHora: DateTime(2026, 10, 25, 9, 0),
        quantidadeML: 250,
      ));

      final viewModel = criar();
      await aguardar();

      expect(viewModel.totalMl, 0);
      viewModel.dispose();
    });

    test('Deve atingir a meta com 8 copos e travar a barra em 100% ao passar dela', () async {
      final viewModel = criar();
      await aguardar();

      for (var i = 0; i < MetaHidratacao.copos; i++) {
        await viewModel.adicionarCopo();
      }
      await aguardar();

      expect(viewModel.copos, MetaHidratacao.copos);
      expect(viewModel.metaAtingida, isTrue);
      expect(viewModel.progresso, 1);

      await viewModel.adicionarCopo();
      await aguardar();

      expect(viewModel.copos, MetaHidratacao.copos + 1);
      expect(viewModel.progresso, 1);
      viewModel.dispose();
    });

    test('Deve avisar quando não conseguir gravar o copo, e limpar o aviso na tentativa seguinte', () async {
      final repositorio = _RepositorioQueFalha(fakeFirestore);
      final viewModel = criar(repositorio: repositorio);
      await aguardar();

      await viewModel.adicionarCopo();

      expect(viewModel.mensagemErro, isNotNull);
      expect(viewModel.totalMl, 0);

      repositorio.falhando = false;
      await viewModel.adicionarCopo();
      await aguardar();

      expect(viewModel.mensagemErro, isNull);
      expect(viewModel.totalMl, MetaHidratacao.mlPorCopo);
      viewModel.dispose();
    });

    test('Deve avisar quando não conseguir tirar o copo', () async {
      await dadosRepository.salvarRegistro(RegistroAgua(
        id: '',
        pacienteId: paciente.id,
        dataHora: DateTime(2026, 10, 25, 9, 0),
        quantidadeML: 250,
      ));
      final viewModel = criar(repositorio: _RepositorioQueFalha(fakeFirestore));
      await aguardar();
      expect(viewModel.podeRemover, isTrue);

      await viewModel.removerCopo();

      expect(viewModel.mensagemErro, isNotNull);
      expect(viewModel.totalMl, 250);
      viewModel.dispose();
    });

    test('Deve marcar erro de leitura quando o Firestore falha ao carregar o dia', () async {
      final viewModel = criar(repositorio: _RepositorioSemLeitura(fakeFirestore));
      await aguardar();

      expect(viewModel.carregando, isFalse);
      expect(viewModel.erroDeLeitura, isTrue);
      viewModel.dispose();
    });

    test('Deve zerar o total quando o dia vira, sem reabrir a tela', () async {
      await dadosRepository.salvarRegistro(RegistroAgua(
        id: '',
        pacienteId: paciente.id,
        dataHora: DateTime(2026, 10, 25, 9, 0),
        quantidadeML: 250,
      ));
      // Faltam 300 ms para a meia-noite; o relogio do teste ja passa dela
      // quando o timer da virada dispara.
      agora = DateTime(2026, 10, 25, 23, 59, 59, 700);
      final viewModel = criar();
      await aguardar();
      expect(viewModel.totalMl, 250);

      agora = DateTime(2026, 10, 26, 0, 0, 0, 100);
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(viewModel.totalMl, 0);
      expect(viewModel.carregando, isFalse);
      viewModel.dispose();
    });

    test('Deve usar a meta de água calculada para o paciente', () async {
      final viewModel = HidratacaoViewModel(
        paciente: paciente.copyWith(metas: metasComAgua(1500)),
        dadosRepository: dadosRepository,
        agora: () => agora,
      );
      await aguardar();

      expect(viewModel.metaMl, 1500);
      expect(viewModel.metaCopos, 6);
      expect(viewModel.metaAtingida, isFalse);

      for (var i = 0; i < 3; i++) {
        await viewModel.adicionarCopo();
      }
      await aguardar();

      expect(viewModel.progresso, closeTo(0.5, 0.0001));
      expect(viewModel.metaAtingida, isFalse);

      for (var i = 0; i < 3; i++) {
        await viewModel.adicionarCopo();
      }
      await aguardar();

      expect(viewModel.copos, 6);
      expect(viewModel.metaAtingida, isTrue);
      viewModel.dispose();
    });

    test('Deve usar a meta padrão quando o paciente não tem metas', () async {
      final viewModel = criar();
      await aguardar();

      expect(viewModel.metaMl, MetaHidratacao.mlDiaria);
      expect(viewModel.metaCopos, MetaHidratacao.copos);
      viewModel.dispose();
    });
  });
}
