import 'package:flutter/foundation.dart';

import '../../data/repositories/acompanhante_repository.dart';
import '../../domain/models/acompanhante.dart';
import '../../domain/models/paciente.dart';

// Estado da tela "Falar com Acompanhante" (Figura 13): os acompanhantes
// vinculados ao paciente, com o telefone de cada um para ligar.
class FalarComAcompanhanteViewModel extends ChangeNotifier {
  final Paciente paciente;
  final AcompanhanteRepository _acompanhanteRepository;

  FalarComAcompanhanteViewModel({
    required this.paciente,
    AcompanhanteRepository? acompanhanteRepository,
  }) : _acompanhanteRepository =
            acompanhanteRepository ?? AcompanhanteRepository();

  List<Acompanhante> _acompanhantes = [];
  // Quem tem telefone vem primeiro: e para quem da para ligar.
  List<Acompanhante> get acompanhantes => _acompanhantes;

  bool _carregando = true;
  bool get carregando => _carregando;

  bool _erroAoCarregar = false;
  bool get erroAoCarregar => _erroAoCarregar;

  bool _descartado = false;

  Future<void> carregar() async {
    _carregando = true;
    _erroAoCarregar = false;
    notifyListeners();

    try {
      final lista = await _acompanhanteRepository
          .listarAcompanhantesDoPaciente(paciente.id);
      _acompanhantes = [
        ...lista.where((a) => a.temTelefone),
        ...lista.where((a) => !a.temTelefone),
      ];
    } catch (e) {
      debugPrint('Falha ao carregar os acompanhantes: $e');
      _erroAoCarregar = true;
    }

    _carregando = false;
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
