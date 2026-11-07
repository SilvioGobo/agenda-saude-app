import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/metas/metas_personalizadas.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_exercicio.dart';
import 'package:agenda_saude_app/ui/rotina/exercicio_viewmodel.dart';

// Leitura da semana que sempre falha (ex.: indice composto nao publicado).
class _RepositorioSemLeitura extends DadosMedicosRepository {
  _RepositorioSemLeitura(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Stream<List<RegistroExercicio>> streamExerciciosDaSemana(
    String pacienteId,
    DateTime dia,
  ) =>
      Stream.error(Exception('indice faltando'));
}

// Nao consegue apagar (ex.: sem internet).
class _RepositorioQueNaoApaga extends DadosMedicosRepository {
  _RepositorioQueNaoApaga(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Future<void> removerRegistro(String registroId) =>
      throw Exception('sem conexao');
}

MetasPersonalizadas _metasComExercicio(int minutos) => MetasPersonalizadas(
      imc: 24.7,
      classificacaoImc: ClassificacaoImc.adequado,
      hidratacaoMl: 2000,
      sonoMinHoras: 7,
      sonoMaxHoras: 9,
      passos: 6000,
      exercicioMinutosSemana: minutos,
      calorias: 1800,
      carboidratosG: 225,
      proteinasG: 90,
      gordurasG: 60,
      fibrasG: 25,
      gorduraSaturadaMaxG: 14,
      acucarLivreMaxG: 45,
      sodioMaxMg: 2000,
    );

void main() {
  group('ExercicioViewModel Testes', () {
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
      // Quarta-feira, 28/10/2026: a semana vai de domingo 25/10 a sabado 31/10.
      agora = DateTime(2026, 10, 28, 15, 0);
    });

    ExercicioViewModel criar({
      DadosMedicosRepository? repositorio,
      Paciente? pacienteDaTela,
    }) {
      return ExercicioViewModel(
        paciente: pacienteDaTela ?? paciente,
        dadosRepository: repositorio ?? dadosRepository,
        agora: () => agora,
      );
    }

    // Deixa o stream do Firestore entregar o que foi gravado.
    Future<void> aguardar() => Future<void>.delayed(Duration.zero);

    Future<void> registrar(
      DateTime quando,
      int minutos, {
      String pacienteId = 'paciente_01',
      String tipo = 'Caminhada',
    }) {
      return dadosRepository.salvarRegistro(RegistroExercicio(
        id: '',
        pacienteId: pacienteId,
        dataHora: quando,
        tipoExercicio: tipo,
        duracaoMinutos: minutos,
        intensidade: 'Moderada',
      ));
    }

    test('Deve começar carregando e zerado, e liberar a tela com o primeiro resultado', () async {
      final viewModel = criar();

      expect(viewModel.carregando, isTrue);

      await aguardar();

      expect(viewModel.carregando, isFalse);
      expect(viewModel.fezExercicioHoje, isFalse);
      expect(viewModel.registrosDeHoje, isEmpty);
      expect(viewModel.minutosHoje, 0);
      expect(viewModel.minutosNaSemana, 0);
      expect(viewModel.progressoDaSemana, 0);
      expect(viewModel.metaAtingida, isFalse);
      viewModel.dispose();
    });

    test('Deve separar os exercícios de hoje dos do resto da semana', () async {
      await registrar(DateTime(2026, 10, 28, 7, 0), 30); // hoje
      await registrar(DateTime(2026, 10, 28, 12, 0), 20); // hoje
      await registrar(DateTime(2026, 10, 26, 8, 0), 40); // segunda
      await registrar(DateTime(2026, 10, 25, 9, 0), 15); // domingo

      final viewModel = criar();
      await aguardar();

      expect(viewModel.fezExercicioHoje, isTrue);
      expect(viewModel.registrosDeHoje.map((r) => r.duracaoMinutos), [20, 30]);
      expect(viewModel.minutosHoje, 50);
      expect(viewModel.minutosNaSemana, 105);
      viewModel.dispose();
    });

    test('Deve ignorar exercícios de outras semanas e de outros pacientes', () async {
      await registrar(DateTime(2026, 10, 24, 23, 0), 60); // sabado passado
      await registrar(DateTime(2026, 11, 1, 8, 0), 60); // domingo seguinte
      await registrar(DateTime(2026, 10, 28, 8, 0), 60, pacienteId: 'outro');

      final viewModel = criar();
      await aguardar();

      expect(viewModel.minutosNaSemana, 0);
      expect(viewModel.minutosHoje, 0);
      viewModel.dispose();
    });

    test('Deve atingir a meta de 150 minutos da semana e travar a barra em 100%', () async {
      final viewModel = criar();
      await aguardar();
      expect(viewModel.metaSemanalMinutos, 150);

      await registrar(DateTime(2026, 10, 26, 8, 0), 140);
      await aguardar();
      expect(viewModel.metaAtingida, isFalse);
      expect(viewModel.minutosQueFaltam, 10);
      expect(viewModel.progressoDaSemana, closeTo(140 / 150, 0.0001));

      await registrar(DateTime(2026, 10, 27, 8, 0), 10);
      await aguardar();
      expect(viewModel.metaAtingida, isTrue);
      expect(viewModel.minutosQueFaltam, 0);
      expect(viewModel.progressoDaSemana, 1);

      await registrar(DateTime(2026, 10, 28, 8, 0), 60);
      await aguardar();
      expect(viewModel.minutosNaSemana, 210);
      expect(viewModel.progressoDaSemana, 1);
      expect(viewModel.minutosQueFaltam, 0);
      viewModel.dispose();
    });

    test('Deve usar a meta de exercício calculada para o paciente', () async {
      final viewModel =
          criar(pacienteDaTela: paciente.copyWith(metas: _metasComExercicio(90)));
      await registrar(DateTime(2026, 10, 28, 8, 0), 45);
      await aguardar();

      expect(viewModel.metaSemanalMinutos, 90);
      expect(viewModel.progressoDaSemana, closeTo(0.5, 0.0001));
      viewModel.dispose();
    });

    test('Deve atualizar quando um exercício é registrado, sem reabrir a tela', () async {
      final viewModel = criar();
      await aguardar();

      await registrar(DateTime(2026, 10, 28, 9, 0), 25);
      await aguardar();

      expect(viewModel.minutosHoje, 25);
      viewModel.dispose();
    });

    test('Deve apagar um exercício registrado por engano', () async {
      await registrar(DateTime(2026, 10, 28, 7, 0), 30);
      await registrar(DateTime(2026, 10, 28, 9, 0), 45);
      final viewModel = criar();
      await aguardar();

      final apagou = await viewModel.apagar(viewModel.registrosDeHoje.first);
      await aguardar();

      expect(apagou, isTrue);
      expect(viewModel.mensagemErro, isNull);
      expect(viewModel.registrosDeHoje.map((r) => r.duracaoMinutos), [30]);
      expect(viewModel.minutosNaSemana, 30);
      viewModel.dispose();
    });

    test('Deve avisar quando não conseguir apagar, e manter o exercício', () async {
      await registrar(DateTime(2026, 10, 28, 7, 0), 30);
      final viewModel = criar(repositorio: _RepositorioQueNaoApaga(fakeFirestore));
      await aguardar();

      final apagou = await viewModel.apagar(viewModel.registrosDeHoje.single);

      expect(apagou, isFalse);
      expect(viewModel.mensagemErro, 'Não foi possível apagar. Tente de novo.');
      expect(viewModel.minutosHoje, 30);
      viewModel.dispose();
    });

    test('Deve entregar o formulário já ligado ao mesmo Firestore', () async {
      final viewModel = criar();
      await aguardar();

      final formulario = viewModel.novoRegistro();
      formulario.escolherTipo('Dança');
      formulario.aumentarMinutos(); // 35
      formulario.escolherIntensidade('Leve');
      await formulario.salvar();
      await aguardar();

      expect(viewModel.minutosHoje, 35);
      expect(viewModel.registrosDeHoje.single.tipoExercicio, 'Dança');
      viewModel.dispose();
    });

    test('Deve marcar erro de leitura quando o Firestore falha ao carregar a semana', () async {
      final viewModel = criar(repositorio: _RepositorioSemLeitura(fakeFirestore));
      await aguardar();

      expect(viewModel.carregando, isFalse);
      expect(viewModel.erroDeLeitura, isTrue);
      viewModel.dispose();
    });

    test('Quando o dia vira dentro da semana, zera só o "hoje" e guarda o resto da semana', () async {
      await registrar(DateTime(2026, 10, 28, 9, 0), 30);
      // Faltam 300 ms para a meia-noite; o relogio do teste ja passa dela
      // quando o timer da virada dispara.
      agora = DateTime(2026, 10, 28, 23, 59, 59, 700);
      final viewModel = criar();
      await aguardar();
      expect(viewModel.minutosHoje, 30);

      agora = DateTime(2026, 10, 29, 0, 0, 0, 100);
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(viewModel.minutosHoje, 0);
      expect(viewModel.minutosNaSemana, 30);
      expect(viewModel.carregando, isFalse);
      viewModel.dispose();
    });

    test('Quando a semana vira no domingo, zera também o progresso da semana', () async {
      await registrar(DateTime(2026, 10, 31, 9, 0), 120);
      agora = DateTime(2026, 10, 31, 23, 59, 59, 700);
      final viewModel = criar();
      await aguardar();
      expect(viewModel.minutosNaSemana, 120);

      agora = DateTime(2026, 11, 1, 0, 0, 0, 100);
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(viewModel.minutosNaSemana, 0);
      expect(viewModel.minutosHoje, 0);
      viewModel.dispose();
    });
  });
}
