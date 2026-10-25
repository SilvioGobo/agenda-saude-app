import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/dados_repository.dart';
import '../../domain/models/paciente.dart';
import '../../domain/models/registro_diabete.dart';

// Ultima glicemia e ultima dose de insulina registradas por um paciente.
class ResumoDiabete {
  final RegistroDiabete? ultimaGlicemia;
  final RegistroDiabete? ultimaInsulina;

  const ResumoDiabete({this.ultimaGlicemia, this.ultimaInsulina});

  factory ResumoDiabete.dosRegistros(List<RegistroDiabete> recentesPrimeiro) {
    RegistroDiabete? glicemia;
    RegistroDiabete? insulina;
    for (final registro in recentesPrimeiro) {
      if (glicemia == null && registro.temGlicemia) glicemia = registro;
      if (insulina == null && registro.temInsulina) insulina = registro;
    }
    return ResumoDiabete(ultimaGlicemia: glicemia, ultimaInsulina: insulina);
  }
}

// Controle de diabetes dos pacientes vinculados, visto pelo acompanhante
// (RF008: o registro "e disponibilizado para o acompanhante"). Escuta em
// tempo real os registros mais recentes de cada paciente diabetico e guarda
// a ultima glicemia e a ultima dose - o "ultimo evento da rotina" do card do
// paciente (Figura 15). Segue a lista de pacientes vinculados do mesmo jeito
// que a central de alertas.
class DiabetesAcompanhanteViewModel extends ChangeNotifier {
  final DadosMedicosRepository _dadosRepository;

  DiabetesAcompanhanteViewModel({DadosMedicosRepository? dadosRepository})
      : _dadosRepository = dadosRepository ?? DadosMedicosRepository();

  final Map<String, StreamSubscription<Object?>> _assinaturas = {};
  final Map<String, ResumoDiabete> _resumos = {};
  bool _descartado = false;

  // Null enquanto a primeira leitura do paciente nao chegou (ou se ele nao
  // e diabetico).
  ResumoDiabete? resumoDe(String pacienteId) => _resumos[pacienteId];

  // Chamado sempre que a lista de pacientes vinculados muda: abre a escuta
  // dos diabeticos que entraram e encerra a de quem saiu. Nao notifica os
  // ouvintes porque roda durante o build do painel.
  void acompanharPacientes(List<Paciente> pacientes) {
    final ids = pacientes
        .where((p) => p.possuiDiabetes)
        .map((p) => p.id)
        .toSet();

    for (final id
        in _assinaturas.keys.where((id) => !ids.contains(id)).toList()) {
      _assinaturas.remove(id)?.cancel();
      _resumos.remove(id);
    }

    for (final id in ids) {
      if (_assinaturas.containsKey(id)) continue;
      _assinaturas[id] =
          _dadosRepository.streamUltimosRegistrosDiabete(id).listen(
        (registros) {
          if (_descartado) return;
          _resumos[id] = ResumoDiabete.dosRegistros(registros);
          notifyListeners();
        },
        onError: (Object erro) => debugPrint(
          'Stream de glicemia/insulina do paciente $id falhou: $erro',
        ),
      );
    }
  }

  @override
  void dispose() {
    _descartado = true;
    for (final assinatura in _assinaturas.values) {
      assinatura.cancel();
    }
    super.dispose();
  }
}
