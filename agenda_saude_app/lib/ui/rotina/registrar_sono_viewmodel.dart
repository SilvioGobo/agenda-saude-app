import 'package:flutter/foundation.dart';

import '../../core/constants/meta_sono.dart';
import '../../data/repositories/dados_repository.dart';
import '../../domain/models/paciente.dart';
import '../../domain/models/registro_sono.dart';

// Formulario da noite de sono (RF 03.2 "Registrar qualidade do sono"): o
// paciente informa as horas dormidas, de meia em meia hora, e como foi o sono
// numa escala de 1 a 5. Quem ja registrou hoje abre o formulario com o que
// registrou e, ao salvar, corrige a mesma noite em vez de criar outra.
class RegistrarSonoViewModel extends ChangeNotifier {
  final Paciente paciente;
  // A noite de hoje que sera corrigida; null no primeiro registro do dia.
  final RegistroSono? registroAtual;
  final DadosMedicosRepository _dadosRepository;
  final DateTime Function() _agora;

  RegistrarSonoViewModel({
    required this.paciente,
    this.registroAtual,
    DadosMedicosRepository? dadosRepository,
    DateTime Function()? agora,
  })  : _dadosRepository = dadosRepository ?? DadosMedicosRepository(),
        _agora = agora ?? DateTime.now,
        _horas = _horasValidas(registroAtual?.horasTotais),
        _qualidade = registroAtual?.qualidade;

  // O valor inicial das horas: o do registro que sera corrigido (no passo de
  // meia hora e dentro dos limites) ou, no primeiro registro, a meta minima.
  static double _horasValidas(double? horas) {
    if (horas == null) return MetaSono.horasIniciais;
    final emPassos = (horas / MetaSono.passoHoras).round() * MetaSono.passoHoras;
    return emPassos.clamp(MetaSono.horasMinimas, MetaSono.horasMaximas);
  }

  bool get editando => registroAtual != null;

  int get metaMinHoras => paciente.metaSonoMinHoras;

  int get metaMaxHoras => paciente.metaSonoMaxHoras;

  double _horas;
  double get horas => _horas;

  int? _qualidade;
  int? get qualidade => _qualidade;

  bool get podeDiminuir =>
      _horas - MetaSono.passoHoras >= MetaSono.horasMinimas;

  bool get podeAumentar =>
      _horas + MetaSono.passoHoras <= MetaSono.horasMaximas;

  // Falta escolher a nota; some quando ela e escolhida.
  String? _erroQualidade;
  String? get erroQualidade => _erroQualidade;

  // Falha ao gravar no Firestore.
  String? _mensagemErro;
  String? get mensagemErro => _mensagemErro;

  bool _salvando = false;
  bool get salvando => _salvando;

  void diminuirHoras() {
    if (!podeDiminuir) return;
    _horas -= MetaSono.passoHoras;
    notifyListeners();
  }

  void aumentarHoras() {
    if (!podeAumentar) return;
    _horas += MetaSono.passoHoras;
    notifyListeners();
  }

  void escolherQualidade(int nota) {
    _qualidade = nota;
    _erroQualidade = null;
    notifyListeners();
  }

  // Grava a noite. Retorna true se salvou. Ao corrigir, mantem o instante do
  // registro original: a noite continua no mesmo dia.
  Future<bool> salvar() async {
    if (_salvando) return false;
    _mensagemErro = null;

    final nota = _qualidade;
    if (nota == null) {
      _erroQualidade = 'Escolha como foi o seu sono.';
      notifyListeners();
      return false;
    }
    _erroQualidade = null;

    _salvando = true;
    notifyListeners();
    try {
      final atual = registroAtual;
      final instante = atual?.dataHora ?? _agora();
      final registro = RegistroSono(
        id: atual?.id ?? '',
        pacienteId: paciente.id,
        dataHora: instante,
        dataFim: instante,
        horasTotais: _horas,
        qualidade: nota,
      );
      if (atual == null) {
        await _dadosRepository.salvarRegistro(registro);
      } else {
        await _dadosRepository.atualizarRegistro(atual.id, registro);
      }
      _salvando = false;
      notifyListeners();
      return true;
    } catch (erro) {
      debugPrint('Falha ao registrar o sono: $erro');
      _mensagemErro = 'Não foi possível salvar. Tente de novo.';
      _salvando = false;
      notifyListeners();
      return false;
    }
  }
}
