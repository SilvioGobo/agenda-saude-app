import 'package:flutter/foundation.dart';

import '../../data/repositories/relatorios_repository.dart';
import '../../domain/models/paciente.dart';
import '../../domain/relatorios/calculadora_relatorios.dart';
import '../../domain/relatorios/resumo_do_mes.dart';
import 'estado_relatorio.dart';

// Estado do relatorio mensal (RF05): o mes aberto na tela, com navegacao para
// os meses anteriores. Abre no mes atual - ou, no dia 1, quando ele ainda nao
// tem nenhum dia encerrado, no mes que acabou de terminar. Meses ja fechados
// nao mudam mais, entao ficam guardados e voltar a eles nao le o Firestore de
// novo; o mes atual e lido a cada abertura.
class RelatorioMesViewModel extends ChangeNotifier {
  final Paciente paciente;
  final RelatoriosRepository _relatoriosRepository;
  final DateTime Function() _agora;

  // Primeiro dia do mes mostrado.
  late DateTime _mes;
  final Map<DateTime, ResumoDoMes> _mesesFechados = {};

  RelatorioMesViewModel({
    required this.paciente,
    RelatoriosRepository? relatoriosRepository,
    DateTime Function()? agora,
  })  : _relatoriosRepository = relatoriosRepository ?? RelatoriosRepository(),
        _agora = agora ?? DateTime.now {
    final hoje = _agora();
    _mes = hoje.day == 1
        ? DateTime(hoje.year, hoje.month - 1)
        : DateTime(hoje.year, hoje.month);
  }

  DateTime get mes => _mes;

  EstadoRelatorio _estado = EstadoRelatorio.carregando;
  EstadoRelatorio get estado => _estado;

  ResumoDoMes? _resumo;
  // Null enquanto carrega ou se a leitura falhou.
  ResumoDoMes? get resumo => _resumo;

  // Leitura atual; a resposta atrasada de um mes que o usuario ja deixou para
  // tras e descartada.
  int _leitura = 0;
  bool _descartado = false;

  DateTime get _mesAtual => CalculadoraRelatorios.primeiroDiaDoMes(_agora());

  // Nao existe relatorio de um mes que ainda nao comecou.
  bool get podeAvancar => _mes.isBefore(_mesAtual);

  Future<void> mesAnterior() {
    _mes = DateTime(_mes.year, _mes.month - 1);
    return carregar();
  }

  Future<void> proximoMes() {
    if (!podeAvancar) return Future.value();
    _mes = DateTime(_mes.year, _mes.month + 1);
    return carregar();
  }

  Future<void> carregar() async {
    final mes = _mes;
    final leitura = ++_leitura;

    final guardado = _mesesFechados[mes];
    if (guardado != null) {
      _resumo = guardado;
      _estado = EstadoRelatorio.pronto;
      notifyListeners();
      return;
    }

    _resumo = null;
    _estado = EstadoRelatorio.carregando;
    notifyListeners();

    try {
      final hoje = _agora();
      // Hoje ainda nao terminou: no mes atual a leitura para na meia-noite.
      final fimDoMes = DateTime(mes.year, mes.month + 1);
      final inicioDeHoje = CalculadoraRelatorios.inicioDoDia(hoje);
      final fim = inicioDeHoje.isBefore(fimDoMes) ? inicioDeHoje : fimDoMes;

      final registros = await _relatoriosRepository.registrosDoPeriodo(
        paciente.id,
        mes,
        fim,
        incluirDiabete: paciente.possuiDiabetes,
      );
      if (_descartado || leitura != _leitura) return;

      final resumo = CalculadoraRelatorios.resumirMes(
        paciente: paciente,
        mes: mes,
        hoje: hoje,
        agua: registros.agua,
        refeicoes: registros.refeicoes,
        medicacoes: registros.medicacoes,
        sono: registros.sono,
        exercicios: registros.exercicios,
        diabete: registros.diabete,
        alertas: registros.alertas,
      );
      if (mes.isBefore(_mesAtual)) _mesesFechados[mes] = resumo;
      _resumo = resumo;
      _estado = EstadoRelatorio.pronto;
    } catch (erro) {
      if (_descartado || leitura != _leitura) return;
      debugPrint('Falha ao carregar o relatorio de $mes: $erro');
      _estado = EstadoRelatorio.erro;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
