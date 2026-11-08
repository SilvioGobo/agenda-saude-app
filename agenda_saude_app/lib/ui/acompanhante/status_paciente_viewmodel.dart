import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/constants/zona_seguranca_cardiaca.dart';
import '../../data/repositories/dados_repository.dart';
import '../../domain/models/batimento_cardiaco.dart';
import '../../domain/models/limites_alerta.dart';
import '../../domain/models/paciente.dart';
import '../../domain/models/registro_base.dart';

// Status de saude consolidado do card do paciente (Figura 15): "ESTÁVEL" ou
// "ATENÇÃO" pela leitura de BPM mais recente, ou "SEM DADOS" quando nao ha
// leitura recente que diga como o paciente esta agora.
enum StatusSaude { estavel, atencao, semDados }

// Estado de um card do painel do acompanhante (RF05.1, Figura 15): o BPM
// mais recente do paciente em tempo real, ha quanto tempo foi medido, o
// status consolidado pela zona de seguranca (UC04.4) e a ultima atividade da
// rotina. Cada card tem o seu ViewModel, que nasce e morre com o card junto
// com as escutas do Firestore. A zona segue os limites de alerta do paciente
// em tempo real (RF 06.1), inclusive os que outro acompanhante salvar.
class StatusPacienteViewModel extends ChangeNotifier {
  final Paciente paciente;
  final DadosMedicosRepository _dadosRepository;
  final DateTime Function() _agora;

  // De quanto em quanto tempo o card se redesenha sem leitura nova: o "ha X
  // minutos" avanca e a leitura pode deixar de valer (vira "SEM DADOS").
  final Duration intervaloRelogio;

  StatusPacienteViewModel({
    required this.paciente,
    DadosMedicosRepository? dadosRepository,
    DateTime Function()? agora,
    this.intervaloRelogio = const Duration(minutes: 1),
  })  : _dadosRepository = dadosRepository ?? DadosMedicosRepository(),
        _agora = agora ?? DateTime.now;

  StreamSubscription<BatimentoCardiaco?>? _assinaturaBatimento;
  StreamSubscription<RegistroBase?>? _assinaturaAtividade;
  StreamSubscription<LimitesAlerta?>? _assinaturaLimites;
  Timer? _relogio;
  bool _descartado = false;

  // Verdadeiro ate a primeira resposta do Firestore sobre o BPM.
  bool _carregando = true;
  bool get carregando => _carregando;

  BatimentoCardiaco? _ultimoBatimento;
  BatimentoCardiaco? get ultimoBatimento => _ultimoBatimento;

  RegistroBase? _ultimaAtividade;
  RegistroBase? get ultimaAtividade => _ultimaAtividade;

  DateTime get agora => _agora();

  // Limites de BPM do paciente (RF 06.1); null = zona padrao.
  late LimitesAlerta? _limitesAlerta = paciente.limitesAlerta;
  LimitesAlerta? get limitesAlerta => _limitesAlerta;

  int get bpmMinimo => ZonaSegurancaCardiaca.bpmMinimo(
        possuiCardiopatia: paciente.possuiCardiopatia,
        limites: _limitesAlerta,
      );

  int get bpmMaximo => ZonaSegurancaCardiaca.bpmMaximo(
        possuiCardiopatia: paciente.possuiCardiopatia,
        limites: _limitesAlerta,
      );

  // O paciente do card com os limites de agora, para as telas abertas por ele
  // (relatorios, ajuste dos limites) usarem a mesma zona do card.
  Paciente get pacienteAtual {
    final limites = _limitesAlerta;
    if (limites == paciente.limitesAlerta) return paciente;
    return limites == null
        ? paciente.copyWith(semLimitesAlerta: true)
        : paciente.copyWith(limitesAlerta: limites);
  }

  // O acompanhante acabou de salvar limites novos: o card ja muda, sem esperar
  // a escuta do Firestore confirmar.
  void usarLimites(LimitesAlerta? limites) {
    if (_descartado || limites == _limitesAlerta) return;
    _limitesAlerta = limites;
    notifyListeners();
  }

  // A leitura mais recente ainda vale para dizer como o paciente esta agora.
  bool get leituraRecente {
    final batimento = _ultimoBatimento;
    if (batimento == null) return false;
    return _agora().difference(batimento.timestamp) <=
        ZonaSegurancaCardiaca.validadeDaLeitura;
  }

  StatusSaude get status {
    final batimento = _ultimoBatimento;
    if (batimento == null || !leituraRecente) return StatusSaude.semDados;
    final dentro = ZonaSegurancaCardiaca.estaDentroDaZona(
      batimento.bpm,
      possuiCardiopatia: paciente.possuiCardiopatia,
      limites: _limitesAlerta,
    );
    return dentro ? StatusSaude.estavel : StatusSaude.atencao;
  }

  void iniciar() {
    _assinaturaBatimento =
        _dadosRepository.streamUltimoBatimento(paciente.id).listen(
      (batimento) {
        if (_descartado) return;
        _ultimoBatimento = batimento;
        _carregando = false;
        notifyListeners();
      },
      onError: (Object erro) {
        debugPrint('Stream de BPM do paciente ${paciente.id} falhou: $erro');
        if (_descartado) return;
        _carregando = false;
        notifyListeners();
      },
    );

    _assinaturaAtividade =
        _dadosRepository.streamUltimaAtividade(paciente.id).listen(
      (registro) {
        if (_descartado) return;
        _ultimaAtividade = registro;
        notifyListeners();
      },
      // Ex.: indice composto ainda nao publicado. O card segue sem a linha
      // da ultima atividade.
      onError: (Object erro) => debugPrint(
        'Stream da ultima atividade do paciente ${paciente.id} falhou: $erro',
      ),
    );

    _assinaturaLimites =
        _dadosRepository.streamLimitesAlerta(paciente.id).listen(
      usarLimites,
      // O card segue com os limites que vieram na lista de pacientes.
      onError: (Object erro) => debugPrint(
        'Stream dos limites de alerta do paciente ${paciente.id} falhou: $erro',
      ),
    );

    _relogio = Timer.periodic(intervaloRelogio, (_) {
      if (!_descartado) notifyListeners();
    });
  }

  @override
  void dispose() {
    _descartado = true;
    _assinaturaBatimento?.cancel();
    _assinaturaAtividade?.cancel();
    _assinaturaLimites?.cancel();
    _relogio?.cancel();
    super.dispose();
  }
}
