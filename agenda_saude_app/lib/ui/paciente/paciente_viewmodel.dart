import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/constants/zona_seguranca_cardiaca.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/dados_repository.dart';
import '../../domain/models/batimento_cardiaco.dart';
import '../../domain/models/limites_alerta.dart';
import '../../domain/models/paciente.dart';

// `alto`/`baixo` = fora da zona de seguranca, acima do maximo ou abaixo do
// minimo; a tela usa a direcao para explicar o alerta ao paciente.
enum StatusCardiaco { semLeitura, estavel, alto, baixo }

// Estado do painel principal do paciente (Figura 13 do TCC): saudacao,
// destaque de BPM em tempo real e o status derivado da zona de seguranca
// cardiaca (UC04.4). A zona segue em tempo real os limites que o acompanhante
// definir (RF 06.1), para o painel mudar junto com o alerta.
class PacienteViewModel extends ChangeNotifier {
  Paciente _paciente;
  final DadosMedicosRepository _dadosRepository;
  final AuthRepository _authRepository;

  StreamSubscription<BatimentoCardiaco?>? _assinaturaBatimento;
  StreamSubscription<LimitesAlerta?>? _assinaturaLimites;

  // Os limites mais recentes do Firestore. As telas abertas a partir do painel
  // devolvem o paciente que receberam ao abrir, que pode ter limites antigos.
  LimitesAlerta? _limites;

  PacienteViewModel({
    required Paciente paciente,
    DadosMedicosRepository? dadosRepository,
    AuthRepository? authRepository,
  })  : _paciente = paciente,
        _limites = paciente.limitesAlerta,
        _dadosRepository = dadosRepository ?? DadosMedicosRepository(),
        _authRepository = authRepository ?? AuthRepository() {
    _assinaturaBatimento =
        _dadosRepository.streamUltimoBatimento(paciente.id).listen(
      (batimento) {
        _ultimoBatimento = batimento;
        notifyListeners();
      },
      // Sem isso um erro do Firestore (ex.: indice composto faltando) vira
      // excecao nao tratada e o painel fica em "aguardando leitura" sem pista.
      onError: (Object erro) =>
          debugPrint('Stream de batimentos falhou: $erro'),
    );

    _assinaturaLimites =
        _dadosRepository.streamLimitesAlerta(paciente.id).listen(
      (limites) {
        if (limites == _limites) return;
        _limites = limites;
        _paciente = _comLimitesAtuais(_paciente);
        notifyListeners();
      },
      // O painel segue com os limites do login.
      onError: (Object erro) =>
          debugPrint('Stream dos limites de alerta falhou: $erro'),
    );
  }

  Paciente get paciente => _paciente;

  // O paciente muda depois do login quando ele atualiza as metas; as telas
  // abertas a partir do painel (ex.: Minha Rotina) leem o valor novo daqui.
  void atualizarPaciente(Paciente atualizado) {
    _paciente = _comLimitesAtuais(atualizado);
    notifyListeners();
  }

  Paciente _comLimitesAtuais(Paciente paciente) {
    if (paciente.limitesAlerta == _limites) return paciente;
    final limites = _limites;
    return limites == null
        ? paciente.copyWith(semLimitesAlerta: true)
        : paciente.copyWith(limitesAlerta: limites);
  }

  BatimentoCardiaco? _ultimoBatimento;
  BatimentoCardiaco? get ultimoBatimento => _ultimoBatimento;

  String get primeiroNome {
    final nome = paciente.nome.trim();
    return nome.isEmpty ? 'Paciente' : nome.split(RegExp(r'\s+')).first;
  }

  int get bpmMinimo => ZonaSegurancaCardiaca.bpmMinimo(
        possuiCardiopatia: paciente.possuiCardiopatia,
        limites: paciente.limitesAlerta,
      );

  int get bpmMaximo => ZonaSegurancaCardiaca.bpmMaximo(
        possuiCardiopatia: paciente.possuiCardiopatia,
        limites: paciente.limitesAlerta,
      );

  StatusCardiaco get statusCardiaco {
    final batimento = _ultimoBatimento;
    if (batimento == null) return StatusCardiaco.semLeitura;
    if (batimento.bpm > bpmMaximo) return StatusCardiaco.alto;
    if (batimento.bpm < bpmMinimo) return StatusCardiaco.baixo;
    return StatusCardiaco.estavel;
  }

  Future<void> sair() => _authRepository.sair();

  @override
  void dispose() {
    _assinaturaBatimento?.cancel();
    _assinaturaLimites?.cancel();
    super.dispose();
  }
}
