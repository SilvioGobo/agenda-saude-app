import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/metas/metas_personalizadas.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_sono.dart';
import 'package:agenda_saude_app/ui/rotina/sono_viewmodel.dart';

// Leitura do dia que sempre falha (ex.: indice composto ainda nao publicado).
class _RepositorioSemLeitura extends DadosMedicosRepository {
  _RepositorioSemLeitura(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Stream<List<RegistroSono>> streamSonoDoDia(String pacienteId, DateTime dia) =>
      Stream.error(Exception('indice faltando'));
}

// Metas de um idoso: 7 a 8 horas de sono (National Sleep Foundation).
const _metasDeIdoso = MetasPersonalizadas(
  imc: 24.7,
  classificacaoImc: ClassificacaoImc.adequado,
  hidratacaoMl: 1500,
  sonoMinHoras: 7,
  sonoMaxHoras: 8,
  passos: 6000,
  exercicioMinutosSemana: 150,
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
  group('SonoViewModel Testes', () {
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

    SonoViewModel criar({
      DadosMedicosRepository? repositorio,
      Paciente? pacienteDaTela,
    }) {
      return SonoViewModel(
        paciente: pacienteDaTela ?? paciente,
        dadosRepository: repositorio ?? dadosRepository,
        agora: () => agora,
      );
    }

    // Deixa o stream do Firestore entregar o que foi gravado.
    Future<void> aguardar() => Future<void>.delayed(Duration.zero);

    // Como o app grava: ao acordar, inicio e fim valem o instante do registro.
    Future<void> registrarSono(
      DateTime quando, {
      String pacienteId = 'paciente_01',
      double horas = 7.5,
      int qualidade = 4,
    }) {
      return dadosRepository.salvarRegistro(RegistroSono(
        id: '',
        pacienteId: pacienteId,
        dataHora: quando,
        dataFim: quando,
        horasTotais: horas,
        qualidade: qualidade,
      ));
    }

    test('Deve começar carregando e sem noite registrada, e liberar a tela com o primeiro resultado', () async {
      final viewModel = criar();

      expect(viewModel.carregando, isTrue);

      await aguardar();

      expect(viewModel.carregando, isFalse);
      expect(viewModel.registrou, isFalse);
      expect(viewModel.registroDeHoje, isNull);
      expect(viewModel.metaAtingida, isFalse);
      viewModel.dispose();
    });

    test('Deve mostrar a noite que o paciente registrou hoje', () async {
      await registrarSono(DateTime(2026, 10, 25, 7, 0), horas: 6.5, qualidade: 3);

      final viewModel = criar();
      await aguardar();

      expect(viewModel.registrou, isTrue);
      expect(viewModel.registroDeHoje!.horasTotais, 6.5);
      expect(viewModel.registroDeHoje!.qualidade, 3);
      viewModel.dispose();
    });

    test('Deve ignorar noites de outros dias e de outros pacientes', () async {
      await registrarSono(DateTime(2026, 10, 24, 7, 0));
      await registrarSono(DateTime(2026, 10, 26, 7, 0));
      await registrarSono(DateTime(2026, 10, 25, 7, 0), pacienteId: 'outro');

      final viewModel = criar();
      await aguardar();

      expect(viewModel.registrou, isFalse);
      viewModel.dispose();
    });

    test('Deve usar a noite mais recente quando há mais de uma no dia', () async {
      await registrarSono(DateTime(2026, 10, 25, 6, 0), horas: 5);
      await registrarSono(DateTime(2026, 10, 25, 9, 0), horas: 8);

      final viewModel = criar();
      await aguardar();

      expect(viewModel.registroDeHoje!.horasTotais, 8);
      viewModel.dispose();
    });

    test('Deve atualizar quando o sono é registrado, sem reabrir a tela', () async {
      final viewModel = criar();
      await aguardar();
      expect(viewModel.registrou, isFalse);

      await registrarSono(DateTime(2026, 10, 25, 7, 0));
      await aguardar();

      expect(viewModel.registrou, isTrue);
      viewModel.dispose();
    });

    test('Deve atingir a meta a partir do mínimo, sem penalizar quem dormiu mais', () async {
      final viewModel = criar();
      await aguardar();

      await registrarSono(DateTime(2026, 10, 25, 7, 0), horas: 6.5);
      await aguardar();
      expect(viewModel.metaAtingida, isFalse);

      await registrarSono(DateTime(2026, 10, 25, 8, 0), horas: 7);
      await aguardar();
      expect(viewModel.metaAtingida, isTrue);

      await registrarSono(DateTime(2026, 10, 25, 9, 0), horas: 10);
      await aguardar();
      expect(viewModel.metaAtingida, isTrue);
      viewModel.dispose();
    });

    test('Deve usar a meta de sono calculada para o paciente', () async {
      final viewModel =
          criar(pacienteDaTela: paciente.copyWith(metas: _metasDeIdoso));
      await aguardar();

      expect(viewModel.metaMinHoras, 7);
      expect(viewModel.metaMaxHoras, 8);
      viewModel.dispose();
    });

    test('Deve usar a meta padrão de 7 a 9 horas quando o paciente não tem metas', () async {
      final viewModel = criar();
      await aguardar();

      expect(viewModel.metaMinHoras, 7);
      expect(viewModel.metaMaxHoras, 9);
      viewModel.dispose();
    });

    test('Deve entregar o formulário vazio no primeiro registro e com a noite de hoje depois', () async {
      final viewModel = criar();
      await aguardar();
      expect(viewModel.novoRegistro().editando, isFalse);

      await registrarSono(DateTime(2026, 10, 25, 7, 0), horas: 6, qualidade: 2);
      await aguardar();

      final formulario = viewModel.novoRegistro();
      expect(formulario.editando, isTrue);
      expect(formulario.horas, 6);
      expect(formulario.qualidade, 2);

      // Grava no mesmo Firestore: ao salvar, o cartão enxerga a noite corrigida.
      formulario.escolherQualidade(5);
      await formulario.salvar();
      await aguardar();
      expect(viewModel.registroDeHoje!.qualidade, 5);
      viewModel.dispose();
    });

    test('Deve marcar erro de leitura quando o Firestore falha ao carregar o dia', () async {
      final viewModel = criar(repositorio: _RepositorioSemLeitura(fakeFirestore));
      await aguardar();

      expect(viewModel.carregando, isFalse);
      expect(viewModel.erroDeLeitura, isTrue);
      viewModel.dispose();
    });

    test('Deve voltar a "não registrado" quando o dia vira, sem reabrir a tela', () async {
      await registrarSono(DateTime(2026, 10, 25, 7, 0));
      // Faltam 300 ms para a meia-noite; o relogio do teste ja passa dela
      // quando o timer da virada dispara.
      agora = DateTime(2026, 10, 25, 23, 59, 59, 700);
      final viewModel = criar();
      await aguardar();
      expect(viewModel.registrou, isTrue);

      agora = DateTime(2026, 10, 26, 0, 0, 0, 100);
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(viewModel.registrou, isFalse);
      expect(viewModel.carregando, isFalse);
      viewModel.dispose();
    });
  });
}
