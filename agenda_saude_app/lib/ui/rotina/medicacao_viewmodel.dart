import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/dados_repository.dart';
import '../../data/repositories/paciente_repository.dart';
import '../../domain/medicacao/dose_planejada.dart';
import '../../domain/models/medicamento.dart';
import '../../domain/models/paciente.dart';
import '../../domain/models/registro_medicacao.dart';

// Estado do cartao "Medicacoes" da rotina diaria (RF003, Figura 14): uma linha
// por dose - um remedio num horario - que o paciente marca como tomada. Marcar
// grava um RegistroMedicacao no Firestore; desmarcar apaga. A lista de remedios
// fica no proprio paciente (`Paciente.medicamentos`) e e editada em "Meus
// remedios". O acompanhante, que le a mesma colecao, ve o que foi tomado.
class MedicacaoViewModel extends ChangeNotifier {
  // Limites da lista, para ela nao virar um problema na tela.
  static const int maximoRemedios = 10;
  static const int maximoHorariosPorRemedio = 6;

  final DadosMedicosRepository _dadosRepository;
  // Criado so ao gravar: ver os remedios nao depende do Firestore.
  PacienteRepository? _pacienteRepositoryInjetado;
  PacienteRepository get _pacienteRepository =>
      _pacienteRepositoryInjetado ??= PacienteRepository();
  final ValueChanged<Paciente>? _aoAtualizarPaciente;
  final DateTime Function() _agora;

  Paciente _paciente;
  StreamSubscription<List<RegistroMedicacao>>? _assinatura;
  Timer? _timerViradaDoDia;
  late DateTime _dia;

  // Doses cuja marcacao esta sendo gravada: um segundo toque na mesma dose, antes
  // de a primeira chegar ao Firestore, nao pode marcar duas vezes.
  final Set<String> _emAndamento = {};

  MedicacaoViewModel({
    required Paciente paciente,
    DadosMedicosRepository? dadosRepository,
    PacienteRepository? pacienteRepository,
    ValueChanged<Paciente>? aoAtualizarPaciente,
    DateTime Function()? agora,
  })  : _paciente = paciente,
        _dadosRepository = dadosRepository ?? DadosMedicosRepository(),
        _pacienteRepositoryInjetado = pacienteRepository,
        _aoAtualizarPaciente = aoAtualizarPaciente,
        _agora = agora ?? DateTime.now {
    _observarDia();
  }

  Paciente get paciente => _paciente;

  List<Medicamento> get medicamentos => _paciente.medicamentos;

  // As doses do dia, do primeiro horario para o ultimo.
  List<DosePlanejada> get doses => DosePlanejada.doDia(medicamentos);

  // Do mais recente para o mais antigo.
  List<RegistroMedicacao> _registros = const [];

  // Verdadeiro ate o Firestore entregar a primeira lista do dia.
  bool _carregando = true;
  bool get carregando => _carregando;

  // A leitura do dia falhou (ex.: sem permissao ou indice faltando): o que esta
  // marcado nao e confiavel, entao a tela esconde as marcacoes.
  bool _erroDeLeitura = false;
  bool get erroDeLeitura => _erroDeLeitura;

  // Falha ao marcar/desmarcar; some na proxima tentativa.
  String? _mensagemErro;
  String? get mensagemErro => _mensagemErro;

  // A primeira marcacao da dose no dia (se foi marcada em dois aparelhos, vale a
  // mais antiga). Null = ainda nao tomada.
  RegistroMedicacao? registroDa(DosePlanejada dose) {
    RegistroMedicacao? primeiro;
    for (final registro in _registros) {
      if (registro.medicamentoId != dose.medicamentoId ||
          registro.horario != dose.horario) {
        continue;
      }
      if (primeiro == null || registro.dataHora.isBefore(primeiro.dataHora)) {
        primeiro = registro;
      }
    }
    return primeiro;
  }

  bool estaTomada(DosePlanejada dose) => registroDa(dose) != null;

  int get tomadas => doses.where(estaTomada).length;

  int get total => doses.length;

  bool get todasTomadas => total > 0 && tomadas == total;

  // De 0 a 1.
  double get progresso => total == 0 ? 0 : tomadas / total;

  // Marca a dose como tomada ou, se ja estava, desmarca.
  Future<void> alternar(DosePlanejada dose) async {
    if (!_emAndamento.add(dose.chave)) return;
    _mensagemErro = null;
    try {
      if (estaTomada(dose)) {
        final ids = _registros
            .where((registro) =>
                registro.medicamentoId == dose.medicamentoId &&
                registro.horario == dose.horario)
            .map((registro) => registro.id)
            .toList();
        for (final id in ids) {
          await _dadosRepository.removerRegistro(id);
        }
      } else {
        await _dadosRepository.salvarRegistro(
          RegistroMedicacao(
            id: '',
            pacienteId: _paciente.id,
            dataHora: _agora(),
            medicamentoId: dose.medicamentoId,
            horario: dose.horario,
            nome: dose.nome,
            dose: dose.dose,
          ),
        );
      }
    } catch (erro) {
      debugPrint('Falha ao marcar o remedio ${dose.descricao}: $erro');
      _mensagemErro = 'Não foi possível salvar. Tente de novo.';
      notifyListeners();
    } finally {
      _emAndamento.remove(dose.chave);
    }
  }

  // Grava a lista de remedios e passa a mostra-la. Devolve false se a gravacao
  // falhar (a lista em tela continua a antiga).
  Future<bool> salvarMedicamentos(List<Medicamento> novaLista) async {
    try {
      await _pacienteRepository.salvarMedicamentos(_paciente.id, novaLista);
    } catch (erro) {
      debugPrint('Falha ao salvar os remedios: $erro');
      return false;
    }
    _paciente = _paciente.copyWith(medicamentos: novaLista);
    _aoAtualizarPaciente?.call(_paciente);
    notifyListeners();
    return true;
  }

  // Passa a acompanhar o dia atual e agenda a virada para o proximo, para as
  // marcacoes zerarem a meia-noite mesmo com a tela aberta.
  void _observarDia() {
    final agora = _agora();
    _dia = DateTime(agora.year, agora.month, agora.day);

    _assinatura?.cancel();
    _assinatura = _dadosRepository
        .streamMedicacoesDoDia(_paciente.id, _dia)
        .listen(
          (registros) {
            _registros = registros;
            _carregando = false;
            _erroDeLeitura = false;
            notifyListeners();
          },
          onError: (Object erro) {
            debugPrint('Stream de medicacao falhou: $erro');
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
