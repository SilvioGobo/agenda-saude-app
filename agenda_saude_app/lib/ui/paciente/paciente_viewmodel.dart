import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/constants/zona_seguranca_cardiaca.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/dados_repository.dart';
import '../../domain/models/batimento_cardiaco.dart';
import '../../domain/models/paciente.dart';

// `alto`/`baixo` = fora da zona de seguranca, acima do maximo ou abaixo do
// minimo; a tela usa a direcao para explicar o alerta ao paciente.
enum StatusCardiaco { semLeitura, estavel, alto, baixo }

// Estado do painel principal do paciente (Figura 13 do TCC): saudacao,
// destaque de BPM em tempo real e o status derivado da zona de seguranca
// cardiaca (UC04.4).
class PacienteViewModel extends ChangeNotifier {
  final Paciente paciente;
  final DadosMedicosRepository _dadosRepository;
  final AuthRepository _authRepository;

  StreamSubscription<BatimentoCardiaco?>? _assinaturaBatimento;

  PacienteViewModel({
    required this.paciente,
    DadosMedicosRepository? dadosRepository,
    AuthRepository? authRepository,
  })  : _dadosRepository = dadosRepository ?? DadosMedicosRepository(),
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
  }

  BatimentoCardiaco? _ultimoBatimento;
  BatimentoCardiaco? get ultimoBatimento => _ultimoBatimento;

  String get primeiroNome {
    final nome = paciente.nome.trim();
    return nome.isEmpty ? 'Paciente' : nome.split(RegExp(r'\s+')).first;
  }

  int get bpmMinimo => ZonaSegurancaCardiaca.bpmMinimo(
        possuiCardiopatia: paciente.possuiCardiopatia,
      );

  int get bpmMaximo => ZonaSegurancaCardiaca.bpmMaximo(
        possuiCardiopatia: paciente.possuiCardiopatia,
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
    super.dispose();
  }
}
