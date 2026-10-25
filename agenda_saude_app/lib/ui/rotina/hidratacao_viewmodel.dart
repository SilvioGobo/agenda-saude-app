import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/constants/meta_hidratacao.dart';
import '../../data/repositories/dados_repository.dart';
import '../../domain/models/paciente.dart';
import '../../domain/models/registro_agua.dart';

// Estado do cartao de hidratacao da rotina diaria (RF03.1, Figura 14 do TCC).
// Cada toque em "+ Copo" grava um RegistroAgua de [MetaHidratacao.mlPorCopo];
// "- Copo" apaga o registro mais recente do dia. O total do dia e sempre a
// soma dos registros do Firestore, entao o acompanhante (que le a mesma
// colecao) enxerga o mesmo progresso do paciente.
class HidratacaoViewModel extends ChangeNotifier {
  final Paciente paciente;
  final DadosMedicosRepository _dadosRepository;
  final DateTime Function() _agora;

  StreamSubscription<List<RegistroAgua>>? _assinatura;
  Timer? _timerViradaDoDia;
  late DateTime _dia;

  HidratacaoViewModel({
    required this.paciente,
    DadosMedicosRepository? dadosRepository,
    DateTime Function()? agora,
  })  : _dadosRepository = dadosRepository ?? DadosMedicosRepository(),
        _agora = agora ?? DateTime.now {
    _observarDia();
  }

  // Do mais recente para o mais antigo.
  List<RegistroAgua> _registros = const [];
  List<RegistroAgua> get registros => _registros;

  // Verdadeiro ate o Firestore entregar a primeira lista do dia.
  bool _carregando = true;
  bool get carregando => _carregando;

  // A leitura do dia falhou (ex.: sem permissao ou indice faltando): o total
  // mostrado nao e confiavel, entao a tela esconde o progresso e os botoes.
  bool _erroDeLeitura = false;
  bool get erroDeLeitura => _erroDeLeitura;

  // Falha ao gravar/apagar um copo; some na proxima tentativa.
  String? _mensagemErro;
  String? get mensagemErro => _mensagemErro;

  int get totalMl => _registros.fold(0, (soma, r) => soma + r.quantidadeML);

  int get copos => totalMl ~/ MetaHidratacao.mlPorCopo;

  // Meta do paciente (calculada na triagem); contas sem metas usam o padrao.
  int get metaMl {
    final calculada = paciente.metas?.hidratacaoMl;
    return calculada != null && calculada >= MetaHidratacao.mlPorCopo
        ? calculada
        : MetaHidratacao.mlDiaria;
  }

  int get metaCopos => metaMl ~/ MetaHidratacao.mlPorCopo;

  // De 0 a 1; passar da meta nao estoura a barra.
  double get progresso => (totalMl / metaMl).clamp(0.0, 1.0).toDouble();

  bool get metaAtingida => totalMl >= metaMl;

  bool get podeRemover => _registros.isNotEmpty;

  Future<void> adicionarCopo() async {
    _mensagemErro = null;
    try {
      await _dadosRepository.salvarRegistro(RegistroAgua(
        id: '',
        pacienteId: paciente.id,
        dataHora: _agora(),
        quantidadeML: MetaHidratacao.mlPorCopo,
      ));
    } catch (erro) {
      debugPrint('Falha ao registrar copo de agua: $erro');
      _mensagemErro = 'Não foi possível registrar o copo. Tente de novo.';
      notifyListeners();
    }
  }

  Future<void> removerCopo() async {
    if (_registros.isEmpty) return;
    _mensagemErro = null;
    try {
      await _dadosRepository.removerRegistro(_registros.first.id);
    } catch (erro) {
      debugPrint('Falha ao remover copo de agua: $erro');
      _mensagemErro = 'Não foi possível tirar o copo. Tente de novo.';
      notifyListeners();
    }
  }

  // Passa a acompanhar o dia atual e agenda a virada para o proximo, para o
  // total voltar a zero a meia-noite mesmo com a tela aberta.
  void _observarDia() {
    final agora = _agora();
    _dia = DateTime(agora.year, agora.month, agora.day);

    _assinatura?.cancel();
    _assinatura = _dadosRepository.streamAguaDoDia(paciente.id, _dia).listen(
      (registros) {
        _registros = registros;
        _carregando = false;
        _erroDeLeitura = false;
        notifyListeners();
      },
      onError: (Object erro) {
        debugPrint('Stream de hidratacao falhou: $erro');
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
    _registros = const [];
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
