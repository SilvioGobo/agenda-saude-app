import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/constants/faixas_glicemia.dart';
import '../../core/constants/momentos_glicemia.dart';
import '../../data/repositories/dados_repository.dart';
import '../../domain/models/paciente.dart';
import '../../domain/models/registro_diabete.dart';

// Um item fixo do checklist do dia e o registro feito nele hoje (null se
// ainda esta pendente).
class ItemChecklistGlicemia {
  final MomentoGlicemia momento;
  final RegistroDiabete? registro;

  const ItemChecklistGlicemia({required this.momento, this.registro});

  bool get feito => registro != null;
}

// Estado do cartao "Glicemia e Insulina" da rotina diaria (RF008, UC
// "Gerenciar Uso de Insulina"). So existe para quem marcou diabetes na
// triagem. Escuta em tempo real os registros de diabetes do dia e monta o
// checklist dos momentos da entrevista E6 (ao acordar, antes do almoco,
// antes do jantar, antes de dormir e, para quem usa insulina, a lenta das
// 22h). O registro em si e feito na tela RegistrarGlicemiaView; aqui fica
// so a remocao, para o paciente corrigir um valor digitado errado.
class GlicemiaInsulinaViewModel extends ChangeNotifier {
  final Paciente paciente;
  final DadosMedicosRepository _dadosRepository;
  final DateTime Function() _agora;

  StreamSubscription<List<RegistroDiabete>>? _assinatura;
  Timer? _timerViradaDoDia;
  late DateTime _dia;

  GlicemiaInsulinaViewModel({
    required this.paciente,
    DadosMedicosRepository? dadosRepository,
    DateTime Function()? agora,
  })  : _dadosRepository = dadosRepository ?? DadosMedicosRepository(),
        _agora = agora ?? DateTime.now {
    _observarDia();
  }

  DadosMedicosRepository get dadosRepository => _dadosRepository;

  DateTime agora() => _agora();

  // Do mais recente para o mais antigo.
  List<RegistroDiabete> _registros = const [];
  List<RegistroDiabete> get registros => _registros;

  // Verdadeiro ate o Firestore entregar a primeira lista do dia.
  bool _carregando = true;
  bool get carregando => _carregando;

  // A leitura do dia falhou (ex.: sem permissao ou indice faltando): o
  // checklist nao e confiavel, entao a tela o esconde.
  bool _erroDeLeitura = false;
  bool get erroDeLeitura => _erroDeLeitura;

  // Falha ao apagar um registro; some na proxima tentativa.
  String? _mensagemErro;
  String? get mensagemErro => _mensagemErro;

  bool get usaInsulina => paciente.usaInsulina == true;

  List<MomentoGlicemia> get _momentosDoDia =>
      MomentoGlicemia.doDia(usaInsulina: usaInsulina);

  // Itens fixos na ordem do dia. Se um momento foi registrado mais de uma
  // vez (ex.: em dois aparelhos), vale o registro mais recente.
  List<ItemChecklistGlicemia> get itensDoDia {
    return _momentosDoDia.map((momento) {
      RegistroDiabete? registro;
      for (final r in _registros) {
        if (r.momento == momento.nome) {
          registro = r;
          break;
        }
      }
      return ItemChecklistGlicemia(momento: momento, registro: registro);
    }).toList();
  }

  // Registros fora dos itens fixos ("Outra medição"), do mais antigo para o
  // mais recente, como aparecem no fim do checklist.
  List<RegistroDiabete> get outrasMedicoes {
    final nomesFixos = _momentosDoDia.map((m) => m.nome).toSet();
    return _registros
        .where((r) => !nomesFixos.contains(r.momento))
        .toList()
        .reversed
        .toList();
  }

  int get totalMedicoes => MomentoGlicemia.medicoesDoDia.length;

  int get medicoesFeitas => itensDoDia
      .where((item) => item.momento.medeGlicemia && item.feito)
      .length;

  // Glicemia mais recente do dia (de qualquer momento).
  RegistroDiabete? get ultimaGlicemia {
    for (final r in _registros) {
      if (r.temGlicemia) return r;
    }
    return null;
  }

  // A medicao mais recente do dia deu hipoglicemia: o cartao mostra a
  // orientacao ate uma nova medicao fora da faixa baixa.
  bool get hipoglicemiaNaUltimaMedicao {
    final ultima = ultimaGlicemia;
    return ultima != null && FaixasGlicemia.ehHipoglicemia(ultima.nivelGlicose!);
  }

  Future<bool> apagarRegistro(RegistroDiabete registro) async {
    _mensagemErro = null;
    try {
      await _dadosRepository.removerRegistro(registro.id);
      return true;
    } catch (erro) {
      debugPrint('Falha ao apagar registro de diabetes: $erro');
      _mensagemErro = 'Não foi possível apagar o registro. Tente de novo.';
      notifyListeners();
      return false;
    }
  }

  // Passa a acompanhar o dia atual e agenda a virada para o proximo, para o
  // checklist recomecar a meia-noite mesmo com a tela aberta.
  void _observarDia() {
    final agora = _agora();
    _dia = DateTime(agora.year, agora.month, agora.day);

    _assinatura?.cancel();
    _assinatura =
        _dadosRepository.streamDiabeteDoDia(paciente.id, _dia).listen(
      (registros) {
        _registros = registros;
        _carregando = false;
        _erroDeLeitura = false;
        notifyListeners();
      },
      onError: (Object erro) {
        debugPrint('Stream de glicemia/insulina falhou: $erro');
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
