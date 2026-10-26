import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/models/item_refeicao.dart';
import 'package:agenda_saude_app/domain/models/refeicao_planejada.dart';
import 'package:agenda_saude_app/domain/models/registro_refeicao.dart';
import 'package:agenda_saude_app/domain/refeicoes/refeicoes_padrao.dart';

import '../../helpers/catalogo_de_teste.dart';

void main() {
  group('ItemRefeicao Testes', () {
    test('Deve converter para JSON e voltar sem perder nenhum campo', () {
      const original = ItemRefeicao(
        alimentoId: 3,
        nome: 'Arroz, tipo 1, cozido',
        quantidadeG: 150.5,
      );

      final copia = ItemRefeicao.fromJson(original.toJson());

      expect(copia.alimentoId, 3);
      expect(copia.nome, 'Arroz, tipo 1, cozido');
      expect(copia.quantidadeG, 150.5);
    });

    test('Deve aceitar quantidade inteira vinda do Firebase', () {
      final item = ItemRefeicao.fromJson({
        'alimentoId': 3,
        'nome': 'Arroz',
        'quantidadeG': 150,
      });

      expect(item.quantidadeG, 150.0);
    });

    test('Deve calcular os nutrientes pela quantidade e pelo catálogo', () async {
      final catalogo = await catalogoDeTeste();
      const item = ItemRefeicao(
        alimentoId: idArrozCozido,
        nome: 'Arroz, tipo 1, cozido',
        quantidadeG: 150,
      );

      final nutrientes = item.nutrientes(catalogo);

      // 150 g de arroz cozido: 128 kcal, 2,5 g P, 0,2 g G e 28,1 g C por 100 g.
      expect(nutrientes.kcal, closeTo(192, 0.001));
      expect(nutrientes.proteinaG, closeTo(3.75, 0.001));
      expect(nutrientes.gorduraG, closeTo(0.3, 0.001));
      expect(nutrientes.carboidratoG, closeTo(42.15, 0.001));
    });

    test(
      'Deve contar zero para um alimento que não está no catálogo',
      () async {
        final catalogo = await catalogoDeTeste();
        const item = ItemRefeicao(
          alimentoId: 99999,
          nome: 'Alimento antigo',
          quantidadeG: 100,
        );

        expect(item.nutrientes(catalogo).kcal, 0);
      },
    );
  });

  group('RefeicaoPlanejada Testes', () {
    test('Deve converter para JSON e voltar sem perder nenhum campo', () {
      const original = RefeicaoPlanejada(
        id: 'almoco',
        nome: 'Almoço',
        itens: [
          ItemRefeicao(
            alimentoId: 3,
            nome: 'Arroz, tipo 1, cozido',
            quantidadeG: 150,
          ),
          ItemRefeicao(
            alimentoId: 561,
            nome: 'Feijão, carioca, cozido',
            quantidadeG: 100,
          ),
        ],
      );

      final copia = RefeicaoPlanejada.fromJson(original.toJson());

      expect(copia.id, 'almoco');
      expect(copia.nome, 'Almoço');
      expect(copia.itens.map((i) => i.alimentoId), [3, 561]);
      expect(copia.itens.map((i) => i.quantidadeG), [150, 100]);
    });

    test('Deve usar valores vazios quando o JSON vier incompleto', () {
      final refeicao = RefeicaoPlanejada.fromJson({'nome': 'Ceia'});

      expect(refeicao.id, '');
      expect(refeicao.nome, 'Ceia');
      expect(refeicao.itens, isEmpty);
    });

    test('Deve ignorar o texto livre que versões antigas guardavam', () {
      final refeicao = RefeicaoPlanejada.fromJson({
        'id': 'r1',
        'nome': 'Café',
        'descricao': 'Pão e café',
      });

      expect(refeicao.itens, isEmpty);
    });

    test(
      'Deve somar os nutrientes de todos os alimentos da refeição',
      () async {
        final catalogo = await catalogoDeTeste();
        const almoco = RefeicaoPlanejada(
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
        );

        final total = almoco.nutrientes(catalogo);

        expect(total.kcal, closeTo(192 + 76 + 159, 0.001));
        expect(total.proteinaG, closeTo(3.75 + 4.8 + 32.0, 0.001));
        expect(total.gorduraG, closeTo(0.3 + 0.5 + 2.5, 0.001));
        expect(total.carboidratoG, closeTo(42.15 + 13.6, 0.001));
        expect(total.sodioMg, closeTo(1.5 + 2 + 50, 0.001));
      },
    );

    test('Deve dar zero para uma refeição sem alimentos', () async {
      final catalogo = await catalogoDeTeste();

      expect(
        const RefeicaoPlanejada(
          id: 'r',
          nome: 'Ceia',
        ).nutrientes(catalogo).kcal,
        0,
      );
    });
  });

  group('RegistroRefeicao Testes', () {
    test('Deve gravar no JSON com o tipo refeicao e a refeição marcada', () {
      final registro = RegistroRefeicao(
        id: '',
        pacienteId: 'paciente_01',
        dataHora: DateTime(2026, 10, 25, 12, 30),
        refeicaoId: 'almoco',
        nome: 'Almoço',
      );

      final json = registro.toJson();

      expect(json['tipo'], 'refeicao');
      expect(json['pacienteId'], 'paciente_01');
      expect(json['dataHora'], DateTime(2026, 10, 25, 12, 30));
      expect(json['refeicaoId'], 'almoco');
      expect(json['nome'], 'Almoço');
      expect(json.containsKey('id'), false);
    });

    test('Deve ler o registro do Firebase com o id do documento', () {
      final registro = RegistroRefeicao.fromJson({
        'tipo': 'refeicao',
        'pacienteId': 'paciente_01',
        'dataHora': Timestamp.fromDate(DateTime(2026, 10, 25, 12, 30)),
        'refeicaoId': 'almoco',
        'nome': 'Almoço',
      }, 'doc-1');

      expect(registro.id, 'doc-1');
      expect(registro.pacienteId, 'paciente_01');
      expect(registro.dataHora, DateTime(2026, 10, 25, 12, 30));
      expect(registro.refeicaoId, 'almoco');
      expect(registro.nome, 'Almoço');
    });
  });

  group('RefeicoesPadrao Testes', () {
    test(
      'Deve dar café, almoço, lanche da tarde e jantar a quem não tem diabetes',
      () {
        final plano = RefeicoesPadrao.para(possuiDiabetes: false);

        expect(plano.map((r) => r.nome), [
          'Café da manhã',
          'Almoço',
          'Lanche da tarde',
          'Jantar',
        ]);
      },
    );

    test('Deve fracionar em seis refeições para quem tem diabetes', () {
      final plano = RefeicoesPadrao.para(possuiDiabetes: true);

      expect(plano.map((r) => r.nome), [
        'Café da manhã',
        'Lanche da manhã',
        'Almoço',
        'Lanche da tarde',
        'Jantar',
        'Ceia',
      ]);
    });

    test('Deve manter ids únicos e fixos entre as chamadas', () {
      final primeira = RefeicoesPadrao.para(possuiDiabetes: true);
      final segunda = RefeicoesPadrao.para(possuiDiabetes: true);

      expect(primeira.map((r) => r.id).toSet().length, primeira.length);
      expect(primeira.map((r) => r.id), segunda.map((r) => r.id));
      expect(primeira.first.id, 'cafe_da_manha');
    });
  });
}
