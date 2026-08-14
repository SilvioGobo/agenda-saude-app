import 'package:flutter/foundation.dart';

import '../../data/repositories/paciente_repository.dart';
import '../../domain/models/paciente.dart';

class TriagemViewModel extends ChangeNotifier {
  final PacienteRepository _pacienteRepository;
  final Paciente _pacienteOriginal;

  TriagemViewModel({
    required Paciente paciente,
    PacienteRepository? pacienteRepository,
  })  : _pacienteOriginal = paciente,
        _pacienteRepository = pacienteRepository ?? PacienteRepository();

  // Diabetes
  bool? possuiDiabetes;
  String? tipoDiabetes;
  bool? usaInsulina;
  String tipoInsulina = '';

  // Cardiopatia
  bool? possuiCardiopatia;
  String tipoCardiopatia = '';
  bool? usaMarcapasso;

  // Dados fisicos/demograficos (obrigatorios)
  DateTime? dataNascimento;
  String? sexoBiologico;
  double? alturaCm;
  double? pesoKg;
  String? nivelAtividadeFisica;

  // Outras informacoes (opcionais)
  String alergias = '';
  String medicamentosEmUso = '';

  bool carregando = false;
  String? mensagemErro;

  void responderDiabetes(bool valor) {
    possuiDiabetes = valor;
    if (!valor) {
      tipoDiabetes = null;
      usaInsulina = null;
      tipoInsulina = '';
    }
    mensagemErro = null;
    notifyListeners();
  }

  void selecionarTipoDiabetes(String tipo) {
    tipoDiabetes = tipo;
    mensagemErro = null;
    notifyListeners();
  }

  void responderUsaInsulina(bool valor) {
    usaInsulina = valor;
    if (!valor) tipoInsulina = '';
    mensagemErro = null;
    notifyListeners();
  }

  void definirTipoInsulina(String valor) {
    tipoInsulina = valor;
  }

  void responderCardiopatia(bool valor) {
    possuiCardiopatia = valor;
    if (!valor) {
      tipoCardiopatia = '';
      usaMarcapasso = null;
    }
    mensagemErro = null;
    notifyListeners();
  }

  void definirTipoCardiopatia(String valor) {
    tipoCardiopatia = valor;
  }

  void responderUsaMarcapasso(bool valor) {
    usaMarcapasso = valor;
    mensagemErro = null;
    notifyListeners();
  }

  void definirDataNascimento(DateTime valor) {
    dataNascimento = valor;
    mensagemErro = null;
    notifyListeners();
  }

  void selecionarSexoBiologico(String valor) {
    sexoBiologico = valor;
    mensagemErro = null;
    notifyListeners();
  }

  void definirAltura(String valor) {
    alturaCm = double.tryParse(valor.replaceAll(',', '.'));
  }

  void definirPeso(String valor) {
    pesoKg = double.tryParse(valor.replaceAll(',', '.'));
  }

  void selecionarNivelAtividadeFisica(String valor) {
    nivelAtividadeFisica = valor;
    mensagemErro = null;
    notifyListeners();
  }

  void definirAlergias(String valor) {
    alergias = valor;
  }

  void definirMedicamentosEmUso(String valor) {
    medicamentosEmUso = valor;
  }

  // Cada etapa do assistente valida só os campos que ela mesma mostra, e
  // guarda o erro em mensagemErro para a tela exibir. Retorna true quando
  // pode avançar para a próxima etapa.
  bool validarEAvancarSobreVoce() {
    if (dataNascimento == null ||
        sexoBiologico == null ||
        alturaCm == null ||
        pesoKg == null ||
        nivelAtividadeFisica == null) {
      mensagemErro =
          'Preencha data de nascimento, sexo, altura, peso e nível de atividade física.';
      notifyListeners();
      return false;
    }
    if (alturaCm! <= 0 || alturaCm! > 250 || pesoKg! <= 0 || pesoKg! > 400) {
      mensagemErro = 'Confira os valores de altura e peso.';
      notifyListeners();
      return false;
    }
    mensagemErro = null;
    notifyListeners();
    return true;
  }

  bool validarEAvancarDiabetes() {
    if (possuiDiabetes == null) {
      mensagemErro = 'Responda se você possui diabetes.';
      notifyListeners();
      return false;
    }
    if (possuiDiabetes == true &&
        (tipoDiabetes == null || usaInsulina == null)) {
      mensagemErro = 'Complete as perguntas sobre diabetes.';
      notifyListeners();
      return false;
    }
    mensagemErro = null;
    notifyListeners();
    return true;
  }

  bool validarEAvancarCardiopatia() {
    if (possuiCardiopatia == null) {
      mensagemErro = 'Responda se você possui alguma cardiopatia.';
      notifyListeners();
      return false;
    }
    if (possuiCardiopatia == true && usaMarcapasso == null) {
      mensagemErro = 'Complete as perguntas sobre cardiopatia.';
      notifyListeners();
      return false;
    }
    mensagemErro = null;
    notifyListeners();
    return true;
  }

  Future<bool> concluirTriagem() async {
    if (!validarEAvancarSobreVoce()) return false;
    if (!validarEAvancarDiabetes()) return false;
    if (!validarEAvancarCardiopatia()) return false;

    carregando = true;
    mensagemErro = null;
    notifyListeners();

    try {
      final pacienteAtualizado = Paciente(
        id: _pacienteOriginal.id,
        nome: _pacienteOriginal.nome,
        email: _pacienteOriginal.email,
        perfil: _pacienteOriginal.perfil,
        possuiDiabetes: possuiDiabetes!,
        tipoDiabetes: possuiDiabetes! ? tipoDiabetes : null,
        usaInsulina: possuiDiabetes! ? usaInsulina : null,
        tipoInsulina:
            (possuiDiabetes! && usaInsulina == true && tipoInsulina.trim().isNotEmpty)
                ? tipoInsulina.trim()
                : null,
        possuiCardiopatia: possuiCardiopatia!,
        tipoCardiopatia:
            (possuiCardiopatia! && tipoCardiopatia.trim().isNotEmpty)
                ? tipoCardiopatia.trim()
                : null,
        usaMarcapasso: possuiCardiopatia! ? usaMarcapasso : null,
        codigoVinculo: _pacienteOriginal.codigoVinculo,
        triagemConcluida: true,
        dataNascimento: dataNascimento,
        sexoBiologico: sexoBiologico,
        alturaCm: alturaCm,
        pesoKg: pesoKg,
        nivelAtividadeFisica: nivelAtividadeFisica,
        alergias: alergias.trim().isNotEmpty ? alergias.trim() : null,
        medicamentosEmUso: medicamentosEmUso.trim().isNotEmpty
            ? medicamentosEmUso.trim()
            : null,
      );

      await _pacienteRepository.salvarPaciente(pacienteAtualizado);

      carregando = false;
      notifyListeners();
      return true;
    } catch (_) {
      mensagemErro = 'Não foi possível salvar a triagem. Tente novamente.';
      carregando = false;
      notifyListeners();
      return false;
    }
  }
}
