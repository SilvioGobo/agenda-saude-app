import 'package:flutter/foundation.dart';

import '../../core/constants/faixas_glicemia.dart';
import '../../core/constants/momentos_glicemia.dart';
import '../../data/repositories/dados_repository.dart';
import '../../domain/models/paciente.dart';
import '../../domain/models/registro_diabete.dart';

// Formulario de um registro de glicemia e/ou insulina (RF 07.1 "Registrar
// glicemia diaria" e RF 07.2 "Registrar aplicacao de insulina"):
// - momentos de medicao pedem a glicemia (mg/dL), obrigatoria;
// - quem usa insulina (triagem) responde se aplicou e, se sim, quantas
//   unidades e de qual tipo;
// - a insulina lenta das 22h e so a dose, com o tipo ja definido.
class RegistrarGlicemiaViewModel extends ChangeNotifier {
  final Paciente paciente;
  final MomentoGlicemia momento;
  final DadosMedicosRepository _dadosRepository;
  final DateTime Function() _agora;

  static const double doseMinima = 0.5;
  static const double doseMaxima = 100;

  RegistrarGlicemiaViewModel({
    required this.paciente,
    required this.momento,
    DadosMedicosRepository? dadosRepository,
    DateTime Function()? agora,
  })  : _dadosRepository = dadosRepository ?? DadosMedicosRepository(),
        _agora = agora ?? DateTime.now,
        _tipoInsulina = momento.tipoInsulinaFixo ?? TipoInsulina.rapida;

  bool get pedeGlicemia => momento.medeGlicemia;

  // A insulina lenta e o registro inteiro: nao pergunta se aplicou.
  bool get insulinaObrigatoria => !momento.medeGlicemia;

  bool get perguntaSeAplicouInsulina =>
      paciente.usaInsulina == true && !insulinaObrigatoria;

  bool? _aplicouInsulina;
  bool? get aplicouInsulina => _aplicouInsulina;

  bool get mostrarCamposInsulina =>
      insulinaObrigatoria || _aplicouInsulina == true;

  bool get escolheTipoInsulina => momento.tipoInsulinaFixo == null;

  String _tipoInsulina;
  String get tipoInsulina => _tipoInsulina;

  String? _erroGlicemia;
  String? get erroGlicemia => _erroGlicemia;

  String? _erroInsulina;
  String? get erroInsulina => _erroInsulina;

  String? _erroDose;
  String? get erroDose => _erroDose;

  // Falha ao gravar no Firestore.
  String? _mensagemErro;
  String? get mensagemErro => _mensagemErro;

  bool _salvando = false;
  bool get salvando => _salvando;

  void responderAplicouInsulina(bool aplicou) {
    _aplicouInsulina = aplicou;
    _erroInsulina = null;
    if (!aplicou) _erroDose = null;
    notifyListeners();
  }

  void selecionarTipoInsulina(String tipo) {
    _tipoInsulina = tipo;
    notifyListeners();
  }

  // Valida os textos digitados e grava o registro. Retorna true se salvou.
  Future<bool> salvar({String glicemia = '', String dose = ''}) async {
    if (_salvando) return false;
    _mensagemErro = null;

    final nivelGlicose = pedeGlicemia ? _validarGlicemia(glicemia) : null;
    _erroInsulina = perguntaSeAplicouInsulina && _aplicouInsulina == null
        ? 'Responda se aplicou insulina agora.'
        : null;
    final doseInsulina = mostrarCamposInsulina ? _validarDose(dose) : null;
    if (!mostrarCamposInsulina) _erroDose = null;

    final valido = _erroGlicemia == null &&
        _erroInsulina == null &&
        _erroDose == null;
    if (!valido) {
      notifyListeners();
      return false;
    }

    _salvando = true;
    notifyListeners();
    try {
      await _dadosRepository.salvarRegistro(RegistroDiabete(
        id: '',
        pacienteId: paciente.id,
        dataHora: _agora(),
        nivelGlicose: nivelGlicose,
        momento: momento.nome,
        doseInsulina: doseInsulina,
        tipoInsulina: doseInsulina != null ? _tipoInsulina : null,
      ));
      _salvando = false;
      notifyListeners();
      return true;
    } catch (erro) {
      debugPrint('Falha ao registrar glicemia/insulina: $erro');
      _mensagemErro = 'Não foi possível salvar. Tente de novo.';
      _salvando = false;
      notifyListeners();
      return false;
    }
  }

  // Glicemia capilar e um numero inteiro dentro do que o glicosimetro mede.
  double? _validarGlicemia(String texto) {
    final limpo = texto.trim();
    if (limpo.isEmpty) {
      _erroGlicemia = 'Digite o valor da glicemia.';
      return null;
    }
    final valor = int.tryParse(limpo);
    if (valor == null ||
        valor < FaixasGlicemia.minimoRegistravel ||
        valor > FaixasGlicemia.maximoRegistravel) {
      _erroGlicemia = 'Digite um valor entre '
          '${FaixasGlicemia.minimoRegistravel} e '
          '${FaixasGlicemia.maximoRegistravel} mg/dL.';
      return null;
    }
    _erroGlicemia = null;
    return valor.toDouble();
  }

  // Unidades de insulina, aceitando virgula ("6,5") e meia unidade.
  double? _validarDose(String texto) {
    final limpo = texto.trim().replaceAll(',', '.');
    if (limpo.isEmpty) {
      _erroDose = 'Digite quantas unidades aplicou.';
      return null;
    }
    final valor = double.tryParse(limpo);
    if (valor == null || valor < doseMinima || valor > doseMaxima) {
      _erroDose = 'Digite um valor entre 0,5 e 100 unidades.';
      return null;
    }
    _erroDose = null;
    return valor;
  }
}
