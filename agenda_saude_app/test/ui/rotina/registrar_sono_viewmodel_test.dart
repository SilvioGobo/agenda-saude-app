import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/constants/meta_sono.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_base.dart';
import 'package:agenda_saude_app/domain/models/registro_sono.dart';
import 'package:agenda_saude_app/ui/rotina/registrar_sono_viewmodel.dart';

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

  @override
  Future<void> atualizarRegistro(String registroId, RegistroBase registro) {
    if (falhando) throw Exception('sem conexao');
    return super.atualizarRegistro(registroId, registro);
  }
}

void main() {
  group('RegistrarSonoViewModel Testes', () {
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

    RegistrarSonoViewModel criar({RegistroSono? registroAtual}) {
      return RegistrarSonoViewModel(
        paciente: paciente,
        registroAtual: registroAtual,
        dadosRepository: repositorio,
        agora: () => agora,
      );
    }

    test('Deve começar em 7 horas, sem nota escolhida e sem estar editando', () {
      final viewModel = criar();

      expect(viewModel.horas, MetaSono.horasIniciais);
      expect(viewModel.qualidade, isNull);
      expect(viewModel.editando, isFalse);
      expect(viewModel.salvando, isFalse);
    });

    test('Deve subir e descer de meia em meia hora', () {
      final viewModel = criar();

      viewModel.aumentarHoras();
      expect(viewModel.horas, 7.5);
      viewModel.diminuirHoras();
      viewModel.diminuirHoras();
      expect(viewModel.horas, 6.5);
    });

    test('Deve parar em meia hora e em 14 horas', () {
      final viewModel = criar();

      for (var i = 0; i < 30; i++) {
        viewModel.diminuirHoras();
      }
      expect(viewModel.horas, MetaSono.horasMinimas);
      expect(viewModel.podeDiminuir, isFalse);

      for (var i = 0; i < 40; i++) {
        viewModel.aumentarHoras();
      }
      expect(viewModel.horas, MetaSono.horasMaximas);
      expect(viewModel.podeAumentar, isFalse);
    });

    test('Deve deixar mexer nas horas quando não está em nenhuma ponta', () {
      final viewModel = criar();

      expect(viewModel.podeDiminuir, isTrue);
      expect(viewModel.podeAumentar, isTrue);
    });

    test('Deve usar a meta de sono do paciente', () {
      final viewModel = criar();

      expect(viewModel.metaMinHoras, 7);
      expect(viewModel.metaMaxHoras, 9);
    });

    test('Deve pedir a nota antes de salvar e não gravar nada sem ela', () async {
      final viewModel = criar();

      final salvou = await viewModel.salvar();

      expect(salvou, isFalse);
      expect(viewModel.erroQualidade, 'Escolha como foi o seu sono.');
      expect(repositorio.gravacoes, 0);
      expect((await fakeFirestore.collection('registros_diarios').get()).docs,
          isEmpty);
    });

    test('Deve limpar o aviso da nota quando ela é escolhida', () async {
      final viewModel = criar();
      await viewModel.salvar();
      expect(viewModel.erroQualidade, isNotNull);

      viewModel.escolherQualidade(4);

      expect(viewModel.erroQualidade, isNull);
      expect(viewModel.qualidade, 4);
    });

    test('Deve gravar a noite com as horas, a nota e o instante do registro', () async {
      final viewModel = criar();
      viewModel.aumentarHoras(); // 7,5 h
      viewModel.escolherQualidade(4);

      final salvou = await viewModel.salvar();

      expect(salvou, isTrue);
      expect(viewModel.salvando, isFalse);
      expect(viewModel.mensagemErro, isNull);
      final docs = (await fakeFirestore.collection('registros_diarios').get()).docs;
      final dados = docs.single.data();
      expect(dados['tipo'], 'sono');
      expect(dados['pacienteId'], 'paciente_01');
      expect(dados['horasTotais'], 7.5);
      expect(dados['qualidade'], 4);
      // Ao acordar: inicio e fim valem o instante do registro.
      expect(dados['dataHora'], isNotNull);
      expect(dados['dataFim'], isNotNull);
    });

    test('Deve abrir com o que já foi registrado e corrigir a mesma noite', () async {
      await repositorio.salvarRegistro(RegistroSono(
        id: '',
        pacienteId: paciente.id,
        dataHora: DateTime(2026, 10, 25, 6, 45),
        dataFim: DateTime(2026, 10, 25, 6, 45),
        horasTotais: 6,
        qualidade: 2,
      ));
      final existente =
          (await repositorio.streamSonoDoDia(paciente.id, agora).first).single;

      final viewModel = criar(registroAtual: existente);
      expect(viewModel.editando, isTrue);
      expect(viewModel.horas, 6);
      expect(viewModel.qualidade, 2);

      viewModel.aumentarHoras();
      viewModel.escolherQualidade(5);
      final salvou = await viewModel.salvar();

      expect(salvou, isTrue);
      final depois = await repositorio.streamSonoDoDia(paciente.id, agora).first;
      // A mesma noite, no mesmo documento, no mesmo instante de antes.
      expect(depois.single.id, existente.id);
      expect(depois.single.horasTotais, 6.5);
      expect(depois.single.qualidade, 5);
      expect(depois.single.dataHora, DateTime(2026, 10, 25, 6, 45));
      expect((await fakeFirestore.collection('registros_diarios').get()).docs,
          hasLength(1));
    });

    test('Deve ajustar ao passo de meia hora e aos limites um registro com horas fora disso', () {
      RegistroSono comHoras(double horas) => RegistroSono(
            id: 'sono1',
            pacienteId: paciente.id,
            dataHora: agora,
            dataFim: agora,
            horasTotais: horas,
            qualidade: 3,
          );

      expect(criar(registroAtual: comHoras(7.3)).horas, 7.5);
      expect(criar(registroAtual: comHoras(0)).horas, MetaSono.horasMinimas);
      expect(criar(registroAtual: comHoras(20)).horas, MetaSono.horasMaximas);
    });

    test('Deve avisar quando não conseguir gravar, e deixar tentar de novo', () async {
      repositorio.falhando = true;
      final viewModel = criar();
      viewModel.escolherQualidade(3);

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
      viewModel.escolherQualidade(4);

      final primeiro = viewModel.salvar();
      expect(viewModel.salvando, isTrue);
      final segundo = await viewModel.salvar();

      expect(segundo, isFalse);
      resposta.complete();
      await primeiro;
      expect(repositorio.gravacoes, 1);
      expect((await fakeFirestore.collection('registros_diarios').get()).docs,
          hasLength(1));
    });
  });
}
