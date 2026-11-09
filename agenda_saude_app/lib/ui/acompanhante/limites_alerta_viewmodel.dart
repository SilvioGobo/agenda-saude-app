import 'package:flutter/foundation.dart';

import '../../core/constants/zona_seguranca_cardiaca.dart';
import '../../data/repositories/dados_repository.dart';
import '../../domain/models/limites_alerta.dart';
import '../../domain/models/paciente.dart';

// Tela "Limites de alerta" do acompanhante (RF 06.1): o minimo e o maximo de
// BPM do paciente, ajustados com os botoes Menos/Mais, de [passo] em [passo],
// sempre dentro das faixas de LimitesAlerta. Salvar grava no doc do paciente,
// onde a leitura do BPM (app aberto e fechado), o painel e o card passam a
// usar os limites novos. Os mesmos valores da zona padrao viram "sem limites"
// (o campo sai do doc), para o paciente acompanhar a zona da triagem.
class LimitesAlertaViewModel extends ChangeNotifier {
  // De quanto em quanto os botoes mudam o valor.
  static const int passo = 5;

  final Paciente paciente;
  // Quem esta ajustando; vai em `atualizadoPor`, que as rules conferem.
  final String acompanhanteId;
  final DadosMedicosRepository _dadosRepository;
  final DateTime Function() _agora;

  // Os limites que valiam ao abrir a tela; null = zona padrao.
  final LimitesAlerta? limitesAtuais;

  late int _bpmMinimo;
  late int _bpmMaximo;

  LimitesAlertaViewModel({
    required this.paciente,
    required this.acompanhanteId,
    this.limitesAtuais,
    DadosMedicosRepository? dadosRepository,
    DateTime Function()? agora,
  })  : _dadosRepository = dadosRepository ?? DadosMedicosRepository(),
        _agora = agora ?? DateTime.now {
    _bpmMinimo = ZonaSegurancaCardiaca.bpmMinimo(
      possuiCardiopatia: paciente.possuiCardiopatia,
      limites: limitesAtuais,
    );
    _bpmMaximo = ZonaSegurancaCardiaca.bpmMaximo(
      possuiCardiopatia: paciente.possuiCardiopatia,
      limites: limitesAtuais,
    );
  }

  int get bpmMinimo => _bpmMinimo;
  int get bpmMaximo => _bpmMaximo;

  // A zona que vale sem limites definidos (pela triagem do paciente).
  int get padraoMinimo => ZonaSegurancaCardiaca.bpmMinimo(
        possuiCardiopatia: paciente.possuiCardiopatia,
      );

  int get padraoMaximo => ZonaSegurancaCardiaca.bpmMaximo(
        possuiCardiopatia: paciente.possuiCardiopatia,
      );

  bool get ehPadrao =>
      _bpmMinimo == padraoMinimo && _bpmMaximo == padraoMaximo;

  String get primeiroNome {
    final nome = paciente.nome.trim();
    return nome.isEmpty ? 'o paciente' : nome.split(RegExp(r'\s+')).first;
  }

  bool get podeDiminuirMinimo => _cabe(_bpmMinimo - passo, _bpmMaximo);
  bool get podeAumentarMinimo => _cabe(_bpmMinimo + passo, _bpmMaximo);
  bool get podeDiminuirMaximo => _cabe(_bpmMinimo, _bpmMaximo - passo);
  bool get podeAumentarMaximo => _cabe(_bpmMinimo, _bpmMaximo + passo);

  bool _cabe(int minimo, int maximo) => LimitesAlerta.saoValidos(minimo, maximo);

  bool _salvando = false;
  bool get salvando => _salvando;

  String? _mensagemErro;
  String? get mensagemErro => _mensagemErro;

  // O que foi gravado no ultimo [salvar] que deu certo; null = zona padrao.
  LimitesAlerta? _limitesSalvos;
  LimitesAlerta? get limitesSalvos => _limitesSalvos;

  void diminuirMinimo() => _mudar(_bpmMinimo - passo, _bpmMaximo);
  void aumentarMinimo() => _mudar(_bpmMinimo + passo, _bpmMaximo);
  void diminuirMaximo() => _mudar(_bpmMinimo, _bpmMaximo - passo);
  void aumentarMaximo() => _mudar(_bpmMinimo, _bpmMaximo + passo);

  void voltarAoPadrao() => _mudar(padraoMinimo, padraoMaximo);

  void _mudar(int minimo, int maximo) {
    if (_salvando || !_cabe(minimo, maximo)) return;
    _bpmMinimo = minimo;
    _bpmMaximo = maximo;
    _mensagemErro = null;
    notifyListeners();
  }

  Future<bool> salvar() async {
    if (_salvando) return false;
    _salvando = true;
    _mensagemErro = null;
    notifyListeners();

    final limites = ehPadrao
        ? null
        : LimitesAlerta(
            bpmMinimo: _bpmMinimo,
            bpmMaximo: _bpmMaximo,
            atualizadoPor: acompanhanteId,
            atualizadoEm: _agora(),
          );
    try {
      await _dadosRepository.salvarLimitesAlerta(paciente.id, limites);
      _limitesSalvos = limites;
      _salvando = false;
      notifyListeners();
      return true;
    } catch (erro) {
      debugPrint('Falha ao salvar os limites de alerta: $erro');
      _mensagemErro = 'Não foi possível salvar os limites. Tente novamente.';
      _salvando = false;
      notifyListeners();
      return false;
    }
  }
}
