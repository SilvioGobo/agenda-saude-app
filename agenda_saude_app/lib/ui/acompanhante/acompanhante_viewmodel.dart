import 'package:flutter/foundation.dart';

import '../../data/repositories/acompanhante_repository.dart';
import '../../domain/models/acompanhante.dart';
import '../../domain/models/paciente.dart';

// Estado do painel do acompanhante (RF05, Figura 15 do TCC): a lista de
// pacientes vinculados a conta, com carregamento e remocao de vinculo.
class AcompanhanteViewModel extends ChangeNotifier {
  Acompanhante acompanhante;
  final AcompanhanteRepository _acompanhanteRepository;

  AcompanhanteViewModel({
    required this.acompanhante,
    AcompanhanteRepository? acompanhanteRepository,
  }) : _acompanhanteRepository =
            acompanhanteRepository ?? AcompanhanteRepository();

  List<Paciente> pacientesVinculados = [];
  bool carregando = false;
  String? mensagemErro;

  String get primeiroNome {
    final nome = acompanhante.nome.trim();
    return nome.isEmpty ? 'Acompanhante' : nome.split(RegExp(r'\s+')).first;
  }

  // Relê o proprio doc (a lista de ids pode ter mudado apos um vinculo) e
  // carrega os pacientes correspondentes.
  Future<void> carregarPacientes() async {
    carregando = true;
    mensagemErro = null;
    notifyListeners();

    try {
      final atualizado =
          await _acompanhanteRepository.getAcompanhante(acompanhante.id);
      if (atualizado != null) acompanhante = atualizado;

      pacientesVinculados =
          await _acompanhanteRepository.listarPacientesVinculados(acompanhante);
    } catch (e) {
      debugPrint('Falha ao carregar pacientes vinculados: $e');
      mensagemErro = 'Não foi possível carregar seus pacientes. Tente novamente.';
    }

    carregando = false;
    notifyListeners();
  }

  Future<bool> desvincular(Paciente paciente) async {
    carregando = true;
    mensagemErro = null;
    notifyListeners();

    try {
      await _acompanhanteRepository.desvincularPaciente(
        acompanhante.id,
        paciente.id,
      );
      pacientesVinculados.removeWhere((p) => p.id == paciente.id);
      acompanhante = Acompanhante(
        id: acompanhante.id,
        nome: acompanhante.nome,
        email: acompanhante.email,
        perfil: acompanhante.perfil,
        pacientesVinculadosIds: acompanhante.pacientesVinculadosIds
            .where((id) => id != paciente.id)
            .toList(),
      );
      carregando = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Falha ao desvincular paciente: $e');
      mensagemErro = 'Não foi possível desvincular o paciente. Tente novamente.';
      carregando = false;
      notifyListeners();
      return false;
    }
  }
}
