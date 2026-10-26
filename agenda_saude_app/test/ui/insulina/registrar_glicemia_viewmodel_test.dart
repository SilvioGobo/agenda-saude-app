import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/constants/momentos_glicemia.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_base.dart';
import 'package:agenda_saude_app/ui/insulina/registrar_glicemia_viewmodel.dart';

class _RepositorioQueFalha extends DadosMedicosRepository {
  _RepositorioQueFalha(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Future<void> salvarRegistro(RegistroBase registro) =>
      Future.error(Exception('sem conexao'));
}

void main() {
  group('RegistrarGlicemiaViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    final agora = DateTime(2026, 10, 25, 7, 10);

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
    });

    RegistrarGlicemiaViewModel criar({
      MomentoGlicemia momento = MomentoGlicemia.aoAcordar,
      bool usaInsulina = false,
      DadosMedicosRepository? repositorio,
    }) {
      return RegistrarGlicemiaViewModel(
        paciente: Paciente(
          id: 'paciente_01',
          nome: 'José Silva',
          email: 'jose@email.com',
          perfil: 'Paciente',
          possuiDiabetes: true,
          usaInsulina: usaInsulina,
          possuiCardiopatia: false,
          codigoVinculo: 'ABC123',
        ),
        momento: momento,
        dadosRepository: repositorio ?? dadosRepository,
        agora: () => agora,
      );
    }

    Future<Map<String, dynamic>> unicoRegistroSalvo() async {
      final snapshot =
          await fakeFirestore.collection('registros_diarios').get();
      expect(snapshot.docs.length, 1);
      return snapshot.docs.single.data();
    }

    test('Deve salvar só a glicemia de quem não usa insulina', () async {
      final viewModel = criar();

      expect(viewModel.pedeGlicemia, isTrue);
      expect(viewModel.perguntaSeAplicouInsulina, isFalse);
      expect(viewModel.mostrarCamposInsulina, isFalse);

      final salvou = await viewModel.salvar(glicemia: ' 112 ');

      expect(salvou, isTrue);
      final dados = await unicoRegistroSalvo();
      expect(dados['tipo'], 'diabete');
      expect(dados['momento'], 'Ao acordar');
      expect(dados['nivelGlicose'], 112);
      expect(dados['doseInsulina'], isNull);
      expect(dados['tipoInsulina'], isNull);
    });

    test('Deve exigir a glicemia dentro da faixa do glicosímetro', () async {
      final viewModel = criar();

      expect(await viewModel.salvar(glicemia: ''), isFalse);
      expect(viewModel.erroGlicemia, 'Digite o valor da glicemia.');

      expect(await viewModel.salvar(glicemia: '19'), isFalse);
      expect(viewModel.erroGlicemia, contains('entre 20 e 600'));

      expect(await viewModel.salvar(glicemia: '601'), isFalse);
      expect(await viewModel.salvar(glicemia: '110.5'), isFalse);

      expect(
        (await fakeFirestore.collection('registros_diarios').get()).docs,
        isEmpty,
      );
    });

    test('Deve pedir que responda se aplicou insulina', () async {
      final viewModel = criar(usaInsulina: true);

      expect(viewModel.perguntaSeAplicouInsulina, isTrue);
      expect(await viewModel.salvar(glicemia: '150'), isFalse);
      expect(viewModel.erroInsulina, 'Responda se aplicou insulina agora.');

      viewModel.responderAplicouInsulina(false);
      expect(viewModel.erroInsulina, isNull);
      expect(await viewModel.salvar(glicemia: '150'), isTrue);
      expect((await unicoRegistroSalvo())['doseInsulina'], isNull);
    });

    test('Deve salvar glicemia e dose de insulina rápida com vírgula decimal', () async {
      final viewModel = criar(
        momento: MomentoGlicemia.antesDoAlmoco,
        usaInsulina: true,
      );
      viewModel.responderAplicouInsulina(true);

      expect(viewModel.mostrarCamposInsulina, isTrue);
      expect(viewModel.tipoInsulina, TipoInsulina.rapida);
      expect(await viewModel.salvar(glicemia: '180', dose: ''), isFalse);
      expect(viewModel.erroDose, 'Digite quantas unidades aplicou.');

      expect(await viewModel.salvar(glicemia: '180', dose: '6,5'), isTrue);
      final dados = await unicoRegistroSalvo();
      expect(dados['nivelGlicose'], 180);
      expect(dados['doseInsulina'], 6.5);
      expect(dados['tipoInsulina'], 'Rápida');
      expect(dados['momento'], 'Antes do almoço');
    });

    test('Deve recusar dose fora de 0,5 a 100 unidades', () async {
      final viewModel = criar(usaInsulina: true);
      viewModel.responderAplicouInsulina(true);

      expect(await viewModel.salvar(glicemia: '120', dose: '0'), isFalse);
      expect(viewModel.erroDose, contains('entre 0,5 e 100'));
      expect(await viewModel.salvar(glicemia: '120', dose: '101'), isFalse);
    });

    test('Deve registrar a insulina lenta só com a dose e o tipo fixo', () async {
      final viewModel = criar(
        momento: MomentoGlicemia.insulinaLenta,
        usaInsulina: true,
      );

      expect(viewModel.pedeGlicemia, isFalse);
      expect(viewModel.perguntaSeAplicouInsulina, isFalse);
      expect(viewModel.mostrarCamposInsulina, isTrue);
      expect(viewModel.escolheTipoInsulina, isFalse);

      expect(await viewModel.salvar(dose: '14'), isTrue);
      final dados = await unicoRegistroSalvo();
      expect(dados['nivelGlicose'], isNull);
      expect(dados['doseInsulina'], 14);
      expect(dados['tipoInsulina'], 'Lenta');
    });

    test('Deve permitir escolher a insulina lenta em outro momento', () async {
      final viewModel = criar(usaInsulina: true);
      viewModel.responderAplicouInsulina(true);
      viewModel.selecionarTipoInsulina(TipoInsulina.lenta);

      expect(await viewModel.salvar(glicemia: '100', dose: '20'), isTrue);
      expect((await unicoRegistroSalvo())['tipoInsulina'], 'Lenta');
    });

    test('Deve mostrar mensagem de erro se não conseguir salvar', () async {
      final viewModel =
          criar(repositorio: _RepositorioQueFalha(fakeFirestore));

      expect(await viewModel.salvar(glicemia: '100'), isFalse);
      expect(viewModel.mensagemErro, 'Não foi possível salvar. Tente de novo.');
      expect(viewModel.salvando, isFalse);
    });
  });
}
