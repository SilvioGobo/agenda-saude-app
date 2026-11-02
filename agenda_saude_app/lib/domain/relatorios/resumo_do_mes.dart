import 'resumo_do_dia.dart';

// Relatorio de um mes (RF05): o resumo de cada dia ja encerrado e os totais do
// mes. O dia de hoje fica de fora porque ainda pode ser cumprido - entrar na
// conta puxaria as medias para baixo no meio do dia - e os dias que ainda nao
// chegaram tambem.
class ResumoDoMes {
  // Primeiro dia do mes, as 00:00.
  final DateTime mes;
  final int diasNoMes;
  // Dias encerrados do mes, do dia 1 em diante; para o mes atual vai ate ontem.
  final List<ResumoDoDia> dias;
  // Dia do mes de hoje, quando este e o mes atual (null nos meses passados).
  final int? diaDeHoje;

  const ResumoDoMes({
    required this.mes,
    required this.diasNoMes,
    required this.dias,
    this.diaDeHoje,
  });

  int get diasEncerrados => dias.length;

  bool get temDiasEncerrados => dias.isNotEmpty;

  // O resumo do dia [dia] (1 a 31) se ele ja terminou; null se ainda nao.
  ResumoDoDia? diaEncerrado(int dia) =>
      dia >= 1 && dia <= dias.length ? dias[dia - 1] : null;

  // --- Dias da rotina ---

  int _contar(SituacaoDoDia situacao) =>
      dias.where((dia) => dia.situacao == situacao).length;

  int get diasCompletos => _contar(SituacaoDoDia.completo);

  int get diasParciais => _contar(SituacaoDoDia.parcial);

  int get diasSemRegistro => _contar(SituacaoDoDia.semRegistro);

  int get diasComRegistro => diasEncerrados - diasSemRegistro;

  // --- Hidratacao ---

  // A meta e a mesma em todos os dias (vem do cadastro do paciente).
  int get metaAguaMl => dias.isEmpty ? 0 : dias.first.hidratacao.metaMl;

  int get diasComAgua => dias.where((dia) => dia.hidratacao.registrou).length;

  int get diasMetaDeAgua =>
      dias.where((dia) => dia.hidratacao.metaAtingida).length;

  // Media dos dias em que o paciente anotou agua: um dia sem anotacao nao quer
  // dizer que ele nao bebeu nada, so que nao registrou.
  double? get mediaAguaMl {
    final comAgua = dias.where((dia) => dia.hidratacao.registrou).toList();
    if (comAgua.isEmpty) return null;
    final soma = comAgua.fold<int>(0, (s, dia) => s + dia.hidratacao.totalMl);
    return soma / comAgua.length;
  }

  // --- Refeicoes ---

  // Refeicoes do plano multiplicadas pelos dias encerrados.
  int get refeicoesPrevistas =>
      dias.fold(0, (soma, dia) => soma + dia.refeicoes.total);

  int get refeicoesFeitas =>
      dias.fold(0, (soma, dia) => soma + dia.refeicoes.feitas);

  int get diasComTodasAsRefeicoes =>
      dias.where((dia) => dia.refeicoes.todasFeitas).length;

  // --- Glicemia e insulina (so para diabeticos) ---

  // Os dias que tem o bloco de diabetes (todos, ou nenhum).
  Iterable<DiabetesDoDia> get _diabetes =>
      dias.map((dia) => dia.diabetes).whereType<DiabetesDoDia>();

  bool get temDiabetes => dias.any((dia) => dia.diabetes != null);

  EstatisticasGlicemia get glicemia => EstatisticasGlicemia.de(
        _diabetes.expand((diabetes) => diabetes.registros),
      );

  int get medicoesPrevistas =>
      _diabetes.fold(0, (soma, d) => soma + d.medicoesPrevistas);

  int get medicoesFeitas =>
      _diabetes.fold(0, (soma, d) => soma + d.medicoesFeitas);

  double get insulinaTotal =>
      _diabetes.fold(0.0, (soma, d) => soma + d.insulinaTotal);

  int get diasComInsulina => _diabetes.where((d) => d.aplicacoes > 0).length;

  // Dias do mes (1 a 31) com hipoglicemia / glicemia muito alta.
  List<int> get diasComHipoglicemia => _diasOnde(
        (dia) => (dia.diabetes?.glicemia.baixas ?? 0) > 0,
      );

  List<int> get diasComGlicemiaMuitoAlta => _diasOnde(
        (dia) => (dia.diabetes?.glicemia.muitoAltas ?? 0) > 0,
      );

  // --- Batimentos (alertas) ---

  int get emergencias => dias.fold(0, (soma, dia) => soma + dia.emergencias);

  int get avisos => dias.fold(0, (soma, dia) => soma + dia.avisos);

  List<int> get diasComEmergencia => _diasOnde((dia) => dia.emergencias > 0);

  List<int> get diasComAviso => _diasOnde((dia) => dia.avisos > 0);

  // Dias com algo que o acompanhante precisa ver: emergencia de batimentos,
  // hipoglicemia ou glicemia muito alta (marcados no calendario).
  List<int> get diasComAlertaGrave => _diasOnde((dia) => dia.temAlertaGrave);

  // --- Series para os graficos (uma posicao por dia do mes) ---

  // Agua do dia em ml; null onde o dia nao terminou ou nao teve anotacao.
  List<double?> get serieAgua => _serie(
        (dia) => dia.hidratacao.registrou
            ? dia.hidratacao.totalMl.toDouble()
            : null,
      );

  // Glicemia media do dia em mg/dL; null onde nao houve medicao.
  List<double?> get serieGlicemia => _serie((dia) => dia.diabetes?.glicemia.media);

  List<double?> _serie(double? Function(ResumoDoDia dia) valorDe) {
    return List<double?>.generate(diasNoMes, (indice) {
      final dia = diaEncerrado(indice + 1);
      return dia == null ? null : valorDe(dia);
    });
  }

  List<int> _diasOnde(bool Function(ResumoDoDia dia) teste) =>
      [for (final dia in dias) if (teste(dia)) dia.dia.day];
}
