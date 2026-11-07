import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../data/repositories/dados_repository.dart';
import '../../domain/models/paciente.dart';
import '../../domain/models/registro_exercicio.dart';
import 'registrar_exercicio_viewmodel.dart';

// Estado do cartao "Exercicio" da rotina diaria (RF03.3): o que o paciente
// fez hoje e quanto falta para a meta de minutos da semana (150, pela OMS). Os
// minutos contam pelo valor de face, qualquer que seja a intensidade. Registrar
// e com o [RegistrarExercicioViewModel]; este acompanha o Firestore em tempo
// real, entao o acompanhante - que le a mesma colecao - ve o mesmo progresso.
class ExercicioViewModel extends ChangeNotifier {
  final Paciente paciente;
  final DadosMedicosRepository _dadosRepository;
  final DateTime Function() _agora;

  StreamSubscription<List<RegistroExercicio>>? _assinatura;
  Timer? _timerViradaDoDia;
  late DateTime _dia;

  ExercicioViewModel({
    required this.paciente,
    DadosMedicosRepository? dadosRepository,
    DateTime Function()? agora,
  })  : _dadosRepository = dadosRepository ?? DadosMedicosRepository(),
        _agora = agora ?? DateTime.now {
    _observarDia();
  }

  // Da semana de hoje (domingo a sabado), do mais recente para o mais antigo.
  List<RegistroExercicio> _registrosDaSemana = const [];

  // Os de hoje, do mais recente para o mais antigo.
  List<RegistroExercicio> get registrosDeHoje => [
        for (final registro in _registrosDaSemana)
          if (_ehDeHoje(registro.dataHora)) registro,
      ];

  bool get fezExercicioHoje => registrosDeHoje.isNotEmpty;

  int get minutosHoje => registrosDeHoje.fold(
        0,
        (soma, registro) => soma + registro.duracaoMinutos,
      );

  int get minutosNaSemana => _registrosDaSemana.fold(
        0,
        (soma, registro) => soma + registro.duracaoMinutos,
      );

  // Meta do paciente (calculada na triagem); contas sem metas usam 150 min.
  int get metaSemanalMinutos => paciente.metaExercicioMinutosSemana;

  int get minutosQueFaltam => max(0, metaSemanalMinutos - minutosNaSemana);

  // De 0 a 1; passar da meta nao estoura a barra.
  double get progressoDaSemana =>
      (minutosNaSemana / metaSemanalMinutos).clamp(0.0, 1.0).toDouble();

  bool get metaAtingida => minutosNaSemana >= metaSemanalMinutos;

  // Verdadeiro ate o Firestore entregar a primeira lista da semana.
  bool _carregando = true;
  bool get carregando => _carregando;

  // A leitura da semana falhou (ex.: sem permissao ou indice faltando): os
  // minutos mostrados nao sao confiaveis, entao a tela esconde o resumo.
  bool _erroDeLeitura = false;
  bool get erroDeLeitura => _erroDeLeitura;

  // Falha ao apagar um exercicio; some na proxima tentativa.
  String? _mensagemErro;
  String? get mensagemErro => _mensagemErro;

  // Apaga um exercicio registrado por engano. Devolve false se falhar (o
  // exercicio continua na lista).
  Future<bool> apagar(RegistroExercicio registro) async {
    _mensagemErro = null;
    try {
      await _dadosRepository.removerRegistro(registro.id);
      return true;
    } catch (erro) {
      debugPrint('Falha ao apagar o exercicio ${registro.id}: $erro');
      _mensagemErro = 'Não foi possível apagar. Tente de novo.';
      notifyListeners();
      return false;
    }
  }

  // O formulario para registrar mais um exercicio. Usa o mesmo Firestore e o
  // mesmo relogio deste ViewModel.
  RegistrarExercicioViewModel novoRegistro() {
    return RegistrarExercicioViewModel(
      paciente: paciente,
      dadosRepository: _dadosRepository,
      agora: _agora,
    );
  }

  bool _ehDeHoje(DateTime dataHora) =>
      dataHora.year == _dia.year &&
      dataHora.month == _dia.month &&
      dataHora.day == _dia.day;

  // Passa a acompanhar a semana de hoje e agenda a virada do dia, para "hoje"
  // voltar a zero a meia-noite - e a semana, no domingo - mesmo com a tela
  // aberta.
  void _observarDia() {
    final agora = _agora();
    _dia = DateTime(agora.year, agora.month, agora.day);

    _assinatura?.cancel();
    _assinatura =
        _dadosRepository.streamExerciciosDaSemana(paciente.id, _dia).listen(
      (registros) {
        _registrosDaSemana = registros;
        _carregando = false;
        _erroDeLeitura = false;
        notifyListeners();
      },
      onError: (Object erro) {
        debugPrint('Stream de exercicio falhou: $erro');
        _carregando = false;
        _erroDeLeitura = true;
        notifyListeners();
      },
    );

    _timerViradaDoDia?.cancel();
    final meiaNoite = DateTime(_dia.year, _dia.month, _dia.day + 1);
    _timerViradaDoDia = Timer(meiaNoite.difference(agora), _aoVirarODia);
  }

  void _aoVirarODia() {
    _registrosDaSemana = const [];
    _carregando = true;
    _observarDia();
    notifyListeners();
  }

  @override
  void dispose() {
    _assinatura?.cancel();
    _timerViradaDoDia?.cancel();
    super.dispose();
  }
}
