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
  // Gravado em RegistroDiabete.momento e mostrado na tela.
  final String nome;
  // Falso so na insulina lenta, que e apenas a dose.
  final bool medeGlicemia;
  // Tipo de insulina ja definido pelo momento (a lenta das 22h); nos demais o
  // paciente escolhe ao registrar.
  final String? tipoInsulinaFixo;

  const MomentoGlicemia._(
    this.nome, {
    this.medeGlicemia = true,
    this.tipoInsulinaFixo,
  });

  static const aoAcordar = MomentoGlicemia._('Ao acordar');
  static const antesDoAlmoco = MomentoGlicemia._('Antes do almoço');
  static const antesDoJantar = MomentoGlicemia._('Antes do jantar');
  static const antesDeDormir = MomentoGlicemia._('Antes de dormir');
  static const insulinaLenta = MomentoGlicemia._(
    'Insulina lenta (22h)',
    medeGlicemia: false,
    tipoInsulinaFixo: TipoInsulina.lenta,
  );
  static const outraMedicao = MomentoGlicemia._('Outra medição');

  static const List<MomentoGlicemia> medicoesDoDia = [
    aoAcordar,
    antesDoAlmoco,
    antesDoJantar,
    antesDeDormir,
  ];

  // Itens fixos do checklist do dia: as quatro medicoes e, para quem usa
  // insulina (triagem, RF02.2), a insulina lenta das 22h.
  static List<MomentoGlicemia> doDia({required bool usaInsulina}) => [
        ...medicoesDoDia,
        if (usaInsulina) insulinaLenta,
      ];
}
