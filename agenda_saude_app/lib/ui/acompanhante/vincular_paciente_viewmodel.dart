import 'package:flutter/foundation.dart';

import '../../core/constants/codigo_vinculo.dart';
import '../../data/repositories/acompanhante_repository.dart';
import '../../data/repositories/paciente_repository.dart';
import '../../domain/models/acompanhante.dart';
import '../../domain/models/codigo_vinculo.dart';

// Fluxo de vinculo de um novo paciente (RF05.4) em duas etapas: o acompanhante
// digita o codigo e ve o nome do paciente encontrado antes de confirmar, para
// nao vincular a pessoa errada por um erro de digitacao.
class VincularPacienteViewModel extends ChangeNotifier {
  final Acompanhante acompanhante;
  final PacienteRepository _pacienteRepository;
  final AcompanhanteRepository _acompanhanteRepository;

  VincularPacienteViewModel({
    required this.acompanhante,
    PacienteRepository? pacienteRepository,
    AcompanhanteRepository? acompanhanteRepository,
  })  : _pacienteRepository = pacienteRepository ?? PacienteRepository(),
        _acompanhanteRepository =
            acompanhanteRepository ?? AcompanhanteRepository();

  bool carregando = false;
  String? mensagemErro;
  CodigoVinculo? pacienteEncontrado;
  bool vinculoConcluido = false;

  Future<bool> buscarPaciente(String codigo) async {
    final codigoNormalizado =
        PacienteRepository.normalizarCodigoVinculo(codigo);

    if (codigoNormalizado.length != tamanhoCodigoVinculo) {
      mensagemErro =
          'O código tem $tamanhoCodigoVinculo caracteres. Confira com o paciente.';
      notifyListeners();
      return false;
    }

    carregando = true;
    mensagemErro = null;
    pacienteEncontrado = null;
    notifyListeners();

    try {
      final encontrado =
          await _pacienteRepository.buscarPorCodigoVinculo(codigoNormalizado);

      if (encontrado == null) {
        mensagemErro = 'Código não encontrado. Confira com o paciente.';
      } else if (acompanhante.pacientesVinculadosIds
          .contains(encontrado.pacienteId)) {
        mensagemErro = 'Este paciente já está vinculado à sua conta.';
      } else {
        pacienteEncontrado = encontrado;
      }
    } catch (e) {
      debugPrint('Busca por código de vínculo falhou: $e');
      mensagemErro = 'Não foi possível buscar o paciente. Tente novamente.';
    }

    carregando = false;
    notifyListeners();
    return pacienteEncontrado != null;
  }

  // Volta para a etapa de digitar o codigo, descartando o paciente encontrado.
  void digitarOutroCodigo() {
    pacienteEncontrado = null;
    mensagemErro = null;
    notifyListeners();
  }

  Future<bool> confirmarVinculo() async {
    final encontrado = pacienteEncontrado;
    if (encontrado == null) return false;

    carregando = true;
    mensagemErro = null;
    notifyListeners();

    try {
      await _acompanhanteRepository.vincularPaciente(
        acompanhante.id,
        encontrado.pacienteId,
      );
      vinculoConcluido = true;
      carregando = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Vínculo falhou: $e');
      mensagemErro = 'Não foi possível concluir o vínculo. Tente novamente.';
      carregando = false;
      notifyListeners();
      return false;
    }
  }
}
