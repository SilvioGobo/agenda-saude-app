import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/limites_alerta.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/acompanhante/limites_alerta_viewmodel.dart';

// Recusa a gravacao, como as security rules fariam com um vinculo desfeito.
class _RepositorioQueFalha extends DadosMedicosRepository {
  _RepositorioQueFalha(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Future<void> salvarLimitesAlerta(String pacienteId, LimitesAlerta? limites) =>
      throw Exception('permission-denied');
}

void main() {
  group('LimitesAlertaViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    final agora = DateTime(2026, 11, 8, 14, 30);

    Paciente paciente({bool possuiCardiopatia = false}) => Paciente(
          id: 'paciente_01',
          nome: 'José Silva',
          email: 'jose@email.com',
          perfil: 'Paciente',
          possuiDiabetes: false,
          possuiCardiopatia: possuiCardiopatia,
          codigoVinculo: 'ABC123',
        );

    LimitesAlertaViewModel criar({
      bool possuiCardiopatia = false,
      LimitesAlerta? limitesAtuais,
      DadosMedicosRepository? repositorio,
    }) {
      return LimitesAlertaViewModel(
        paciente: paciente(possuiCardiopatia: possuiCardiopatia),
        acompanhanteId: 'cuidador_01',
        limitesAtuais: limitesAtuais,
        dadosRepository: repositorio ?? dadosRepository,
        agora: () => agora,
      );
    }

    Future<Map<String, dynamic>?> limitesGravados() async {
      final doc =
          await fakeFirestore.collection('usuarios').doc('paciente_01').get();
      return doc.data()?['limitesAlerta'] as Map<String, dynamic>?;
    }

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
      await fakeFirestore
          .collection('usuarios')
          .doc('paciente_01')
          .set({'nome': 'José Silva', 'perfil': 'Paciente'});
    });

    test('Deve começar na zona padrão do paciente sem limites definidos', () {
      final normal = criar();
      expect((normal.bpmMinimo, normal.bpmMaximo), (60, 100));
      expect(normal.ehPadrao, isTrue);

      final cardiopata = criar(possuiCardiopatia: true);
      expect((cardiopata.bpmMinimo, cardiopata.bpmMaximo), (60, 90));
      expect((cardiopata.padraoMinimo, cardiopata.padraoMaximo), (60, 90));
    });

    test('Deve começar nos limites que já valem para o paciente', () {
      final viewModel = criar(
        limitesAtuais: const LimitesAlerta(bpmMinimo: 50, bpmMaximo: 120),
      );

      expect((viewModel.bpmMinimo, viewModel.bpmMaximo), (50, 120));
      expect(viewModel.ehPadrao, isFalse);
    });

    test('Deve mudar os valores de 5 em 5 e voltar ao padrão', () {
      final viewModel = criar();

      viewModel.diminuirMinimo();
      viewModel.aumentarMaximo();
      viewModel.aumentarMaximo();
      expect((viewModel.bpmMinimo, viewModel.bpmMaximo), (55, 110));

      viewModel.voltarAoPadrao();
      expect((viewModel.bpmMinimo, viewModel.bpmMaximo), (60, 100));
      expect(viewModel.ehPadrao, isTrue);
    });

    test('Não deve passar das faixas aceitas', () {
      final viewModel = criar(
        limitesAtuais: const LimitesAlerta(bpmMinimo: 40, bpmMaximo: 150),
      );
      expect(viewModel.podeDiminuirMinimo, isFalse);
      expect(viewModel.podeAumentarMaximo, isFalse);

      viewModel.diminuirMinimo();
      viewModel.aumentarMaximo();
      expect((viewModel.bpmMinimo, viewModel.bpmMaximo), (40, 150));
    });

    test('Deve manter ao menos 20 BPM entre o mínimo e o máximo', () {
      final viewModel = criar(
        limitesAtuais: const LimitesAlerta(bpmMinimo: 80, bpmMaximo: 100),
      );
      expect(viewModel.podeAumentarMinimo, isFalse);
      expect(viewModel.podeDiminuirMaximo, isFalse);

      viewModel.aumentarMinimo();
      viewModel.diminuirMaximo();
      expect((viewModel.bpmMinimo, viewModel.bpmMaximo), (80, 100));

      // Mas o maximo sobe e o minimo desce.
      expect(viewModel.podeAumentarMaximo, isTrue);
      expect(viewModel.podeDiminuirMinimo, isTrue);
    });

    test('Deve salvar os limites com quem ajustou e quando', () async {
      final viewModel = criar();
      viewModel.diminuirMinimo();
      viewModel.aumentarMaximo();

      expect(await viewModel.salvar(), isTrue);

      expect(await limitesGravados(), {
        'bpmMinimo': 55,
        'bpmMaximo': 105,
        'atualizadoPor': 'cuidador_01',
        'atualizadoEm': isNotNull,
      });
      expect(viewModel.limitesSalvos?.bpmMinimo, 55);
      expect(viewModel.limitesSalvos?.atualizadoEm, agora);
      expect(viewModel.salvando, isFalse);
    });

    test('Deve tirar os limites do paciente ao salvar a zona padrão', () async {
      await dadosRepository.salvarLimitesAlerta(
        'paciente_01',
        const LimitesAlerta(bpmMinimo: 50, bpmMaximo: 120),
      );
      final viewModel = criar(
        limitesAtuais: const LimitesAlerta(bpmMinimo: 50, bpmMaximo: 120),
      );

      viewModel.voltarAoPadrao();
      expect(await viewModel.salvar(), isTrue);

      expect(await limitesGravados(), isNull);
      expect(viewModel.limitesSalvos, isNull);
    });

    test('Deve explicar quando não consegue salvar', () async {
      final viewModel =
          criar(repositorio: _RepositorioQueFalha(fakeFirestore));
      viewModel.aumentarMaximo();

      expect(await viewModel.salvar(), isFalse);

      expect(viewModel.mensagemErro, contains('Não foi possível salvar'));
      expect(viewModel.salvando, isFalse);
      // Mexer nos valores apaga o erro.
      viewModel.aumentarMaximo();
      expect(viewModel.mensagemErro, isNull);
    });
  });
}
