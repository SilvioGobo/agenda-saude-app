import 'package:flutter/foundation.dart';

import '../../data/repositories/paciente_repository.dart';
import '../../domain/alergias/alergias.dart';
import '../../domain/models/paciente.dart';

// Estado de "Minhas alergias" (Personalizar rotina): as mesmas alergias da
// triagem - a alimentos, a remedios e as outras -, para o paciente mudar
// depois. Nada e gravado ate "Salvar".
class MinhasAlergiasViewModel extends ChangeNotifier {
  final Paciente _paciente;
  // Criado so ao gravar: abrir a tela nao depende do Firestore.
  PacienteRepository? _pacienteRepositoryInjetado;
  PacienteRepository get _pacienteRepository =>
      _pacienteRepositoryInjetado ??= PacienteRepository();
  final ValueChanged<Paciente>? _aoSalvar;

  MinhasAlergiasViewModel({
    required Paciente paciente,
    PacienteRepository? pacienteRepository,
    ValueChanged<Paciente>? aoSalvar,
  }) : _paciente = paciente,
       _pacienteRepositoryInjetado = pacienteRepository,
       _aoSalvar = aoSalvar,
       alimentos = [...paciente.alergiasAlimentos],
       remedios = [...paciente.alergiasRemedios],
       outras = paciente.alergias ?? '';

  List<String> alimentos;
  List<String> remedios;
  String outras;

  bool salvando = false;
  String? mensagemErro;

  void adicionarAlimento(String nome) {
    alimentos = comAlergia(alimentos, nome);
    _mudou();
  }

  void tirarAlimento(String nome) {
    alimentos = [...alimentos]..remove(nome);
    _mudou();
  }

  void adicionarRemedio(String nome) {
    remedios = comAlergia(remedios, nome);
    _mudou();
  }

  void tirarRemedio(String nome) {
    remedios = [...remedios]..remove(nome);
    _mudou();
  }

  void definirOutras(String texto) {
    outras = texto;
    if (mensagemErro != null) _mudou();
  }

  // Grava e avisa quem abriu a tela com o paciente atualizado. Devolve false
  // se a gravacao falhar (a tela continua aberta, com o aviso).
  Future<bool> salvar() async {
    salvando = true;
    mensagemErro = null;
    notifyListeners();

    try {
      await _pacienteRepository.salvarAlergias(
        _paciente.id,
        alimentos: alimentos,
        remedios: remedios,
        outras: outras,
      );
    } catch (erro) {
      debugPrint('Falha ao salvar as alergias: $erro');
      salvando = false;
      mensagemErro = 'Não foi possível salvar. Tente de novo.';
      notifyListeners();
      return false;
    }

    salvando = false;
    notifyListeners();
    _aoSalvar?.call(
      _paciente.copyWith(
        alergiasAlimentos: alimentos,
        alergiasRemedios: remedios,
        alergias: outras,
      ),
    );
    return true;
  }

  void _mudou() {
    mensagemErro = null;
    notifyListeners();
  }
}
