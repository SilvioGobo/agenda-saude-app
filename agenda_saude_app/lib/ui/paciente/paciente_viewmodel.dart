import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/constants/zona_seguranca_cardiaca.dart';
import '../../data/repositories/dados_repository.dart';
import '../../domain/models/batimento_cardiaco.dart';
import '../../domain/models/paciente.dart';

enum StatusCardiaco { semLeitura, estavel, atencao }

// Estado do painel principal do paciente (Figura 13 do TCC): saudacao,
// destaque de BPM em tempo real e o status derivado da zona de seguranca
// cardiaca (UC04.4).
class PacienteViewModel extends ChangeNotifier {
  final Paciente paciente;
  final DadosMedicosRepository _dadosRepository;

  StreamSubscription<BatimentoCardiaco?>? _assinaturaBatimento;

  PacienteViewModel({
    required this.paciente,
    DadosMedicosRepository? dadosRepository,
  }) : _dadosRepository = dadosRepository ?? DadosMedicosRepository() {
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

  StatusCardiaco get statusCardiaco {
    final batimento = _ultimoBatimento;
    if (batimento == null) return StatusCardiaco.semLeitura;

    final dentroDaZona = ZonaSegurancaCardiaca.estaDentroDaZona(
      batimento.bpm,
      possuiCardiopatia: paciente.possuiCardiopatia,
    );
    return dentroDaZona ? StatusCardiaco.estavel : StatusCardiaco.atencao;
  }

  @override
  void dispose() {
    _assinaturaBatimento?.cancel();
    super.dispose();
  }
}
