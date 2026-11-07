import 'package:flutter/foundation.dart';

import '../../data/repositories/alimentos_repository.dart';
import '../../data/repositories/relatorios_repository.dart';
import '../../domain/alimentos/catalogo_alimentos.dart';
import '../../domain/alimentos/nutrientes.dart';
import '../../domain/metas/metas_personalizadas.dart';
import '../../domain/models/paciente.dart';
import '../../domain/relatorios/calculadora_relatorios.dart';
import '../../domain/relatorios/resumo_do_dia.dart';
import 'estado_relatorio.dart';

// Estado do relatorio de um dia (RF05): o "Ontem" da tela de relatorios e o
// dia aberto a partir do calendario do mes. Le os registros do paciente no
// Firestore uma vez e monta o [ResumoDoDia]; o paciente e o acompanhante veem
// o mesmo resumo porque leem os mesmos documentos.
//
// Os nutrientes saem dos alimentos que o paciente cadastrou em cada refeicao
// do plano e do catalogo TACO, como na tela de rotina. O catalogo carrega em
// paralelo, mas o relatorio nao espera por ele: ja serve sem os nutrientes, que
// entram quando o catalogo chega - ou nunca, se ele nao carregar.
class RelatorioDiaViewModel extends ChangeNotifier {
  final Paciente paciente;
  // O dia do relatorio, as 00:00.
  final DateTime dia;
  final RelatoriosRepository _relatoriosRepository;
  final AlimentosRepository _alimentosRepository;

  RelatorioDiaViewModel({
    required this.paciente,
    required DateTime dia,
    RelatoriosRepository? relatoriosRepository,
    AlimentosRepository? alimentosRepository,
  })  : dia = CalculadoraRelatorios.inicioDoDia(dia),
        _relatoriosRepository = relatoriosRepository ?? RelatoriosRepository(),
        _alimentosRepository =
            alimentosRepository ?? AlimentosRepository.compartilhado;

  EstadoRelatorio _estado = EstadoRelatorio.carregando;
  EstadoRelatorio get estado => _estado;

  ResumoDoDia? _resumo;
  // Null enquanto carrega ou se a leitura falhou.
  ResumoDoDia? get resumo => _resumo;

  CatalogoAlimentos? _catalogo;

  // Metas do paciente, para comparar com o que as refeicoes forneceram.
  MetasPersonalizadas? get metas => paciente.metas;

  // Leitura atual; uma resposta atrasada de uma leitura anterior e descartada.
  int _leitura = 0;
  bool _descartado = false;

  // Alguma refeicao do plano tem alimentos cadastrados e o catalogo esta
  // disponivel: so entao da para estimar calorias e nutrientes.
  bool get temNutrientes {
    final resumo = _resumo;
    return resumo != null &&
        _catalogo != null &&
        resumo.refeicoes.planejadas.any((item) => item.refeicao.itens.isNotEmpty);
  }

  // Estimativa do que o dia forneceu: soma dos alimentos das refeicoes
  // marcadas como feitas, pelo plano de hoje.
  Nutrientes get nutrientesConsumidos {
    final resumo = _resumo;
    final catalogo = _catalogo;
    if (resumo == null || catalogo == null) return Nutrientes.zero;
    return Nutrientes.somar(
      resumo.refeicoes.planejadas
          .where((item) => item.feita)
          .map((item) => item.refeicao.nutrientes(catalogo)),
    );
  }

  // Termina depois que o catalogo chegou (ou falhou), mas o relatorio ja foi
  // mostrado antes disso.
  Future<void> carregar() async {
    final leitura = ++_leitura;
    _estado = EstadoRelatorio.carregando;
    notifyListeners();

    final catalogoPendente = _carregarCatalogo();

    try {
      final fim = DateTime(dia.year, dia.month, dia.day + 1);
      final (registros, batimentos, exerciciosDaSemana) = await (
        _relatoriosRepository.registrosDoPeriodo(
          paciente.id,
          dia,
          fim,
          incluirDiabete: paciente.possuiDiabetes,
        ),
        _relatoriosRepository.batimentosDoPeriodo(paciente.id, dia, fim),
        _relatoriosRepository.exerciciosDaSemanaAte(paciente.id, dia),
      ).wait;
      if (_descartado || leitura != _leitura) return;

      _resumo = CalculadoraRelatorios.resumirDia(
        paciente: paciente,
        dia: dia,
        agua: registros.agua,
        refeicoes: registros.refeicoes,
        medicacoes: registros.medicacoes,
        sono: registros.sono,
        exercicios: registros.exercicios,
        exerciciosDaSemana: exerciciosDaSemana,
        diabete: registros.diabete,
        batimentos: batimentos,
        alertas: registros.alertas,
      );
      _estado = EstadoRelatorio.pronto;
    } catch (erro) {
      if (_descartado || leitura != _leitura) return;
      debugPrint('Falha ao carregar o relatorio do dia $dia: $erro');
      _resumo = null;
      _estado = EstadoRelatorio.erro;
    }
    notifyListeners();

    final catalogo = await catalogoPendente;
    if (_descartado || catalogo == null || _catalogo != null) return;
    _catalogo = catalogo;
    notifyListeners();
  }

  Future<CatalogoAlimentos?> _carregarCatalogo() async {
    try {
      return await _alimentosRepository.carregar();
    } catch (erro) {
      debugPrint('Falha ao carregar o catalogo de alimentos: $erro');
      return null;
    }
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
