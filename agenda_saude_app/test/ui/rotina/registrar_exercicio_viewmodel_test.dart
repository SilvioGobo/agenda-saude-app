import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/constants/meta_exercicio.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_base.dart';
import 'package:agenda_saude_app/ui/rotina/registrar_exercicio_viewmodel.dart';

// Falha ao gravar enquanto `falhando` for verdadeiro; e, se `espera` existir,
// so grava depois dela (para testar o toque duplo em "Salvar").
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
}

void main() {
  group('RegistrarExercicioViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late _RepositorioDeTeste repositorio;
    late Paciente paciente;
    final agora = DateTime(2026, 10, 25, 7, 30);

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repositorio = _RepositorioDeTeste(fakeFirestore);
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

    RegistrarExercicioViewModel criar() {
      return RegistrarExercicioViewModel(
        paciente: paciente,
        dadosRepository: repositorio,
        agora: () => agora,
      );
    }

    Future<List<Map<String, dynamic>>> gravados() async {
      final snapshot = await fakeFirestore.collection('registros_diarios').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    }

    test('Deve começar em 30 minutos, sem exercício nem intensidade escolhidos', () {
      final viewModel = criar();

      expect(viewModel.minutos, MetaExercicio.minutosIniciais);
      expect(viewModel.tipo, isNull);
      expect(viewModel.intensidade, isNull);
      expect(viewModel.salvando, isFalse);
    });

    test('Deve subir e descer de 5 em 5 minutos', () {
      final viewModel = criar();

      viewModel.aumentarMinutos();
      expect(viewModel.minutos, 35);
      viewModel.diminuirMinutos();
      viewModel.diminuirMinutos();
      expect(viewModel.minutos, 25);
    });

    test('Deve parar em 5 minutos e em 4 horas', () {
      final viewModel = criar();

      for (var i = 0; i < 20; i++) {
        viewModel.diminuirMinutos();
      }
      expect(viewModel.minutos, MetaExercicio.minutosMinimos);
      expect(viewModel.podeDiminuir, isFalse);

      for (var i = 0; i < 60; i++) {
        viewModel.aumentarMinutos();
      }
      expect(viewModel.minutos, MetaExercicio.minutosMaximos);
      expect(viewModel.podeAumentar, isFalse);
    });

    test('Deve deixar mexer nos minutos quando não está em nenhuma ponta', () {
      final viewModel = criar();

      expect(viewModel.podeDiminuir, isTrue);
      expect(viewModel.podeAumentar, isTrue);
    });

    test('Deve pedir o exercício e a intensidade, e não gravar nada sem eles', () async {
      final viewModel = criar();

      final salvou = await viewModel.salvar();

      expect(salvou, isFalse);
      expect(viewModel.erroTipo, 'Escolha qual exercício você fez.');
      expect(viewModel.erroIntensidade, 'Escolha como foi a intensidade.');
      expect(repositorio.gravacoes, 0);
      expect(await gravados(), isEmpty);
    });

    test('Deve limpar cada aviso quando a escolha é feita', () async {
      final viewModel = criar();
      await viewModel.salvar();

      viewModel.escolherTipo('Caminhada');
      expect(viewModel.erroTipo, isNull);
      expect(viewModel.erroIntensidade, isNotNull);

      viewModel.escolherIntensidade('Leve');
      expect(viewModel.erroIntensidade, isNull);
    });

    test('Deve gravar o exercício com o tipo, a duração, a intensidade e o instante', () async {
      final viewModel = criar();
      viewModel.escolherTipo('Hidroginástica');
      viewModel.aumentarMinutos(); // 35
      viewModel.aumentarMinutos(); // 40
      viewModel.escolherIntensidade('Moderada');

      final salvou = await viewModel.salvar();

      expect(salvou, isTrue);
      expect(viewModel.salvando, isFalse);
      expect(viewModel.mensagemErro, isNull);
      final dados = (await gravados()).single;
      expect(dados['tipo'], 'exercicio');
      expect(dados['pacienteId'], 'paciente_01');
      expect(dados['tipoExercicio'], 'Hidroginástica');
      expect(dados['duracaoMinutos'], 40);
      expect(dados['intensidade'], 'Moderada');
      expect(dados['dataHora'], isNotNull);
    });

    test('Deve criar um registro novo a cada vez: dá para se exercitar mais de uma vez no dia', () async {
      final primeiro = criar();
      primeiro.escolherTipo('Caminhada');
      primeiro.escolherIntensidade('Leve');
      await primeiro.salvar();

      final segundo = criar();
      segundo.escolherTipo('Alongamento');
      segundo.escolherIntensidade('Leve');
      await segundo.salvar();

      expect(await gravados(), hasLength(2));
    });

    test('Deve avisar quando não conseguir gravar, e deixar tentar de novo', () async {
      repositorio.falhando = true;
      final viewModel = criar();
      viewModel.escolherTipo('Caminhada');
      viewModel.escolherIntensidade('Leve');

      final salvou = await viewModel.salvar();

      expect(salvou, isFalse);
      expect(viewModel.mensagemErro, 'Não foi possível salvar. Tente de novo.');
      expect(viewModel.salvando, isFalse);

      repositorio.falhando = false;
      final denovo = await viewModel.salvar();

      expect(denovo, isTrue);
      expect(viewModel.mensagemErro, isNull);
    });

    test('Deve ignorar um segundo toque em "Salvar" enquanto grava', () async {
      final resposta = Completer<void>();
      repositorio.espera = resposta.future;
      final viewModel = criar();
      viewModel.escolherTipo('Caminhada');
      viewModel.escolherIntensidade('Leve');

      final primeiro = viewModel.salvar();
      expect(viewModel.salvando, isTrue);
      final segundo = await viewModel.salvar();

      expect(segundo, isFalse);
      resposta.complete();
      await primeiro;
      expect(repositorio.gravacoes, 1);
      expect(await gravados(), hasLength(1));
    });
  });
}
