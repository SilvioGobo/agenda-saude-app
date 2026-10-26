import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/alimentos/catalogo_alimentos.dart';
import 'package:agenda_saude_app/domain/models/item_refeicao.dart';
import 'package:agenda_saude_app/domain/models/refeicao_planejada.dart';
import 'package:agenda_saude_app/domain/refeicoes/refeicoes_padrao.dart';
import 'package:agenda_saude_app/ui/rotina/personalizar_refeicoes_viewmodel.dart';
import 'package:agenda_saude_app/ui/rotina/refeicoes_viewmodel.dart';

import '../../helpers/catalogo_de_teste.dart';

void main() {
  group('PersonalizarRefeicoesViewModel Testes', () {
    late CatalogoAlimentos catalogo;
    late List<List<RefeicaoPlanejada>> salvos;
    late bool salvarComSucesso;
    var proximoId = 0;

    setUpAll(() async {
      catalogo = await catalogoDeTeste();
    });

    setUp(() {
      salvos = [];
      salvarComSucesso = true;
      proximoId = 0;
    });

    PersonalizarRefeicoesViewModel criar({
      List<RefeicaoPlanejada>? atual,
      bool comCatalogo = true,
    }) {
      return PersonalizarRefeicoesViewModel(
        atual:
            atual ??
            const [
              RefeicaoPlanejada(
                id: 'r1',
                nome: 'Café',
                itens: [
                  ItemRefeicao(
                    alimentoId: idPaoFrances,
                    nome: 'Pão, trigo, francês',
                    quantidadeG: 50,
                  ),
                ],
              ),
              RefeicaoPlanejada(id: 'r2', nome: 'Almoço'),
            ],
        padrao: RefeicoesPadrao.para(possuiDiabetes: false),
        aoSalvar: (plano) async {
          salvos.add(plano);
          return salvarComSucesso;
        },
        catalogo: comCatalogo ? catalogo : null,
        gerarId: () => 'novo_${proximoId++}',
      );
    }

    test('Deve começar com uma cópia editável do plano atual', () {
      final viewModel = criar();

      expect(viewModel.refeicoes.map((r) => r.nome), ['Café', 'Almoço']);
      expect(
        viewModel.refeicoes.first.itens.single.nome,
        'Pão, trigo, francês',
      );
      expect(viewModel.refeicoes.first.itens.single.quantidadeG, 50);
      expect(viewModel.refeicoes.last.itens, isEmpty);
      expect(viewModel.podeAdicionar, isTrue);
      expect(viewModel.podeEscolherAlimentos, isTrue);
      expect(viewModel.mensagemErro, isNull);
    });

    test(
      'Deve adicionar uma refeição nova, sem nome nem alimentos, com id próprio',
      () {
        final viewModel = criar();

        viewModel.adicionar();

        expect(viewModel.refeicoes.length, 3);
        expect(viewModel.refeicoes.last.id, 'novo_0');
        expect(viewModel.refeicoes.last.nome, '');
        expect(viewModel.refeicoes.last.itens, isEmpty);
      },
    );

    test('Não deve passar do máximo de refeições', () {
      final viewModel = criar();

      for (var i = 0; i < 20; i++) {
        viewModel.adicionar();
      }

      expect(viewModel.refeicoes.length, RefeicoesViewModel.maximoRefeicoes);
      expect(viewModel.podeAdicionar, isFalse);
    });

    test('Deve remover uma refeição pelo id', () {
      final viewModel = criar();

      viewModel.remover('r1');

      expect(viewModel.refeicoes.map((r) => r.id), ['r2']);
    });

    test(
      'Deve voltar ao plano padrão e trocar a versão para recriar os campos',
      () {
        final viewModel = criar();
        final versaoAntes = viewModel.versao;

        viewModel.restaurarPadrao();

        expect(viewModel.refeicoes.map((r) => r.nome), [
          'Café da manhã',
          'Almoço',
          'Lanche da tarde',
          'Jantar',
        ]);
        expect(viewModel.refeicoes.every((r) => r.itens.isEmpty), isTrue);
        expect(viewModel.versao, isNot(versaoAntes));
      },
    );

    group('Alimentos da refeição', () {
      test('Deve adicionar o alimento escolhido com 100 g', () {
        final viewModel = criar();
        final almoco = viewModel.refeicoes.last;

        viewModel.adicionarAlimento(almoco, catalogo.porId(idArrozCozido)!);

        expect(almoco.itens.single.alimentoId, idArrozCozido);
        expect(almoco.itens.single.nome, 'Arroz, tipo 1, cozido');
        expect(almoco.itens.single.quantidadeG, 100);
      });

      test(
        'Deve aceitar o mesmo alimento duas vezes, como itens diferentes',
        () {
          final viewModel = criar();
          final almoco = viewModel.refeicoes.last;

          viewModel.adicionarAlimento(almoco, catalogo.porId(idArrozCozido)!);
          viewModel.adicionarAlimento(almoco, catalogo.porId(idArrozCozido)!);

          expect(almoco.itens.length, 2);
          expect(almoco.itens[0].chave, isNot(almoco.itens[1].chave));
        },
      );

      test('Não deve passar do máximo de alimentos por refeição', () {
        final viewModel = criar();
        final almoco = viewModel.refeicoes.last;

        for (var i = 0; i < 30; i++) {
          viewModel.adicionarAlimento(almoco, catalogo.porId(idArrozCozido)!);
        }

        expect(
          almoco.itens.length,
          PersonalizarRefeicoesViewModel.maximoAlimentosPorRefeicao,
        );
        expect(viewModel.podeAdicionarAlimento(almoco), isFalse);
      });

      test('Deve tirar um alimento da refeição', () {
        final viewModel = criar();
        final cafe = viewModel.refeicoes.first;

        viewModel.removerAlimento(cafe, cafe.itens.single);

        expect(cafe.itens, isEmpty);
      });

      test('Deve aceitar a quantidade com vírgula ou ponto', () {
        final viewModel = criar();
        final item = viewModel.refeicoes.first.itens.single;

        viewModel.definirQuantidade(item, '62,5');
        expect(item.quantidadeG, 62.5);

        viewModel.definirQuantidade(item, ' 80.5 ');
        expect(item.quantidadeG, 80.5);
      });

      test('Deve tratar quantidade em branco ou inválida como zero', () {
        final viewModel = criar();
        final item = viewModel.refeicoes.first.itens.single;

        viewModel.definirQuantidade(item, '');
        expect(item.quantidadeG, 0);

        viewModel.definirQuantidade(item, 'abc');
        expect(item.quantidadeG, 0);
      });

      test(
        'Deve avisar quem escuta quando a quantidade muda, para os totais atualizarem',
        () {
          final viewModel = criar();
          var avisos = 0;
          viewModel.addListener(() => avisos++);

          viewModel.definirQuantidade(
            viewModel.refeicoes.first.itens.single,
            '70',
          );

          expect(avisos, 1);
        },
      );
    });

    group('Nutrientes', () {
      test(
        'Deve calcular o que cada alimento, cada refeição e o dia fornecem',
        () {
          final viewModel = criar();
          final almoco = viewModel.refeicoes.last;
          viewModel.adicionarAlimento(almoco, catalogo.porId(idArrozCozido)!);
          viewModel.definirQuantidade(almoco.itens.single, '150');

          final arroz = viewModel.nutrientesDoItem(almoco.itens.single);
          expect(arroz.kcal, closeTo(192, 0.001));
          expect(arroz.carboidratoG, closeTo(42.15, 0.001));

          // 50 g de pao frances: 150 kcal, 4 g de proteina.
          final cafe = viewModel.nutrientesDa(viewModel.refeicoes.first);
          expect(cafe.kcal, closeTo(150, 0.001));
          expect(cafe.proteinaG, closeTo(4.0, 0.001));

          final dia = viewModel.nutrientesDoDia;
          expect(dia.kcal, closeTo(150 + 192, 0.001));
          expect(dia.proteinaG, closeTo(4.0 + 3.75, 0.001));
        },
      );

      test('Deve atualizar o total do dia ao mudar a quantidade', () {
        final viewModel = criar();

        viewModel.definirQuantidade(
          viewModel.refeicoes.first.itens.single,
          '100',
        );

        expect(viewModel.nutrientesDoDia.kcal, closeTo(300, 0.001));
      });

      test('Deve dar zero sem catálogo e não deixar escolher alimentos', () {
        final viewModel = criar(comCatalogo: false);

        expect(viewModel.podeEscolherAlimentos, isFalse);
        expect(viewModel.nutrientesDoDia.kcal, 0);
        // Os alimentos ja cadastrados continuam la.
        expect(viewModel.refeicoes.first.itens.length, 1);
      });
    });

    group('Salvar', () {
      test(
        'Deve salvar nomes sem espaços nas pontas e os alimentos com a quantidade',
        () async {
          final viewModel = criar();
          viewModel.definirNome(viewModel.refeicoes.first, '  Café reforçado ');
          viewModel.adicionarAlimento(
            viewModel.refeicoes.first,
            catalogo.porId(idBananaPrata)!,
          );
          viewModel.definirQuantidade(
            viewModel.refeicoes.first.itens.last,
            '120',
          );
          viewModel.adicionar();
          viewModel.definirNome(viewModel.refeicoes.last, 'Lanche');

          final salvou = await viewModel.salvar();

          expect(salvou, isTrue);
          expect(viewModel.mensagemErro, isNull);
          expect(viewModel.salvando, isFalse);
          final plano = salvos.single;
          expect(plano.map((r) => r.id), ['r1', 'r2', 'novo_0']);
          expect(plano.first.nome, 'Café reforçado');
          expect(plano.first.itens.map((i) => i.alimentoId), [
            idPaoFrances,
            idBananaPrata,
          ]);
          expect(plano.first.itens.map((i) => i.quantidadeG), [50, 120]);
          expect(plano.first.itens.last.nome, 'Banana, prata, crua');
          expect(plano.last.nome, 'Lanche');
          expect(plano.last.itens, isEmpty);
        },
      );

      test(
        'Não deve salvar enquanto alguma refeição estiver sem nome',
        () async {
          final viewModel = criar();
          viewModel.adicionar();
          viewModel.definirNome(viewModel.refeicoes.last, '   ');

          final salvou = await viewModel.salvar();

          expect(salvou, isFalse);
          expect(viewModel.mensagemErro, 'Dê um nome para todas as refeições.');
          expect(salvos, isEmpty);
        },
      );

      test(
        'Deve limpar o aviso de nome vazio quando o paciente digita o nome',
        () async {
          final viewModel = criar();
          viewModel.adicionar();
          await viewModel.salvar();
          expect(viewModel.mensagemErro, isNotNull);

          viewModel.definirNome(viewModel.refeicoes.last, 'Ceia');

          expect(viewModel.mensagemErro, isNull);
        },
      );

      test('Não deve salvar um plano sem nenhuma refeição', () async {
        final viewModel = criar();
        viewModel.remover('r1');
        viewModel.remover('r2');

        final salvou = await viewModel.salvar();

        expect(salvou, isFalse);
        expect(viewModel.mensagemErro, 'Deixe pelo menos uma refeição.');
        expect(salvos, isEmpty);
      });

      test(
        'Não deve salvar com quantidade zero, em branco ou grande demais',
        () async {
          final viewModel = criar();
          final item = viewModel.refeicoes.first.itens.single;

          for (final texto in ['0', '', 'abc', '2001']) {
            viewModel.definirQuantidade(item, texto);

            final salvou = await viewModel.salvar();

            expect(salvou, isFalse, reason: 'quantidade "$texto"');
            expect(
              viewModel.mensagemErro,
              'Informe a quantidade de cada alimento em gramas, de 1 a 2000.',
            );
          }
          expect(salvos, isEmpty);

          viewModel.definirQuantidade(item, '2000');
          expect(await viewModel.salvar(), isTrue);
        },
      );

      test(
        'Deve avisar quando a gravação falha e deixar tentar de novo',
        () async {
          final viewModel = criar();
          salvarComSucesso = false;

          expect(await viewModel.salvar(), isFalse);
          expect(viewModel.mensagemErro, contains('Não foi possível salvar'));
          expect(viewModel.salvando, isFalse);

          salvarComSucesso = true;
          expect(await viewModel.salvar(), isTrue);
          expect(viewModel.mensagemErro, isNull);
        },
      );
    });
  });
}
