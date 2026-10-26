// Tipos de insulina gravados em RegistroDiabete.tipoInsulina.
class TipoInsulina {
  TipoInsulina._();

  static const String rapida = 'Rápida';
  static const String lenta = 'Lenta';

  static const List<String> todos = [rapida, lenta];
}

// Momentos do dia para medir a glicemia e aplicar insulina (entrevista E6 do
// TCC): ao acordar, antes do almoco, antes do jantar e antes de dormir. A
// insulina de acao lenta costuma ter horario fixo, as 22h, e vira um item
// proprio do checklist - so de insulina. "Outra medicao" cobre medidas fora
// desses horarios (ex.: o paciente se sentiu mal a tarde).
class MomentoGlicemia {
  // Gravado em RegistroDiabete.momento (e falado pelo leitor de tela).
  final String nome;
  // Como aparece na tela: caixa alta, por extenso, para leitura facil (NF004).
  final String rotulo;
  // Falso so na insulina lenta, que e apenas a dose.
  final bool medeGlicemia;
  // Tipo de insulina ja definido pelo momento (a lenta das 22h); nos demais o
  // paciente escolhe ao registrar.
  final String? tipoInsulinaFixo;

  const MomentoGlicemia._(
    this.nome,
    this.rotulo, {
    this.medeGlicemia = true,
    this.tipoInsulinaFixo,
  });

  static const aoAcordar = MomentoGlicemia._('Ao acordar', 'AO ACORDAR');
  static const antesDoAlmoco =
      MomentoGlicemia._('Antes do almoço', 'ANTES DO ALMOÇO');
  static const antesDoJantar =
      MomentoGlicemia._('Antes do jantar', 'ANTES DO JANTAR');
  static const antesDeDormir =
      MomentoGlicemia._('Antes de dormir', 'ANTES DE DORMIR');
  static const insulinaLenta = MomentoGlicemia._(
    'Insulina lenta (22h)',
    // Espaco que nao quebra: "(22 HORAS)" fica junto na mesma linha.
    'INSULINA LENTA (22\u00A0HORAS)',
    medeGlicemia: false,
    tipoInsulinaFixo: TipoInsulina.lenta,
  );
  static const outraMedicao =
      MomentoGlicemia._('Outra medição', 'OUTRA MEDIÇÃO');

  static const List<MomentoGlicemia> medicoesDoDia = [
    aoAcordar,
    antesDoAlmoco,
    antesDoJantar,
    antesDeDormir,
  ];

  static const List<MomentoGlicemia> todos = [
    ...medicoesDoDia,
    insulinaLenta,
    outraMedicao,
  ];

  // Momento de um registro gravado; nome desconhecido vira medicao avulsa.
  static MomentoGlicemia porNome(String nome) {
    for (final momento in todos) {
      if (momento.nome == nome) return momento;
    }
    return outraMedicao;
  }

  // Itens fixos do checklist do dia: as quatro medicoes e, para quem usa
  // insulina (triagem, RF02.2), a insulina lenta das 22h.
  static List<MomentoGlicemia> doDia({required bool usaInsulina}) => [
        ...medicoesDoDia,
        if (usaInsulina) insulinaLenta,
      ];
}
