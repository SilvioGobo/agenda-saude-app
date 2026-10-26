import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/alimentos_repository.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/domain/models/item_refeicao.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/refeicao_planejada.dart';
import 'package:agenda_saude_app/domain/models/registro_base.dart';
import 'package:agenda_saude_app/domain/models/registro_refeicao.dart';
import 'package:agenda_saude_app/ui/rotina/refeicoes_viewmodel.dart';

import '../../helpers/catalogo_de_teste.dart';

// Falha ao gravar ou apagar enquanto `falhando` for verdadeiro.
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
  Stream<List<RegistroRefeicao>> streamRefeicoesDoDia(
    String pacienteId,
    DateTime dia,
  ) => Stream.error(Exception('indice faltando'));
}

class _PacienteRepositorioQueFalha extends PacienteRepository {
  _PacienteRepositorioQueFalha(FakeFirebaseFirestore firestore)
    : super(firestore: firestore);

  @override
  Future<void> salvarRefeicoes(
    String pacienteId,
    List<RefeicaoPlanejada> refeicoes,
  ) {
    throw Exception('sem conexao');
  }
}

void main() {
  group('RefeicoesViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    late PacienteRepository pacienteRepository;
    late Paciente paciente;
    late DateTime agora;
    late List<Paciente> atualizacoes;
    late AlimentosRepository alimentosRepository;

    setUp(() {
      alimentosRepository = alimentosRepositoryDeTeste();
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
      pacienteRepository = PacienteRepository(firestore: fakeFirestore);
      // Sem diabetes: plano padrao de 4 refeicoes (cafe, almoco, lanche, jantar).
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
      atualizacoes = [];
    });

    RefeicoesViewModel criar({
      DadosMedicosRepository? dados,
      PacienteRepository? pacientes,
      Paciente? pacienteDoTeste,
    }) {
      return RefeicoesViewModel(
        paciente: pacienteDoTeste ?? paciente,
        dadosRepository: dados ?? dadosRepository,
        pacienteRepository: pacientes ?? pacienteRepository,
        alimentosRepository: alimentosRepository,
        aoAtualizarPaciente: atualizacoes.add,
        agora: () => agora,
      );
    }

    // Deixa o stream do Firestore entregar o que foi gravado.
    Future<void> aguardar() => Future<void>.delayed(Duration.zero);

    test(
      'Deve começar carregando e, depois, mostrar o plano padrão sem nenhuma feita',
      () async {
        final viewModel = criar();

        expect(viewModel.carregando, isTrue);

        await aguardar();

        expect(viewModel.carregando, isFalse);
        expect(viewModel.erroDeLeitura, isFalse);
        expect(viewModel.refeicoes.map((r) => r.nome), [
          'Café da manhã',
          'Almoço',
          'Lanche da tarde',
          'Jantar',
        ]);
        expect(viewModel.total, 4);
        expect(viewModel.feitas, 0);
        expect(viewModel.progresso, 0);
        expect(viewModel.todasFeitas, isFalse);
        viewModel.dispose();
      },
    );

    test('Deve marcar a refeição como feita e gravar o registro', () async {
      final viewModel = criar();
      await aguardar();
      final almoco = viewModel.refeicoes[1];

      await viewModel.alternar(almoco);
      await aguardar();

      expect(viewModel.estaFeita(almoco), isTrue);
      expect(viewModel.feitas, 1);
      expect(viewModel.progresso, 0.25);

      final salvos = await fakeFirestore.collection('registros_diarios').get();
      final dados = salvos.docs.single.data();
      expect(dados['tipo'], 'refeicao');
      expect(dados['pacienteId'], 'paciente_01');
      expect(dados['refeicaoId'], 'almoco');
      expect(dados['nome'], 'Almoço');
      viewModel.dispose();
    });

    test(
      'Deve desmarcar a refeição ao tocar de novo, apagando o registro',
      () async {
        final viewModel = criar();
        await aguardar();
        final cafe = viewModel.refeicoes.first;
        await viewModel.alternar(cafe);
        await aguardar();
        expect(viewModel.estaFeita(cafe), isTrue);

        await viewModel.alternar(cafe);
        await aguardar();

        expect(viewModel.estaFeita(cafe), isFalse);
        expect(viewModel.feitas, 0);
        final salvos = await fakeFirestore
            .collection('registros_diarios')
            .get();
        expect(salvos.docs, isEmpty);
        viewModel.dispose();
      },
    );

    test(
      'Deve apagar todos os registros duplicados da mesma refeição ao desmarcar',
      () async {
        for (final hora in [8, 9]) {
          await dadosRepository.salvarRegistro(
            RegistroRefeicao(
              id: '',
              pacienteId: paciente.id,
              dataHora: DateTime(2026, 10, 25, hora),
              refeicaoId: 'cafe_da_manha',
              nome: 'Café da manhã',
            ),
          );
        }
        final viewModel = criar();
        await aguardar();
        expect(viewModel.feitas, 1);

        await viewModel.alternar(viewModel.refeicoes.first);
        await aguardar();

        expect(viewModel.feitas, 0);
        final salvos = await fakeFirestore
            .collection('registros_diarios')
            .get();
        expect(salvos.docs, isEmpty);
        viewModel.dispose();
      },
    );

    test('Deve avisar quando todas as refeições do dia foram feitas', () async {
      final viewModel = criar();
      await aguardar();

      for (final refeicao in viewModel.refeicoes) {
        await viewModel.alternar(refeicao);
      }
      await aguardar();

      expect(viewModel.feitas, 4);
      expect(viewModel.progresso, 1);
      expect(viewModel.todasFeitas, isTrue);
      viewModel.dispose();
    });

    test(
      'Deve ignorar registros de ontem, de outro paciente e de outros tipos',
      () async {
        Future<void> registrar(String pacienteId, DateTime quando, String id) {
          return dadosRepository.salvarRegistro(
            RegistroRefeicao(
              id: '',
              pacienteId: pacienteId,
              dataHora: quando,
              refeicaoId: id,
              nome: id,
            ),
          );
        }

        await registrar(paciente.id, DateTime(2026, 10, 24, 12), 'almoco');
        await registrar('outro_paciente', DateTime(2026, 10, 25, 12), 'almoco');
        await fakeFirestore.collection('registros_diarios').add({
          'tipo': 'agua',
          'pacienteId': paciente.id,
          'dataHora': DateTime(2026, 10, 25, 12),
          'quantidadeML': 250,
        });

        final viewModel = criar();
        await aguardar();

        expect(viewModel.feitas, 0);
        viewModel.dispose();
      },
    );

    test('Não deve contar a refeição marcada que saiu do plano', () async {
      await dadosRepository.salvarRegistro(
        RegistroRefeicao(
          id: '',
          pacienteId: paciente.id,
          dataHora: DateTime(2026, 10, 25, 12),
          refeicaoId: 'ceia',
          nome: 'Ceia',
        ),
      );
      final viewModel = criar();
      await aguardar();

      expect(viewModel.feitas, 0);
      expect(viewModel.total, 4);
      viewModel.dispose();
    });

    test(
      'Deve mostrar o erro e manter tudo como estava quando marcar falha',
      () async {
        final repositorio = _RepositorioQueFalha(fakeFirestore);
        final viewModel = criar(dados: repositorio);
        await aguardar();

        await viewModel.alternar(viewModel.refeicoes.first);

        expect(viewModel.mensagemErro, contains('Não foi possível salvar'));
        expect(viewModel.feitas, 0);

        repositorio.falhando = false;
        await viewModel.alternar(viewModel.refeicoes.first);
        await aguardar();

        expect(viewModel.mensagemErro, isNull);
        expect(viewModel.feitas, 1);
        viewModel.dispose();
      },
    );

    test('Deve sinalizar erro de leitura quando o Firestore falha', () async {
      final viewModel = criar(dados: _RepositorioSemLeitura(fakeFirestore));

      await aguardar();

      expect(viewModel.carregando, isFalse);
      expect(viewModel.erroDeLeitura, isTrue);
      viewModel.dispose();
    });

    test(
      'Deve zerar as marcações quando o dia vira, com a tela aberta',
      () async {
        await dadosRepository.salvarRegistro(
          RegistroRefeicao(
            id: '',
            pacienteId: paciente.id,
            dataHora: DateTime(2026, 10, 25, 9),
            refeicaoId: 'cafe_da_manha',
            nome: 'Café da manhã',
          ),
        );
        // Faltam 300 ms para a meia-noite; o relogio do teste ja passa dela
        // quando o timer da virada dispara.
        agora = DateTime(2026, 10, 25, 23, 59, 59, 700);
        final viewModel = criar();
        await aguardar();
        expect(viewModel.feitas, 1);

        agora = DateTime(2026, 10, 26, 0, 0, 0, 100);
        await Future<void>.delayed(const Duration(milliseconds: 700));

        expect(viewModel.feitas, 0);
        expect(viewModel.carregando, isFalse);
        viewModel.dispose();
      },
    );

    test(
      'Deve salvar o plano personalizado, trocar as refeições e avisar o painel',
      () async {
        await pacienteRepository.salvarPaciente(paciente);
        final viewModel = criar();
        await aguardar();

        final salvou = await viewModel.salvarPlano(const [
          RefeicaoPlanejada(
            id: 'r1',
            nome: 'Café',
            itens: [
              ItemRefeicao(
                alimentoId: 53,
                nome: 'Pão, trigo, francês',
                quantidadeG: 50,
              ),
            ],
          ),
          RefeicaoPlanejada(id: 'r2', nome: 'Almoço'),
        ]);

        expect(salvou, isTrue);
        expect(viewModel.refeicoes.map((r) => r.nome), ['Café', 'Almoço']);
        expect(viewModel.total, 2);
        expect(atualizacoes.single.refeicoes!.length, 2);

        final salvo = await pacienteRepository.getPaciente(paciente.id);
        expect(salvo!.refeicoes!.map((r) => r.id), ['r1', 'r2']);
        expect(salvo.refeicoes!.first.itens.single.alimentoId, 53);
        expect(salvo.refeicoes!.first.itens.single.quantidadeG, 50);
        viewModel.dispose();
      },
    );

    test('Deve manter o plano antigo quando salvar o plano falha', () async {
      final viewModel = criar(
        pacientes: _PacienteRepositorioQueFalha(fakeFirestore),
      );
      await aguardar();

      final salvou = await viewModel.salvarPlano(const [
        RefeicaoPlanejada(id: 'r1', nome: 'Café'),
      ]);

      expect(salvou, isFalse);
      expect(viewModel.total, 4);
      expect(atualizacoes, isEmpty);
      viewModel.dispose();
    });

    test(
      'Deve usar o plano personalizado do paciente quando ele já tem um',
      () async {
        final viewModel = criar(
          pacienteDoTeste: paciente.copyWith(
            refeicoes: const [RefeicaoPlanejada(id: 'r1', nome: 'Café')],
          ),
        );
        await aguardar();

        expect(viewModel.refeicoes.single.nome, 'Café');
        expect(viewModel.total, 1);
        viewModel.dispose();
      },
    );

    group('Nutrientes do dia', () {
      // Cafe: 50 g de pao frances + 100 g de banana prata.
      // Almoco: 150 g de arroz + 100 g de feijao + 100 g de frango grelhado.
      Paciente comAlimentos() => paciente.copyWith(
        refeicoes: const [
          RefeicaoPlanejada(
            id: 'cafe',
            nome: 'Café',
            itens: [
              ItemRefeicao(
                alimentoId: idPaoFrances,
                nome: 'Pão',
                quantidadeG: 50,
              ),
              ItemRefeicao(
                alimentoId: idBananaPrata,
                nome: 'Banana',
                quantidadeG: 100,
              ),
            ],
          ),
          RefeicaoPlanejada(
            id: 'almoco',
            nome: 'Almoço',
            itens: [
              ItemRefeicao(
                alimentoId: idArrozCozido,
                nome: 'Arroz',
                quantidadeG: 150,
              ),
              ItemRefeicao(
                alimentoId: idFeijaoCarioca,
                nome: 'Feijão',
                quantidadeG: 100,
              ),
              ItemRefeicao(
                alimentoId: idFrangoGrelhado,
                nome: 'Frango',
                quantidadeG: 100,
              ),
            ],
          ),
          RefeicaoPlanejada(id: 'ceia', nome: 'Ceia'),
        ],
      );

      Future<RefeicoesViewModel> criarComCatalogo(Paciente doTeste) async {
        await alimentosRepository.carregar();
        final viewModel = criar(pacienteDoTeste: doTeste);
        await aguardar();
        return viewModel;
      }

      test('Deve carregar o catálogo e somar os nutrientes do plano', () async {
        final viewModel = await criarComCatalogo(comAlimentos());

        expect(viewModel.catalogo, isNotNull);
        expect(viewModel.catalogoComErro, isFalse);
        expect(viewModel.temAlimentos, isTrue);

        final cafe = viewModel.nutrientesDa(viewModel.refeicoes[0]);
        expect(cafe.kcal, closeTo(150 + 98, 0.001));
        expect(cafe.proteinaG, closeTo(4.0 + 1.3, 0.001));
        expect(cafe.carboidratoG, closeTo(29.3 + 26.0, 0.001));
        expect(cafe.sodioMg, closeTo(324, 0.001));

        final plano = viewModel.nutrientesPlanejados;
        expect(plano.kcal, closeTo(150 + 98 + 192 + 76 + 159, 0.001));
        expect(plano.proteinaG, closeTo(5.3 + 3.75 + 4.8 + 32.0, 0.001));
        expect(plano.gorduraG, closeTo(1.65 + 0.3 + 0.5 + 2.5, 0.001));
        viewModel.dispose();
      });

      test(
        'Deve contar no consumido só as refeições marcadas como feitas',
        () async {
          final viewModel = await criarComCatalogo(comAlimentos());
          expect(viewModel.nutrientesConsumidos.kcal, 0);

          await viewModel.alternar(viewModel.refeicoes[0]);
          await aguardar();

          expect(viewModel.nutrientesConsumidos.kcal, closeTo(248, 0.001));

          await viewModel.alternar(viewModel.refeicoes[1]);
          await aguardar();

          expect(
            viewModel.nutrientesConsumidos.kcal,
            closeTo(viewModel.nutrientesPlanejados.kcal, 0.001),
          );

          await viewModel.alternar(viewModel.refeicoes[0]);
          await aguardar();

          expect(viewModel.nutrientesConsumidos.kcal, closeTo(427, 0.001));
          viewModel.dispose();
        },
      );

      test('Deve dizer que não há alimentos no plano padrão', () async {
        final viewModel = await criarComCatalogo(paciente);

        expect(viewModel.temAlimentos, isFalse);
        expect(viewModel.nutrientesPlanejados.kcal, 0);
        viewModel.dispose();
      });

      test('Deve expor as metas do paciente para comparar', () async {
        final viewModel = await criarComCatalogo(paciente);

        expect(viewModel.metas, isNull);
        viewModel.dispose();
      });

      test(
        'Deve zerar os nutrientes e avisar quando o catálogo não carrega',
        () async {
          final viewModel = RefeicoesViewModel(
            paciente: comAlimentos(),
            dadosRepository: dadosRepository,
            pacienteRepository: pacienteRepository,
            alimentosRepository: AlimentosRepository(
              lerTexto: () async => throw Exception('sem arquivo'),
            ),
            agora: () => agora,
          );
          await aguardar();
          await aguardar();

          expect(viewModel.catalogo, isNull);
          expect(viewModel.catalogoComErro, isTrue);
          expect(viewModel.nutrientesPlanejados.kcal, 0);
          expect(viewModel.refeicoes.length, 3);
          viewModel.dispose();
        },
      );
    });
  });
}
