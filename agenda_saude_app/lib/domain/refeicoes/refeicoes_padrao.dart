import '../models/refeicao_planejada.dart';

// Plano de refeicoes de quem ainda nao personalizou o seu. Os nomes seguem o
// RF03.4 (Cafe, Almoco, Janta). Diabeticos ganham os dois lanches extras que
// as diretrizes de diabetes recomendam (fracionar em 5 a 6 refeicoes para
// evitar picos e quedas de glicemia). Os ids sao fixos para os registros do
// dia continuarem valendo mesmo que o plano seja gerado de novo.
class RefeicoesPadrao {
  RefeicoesPadrao._();

  static const _cafeDaManha = RefeicaoPlanejada(
    id: 'cafe_da_manha',
    nome: 'Café da manhã',
  );
  static const _lancheDaManha = RefeicaoPlanejada(
    id: 'lanche_da_manha',
    nome: 'Lanche da manhã',
  );
  static const _almoco = RefeicaoPlanejada(id: 'almoco', nome: 'Almoço');
  static const _lancheDaTarde = RefeicaoPlanejada(
    id: 'lanche_da_tarde',
    nome: 'Lanche da tarde',
  );
  static const _jantar = RefeicaoPlanejada(id: 'jantar', nome: 'Jantar');
  static const _ceia = RefeicaoPlanejada(id: 'ceia', nome: 'Ceia');

  static List<RefeicaoPlanejada> para({required bool possuiDiabetes}) {
    if (possuiDiabetes) {
      return const [
        _cafeDaManha,
        _lancheDaManha,
        _almoco,
        _lancheDaTarde,
        _jantar,
        _ceia,
      ];
    }
    return const [_cafeDaManha, _almoco, _lancheDaTarde, _jantar];
  }
}
