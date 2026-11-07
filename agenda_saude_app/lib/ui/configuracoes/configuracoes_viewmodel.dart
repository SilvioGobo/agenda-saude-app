import 'package:flutter/foundation.dart';

import '../../core/services/tts_service.dart';
import '../../data/repositories/preferencias_repository.dart';
import '../../domain/acessibilidade/configuracao_narrador.dart';

// Configuracoes de acessibilidade (RF 07 e RF 08): liga e desliga o narrador de
// voz e escolhe a velocidade da fala. A escolha fica guardada no aparelho e vale
// para o aplicativo todo ate o paciente mudar. Ao ligar o narrador e ao trocar a
// velocidade o aparelho ja fala uma frase, para o paciente ouvir o que escolheu.
class ConfiguracoesViewModel extends ChangeNotifier {
  final PreferenciasRepository _preferencias;
  final TtsService _tts;

  ConfiguracoesViewModel({
    PreferenciasRepository? preferencias,
    TtsService? ttsService,
  })  : _preferencias = preferencias ?? PreferenciasRepository(),
        _tts = ttsService ?? TtsServiceImpl();

  ConfiguracaoNarrador _configuracao = const ConfiguracaoNarrador();
  // Verdadeiro ate ler a configuracao guardada e preparar a voz.
  bool _carregando = true;
  // null ate a verificacao; falso se o aparelho nao tem a voz em portugues.
  bool? _vozEmPortugues;
  String? _mensagemErro;
  bool _descartado = false;

  // Falso nos aparelhos sem voz do sistema (web, desktop).
  bool get suportado => _tts.disponivel;

  bool get carregando => _carregando;

  bool get narradorLigado => _configuracao.ligado;

  VelocidadeNarracao get velocidade => _configuracao.velocidade;

  // O aparelho nao tem a voz em portugues: o narrador fala com a voz padrao.
  bool get faltaVozEmPortugues => _vozEmPortugues == false;

  // Falha ao guardar a escolha ou ao falar; some na proxima tentativa.
  String? get mensagemErro => _mensagemErro;

  // Le a configuracao guardada e deixa a voz pronta, na velocidade escolhida.
  Future<void> carregar() async {
    try {
      _configuracao = await _preferencias.narrador();
    } catch (erro) {
      // Sem a leitura, o narrador fica no padrao (desligado, velocidade normal).
      debugPrint('Falha ao ler a configuracao do narrador: $erro');
    }

    if (_tts.disponivel) {
      try {
        _vozEmPortugues = await _tts.inicializar();
        await _tts.definirVelocidade(_configuracao.velocidade.taxa);
      } catch (erro) {
        debugPrint('Falha ao preparar a voz: $erro');
      }
    }

    _carregando = false;
    _avisar();
  }

  Future<void> alternarNarrador(bool ligado) async {
    if (_configuracao.ligado == ligado) return;
    final anterior = _configuracao;
    _configuracao = anterior.copyWith(ligado: ligado);
    _mensagemErro = null;
    _avisar();

    try {
      await _preferencias.salvarNarradorLigado(ligado);
    } catch (erro) {
      debugPrint('Falha ao guardar se o narrador esta ligado: $erro');
      _configuracao = anterior;
      _mensagemErro = 'Não foi possível guardar. Tente de novo.';
      _avisar();
      return;
    }

    if (ligado) {
      await _falar('Narrador ligado.');
    } else {
      await _parar();
    }
  }

  Future<void> escolherVelocidade(VelocidadeNarracao nova) async {
    final anterior = _configuracao;
    _configuracao = anterior.copyWith(velocidade: nova);
    _mensagemErro = null;
    _avisar();

    try {
      await _preferencias.salvarVelocidadeDoNarrador(nova);
      if (_tts.disponivel) await _tts.definirVelocidade(nova.taxa);
    } catch (erro) {
      debugPrint('Falha ao guardar a velocidade do narrador: $erro');
      _configuracao = anterior;
      _mensagemErro = 'Não foi possível guardar. Tente de novo.';
      _avisar();
      return;
    }

    await _falar(_exemploDe(nova));
  }

  // Botao "Testar voz": fala uma frase na velocidade escolhida.
  Future<void> testarVoz() {
    _mensagemErro = null;
    return _falar(
      'Olá! Eu sou o narrador do Agenda Saúde. É assim que vou ler os '
      'textos para você.',
    );
  }

  static String _exemploDe(VelocidadeNarracao velocidade) {
    switch (velocidade) {
      case VelocidadeNarracao.devagar:
        return 'Estou falando devagar.';
      case VelocidadeNarracao.normal:
        return 'Estou falando na velocidade normal.';
      case VelocidadeNarracao.rapido:
        return 'Estou falando rápido.';
    }
  }

  Future<void> _falar(String texto) async {
    if (!_tts.disponivel) return;
    try {
      await _tts.falar(texto);
    } catch (erro) {
      debugPrint('Falha ao falar: $erro');
      _mensagemErro = 'O celular não conseguiu falar agora. Confira se a voz '
          'do sistema está instalada.';
      _avisar();
    }
  }

  Future<void> _parar() async {
    if (!_tts.disponivel) return;
    try {
      await _tts.parar();
    } catch (erro) {
      debugPrint('Falha ao parar a voz: $erro');
    }
  }

  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
