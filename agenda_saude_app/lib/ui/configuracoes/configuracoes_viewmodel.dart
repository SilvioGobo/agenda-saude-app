import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/services/tts_service.dart';
import '../../data/repositories/preferencias_repository.dart';
import '../../domain/acessibilidade/configuracao_narrador.dart';

// Configuracoes de acessibilidade (RF 07 e RF 08): liga e desliga o narrador de
// voz e escolhe a velocidade da fala. A escolha fica guardada no aparelho e vale
// para o aplicativo todo ate o paciente mudar. Ao ligar o narrador e ao trocar a
// velocidade o aparelho ja fala uma frase, para o paciente ouvir o que escolheu.
//
// Tambem e por aqui que as telas leem em voz alta o que mostram (RF 08.2, botao
// "Ouvir esta tela"): [ouvir] fala um texto curto que a propria tela escolhe, so
// com o narrador ligado, e [pararDeOuvir] corta a fala. Como a escolha vale para
// o aparelho todo, e um ViewModel so que as telas dividem.
class ConfiguracoesViewModel extends ChangeNotifier {
  static const _mensagemFalhaDeVoz = 'O celular não conseguiu falar agora. '
      'Confira se a voz do sistema está instalada.';

  final PreferenciasRepository _preferencias;
  final TtsService _tts;

  ConfiguracoesViewModel({
    PreferenciasRepository? preferencias,
    TtsService? ttsService,
  })  : _preferencias = preferencias ?? PreferenciasRepository(),
        _tts = ttsService ?? TtsServiceImpl() {
    // A voz avisa quando comeca e quando acaba de falar: assim o botao "Ouvir
    // esta tela" sabe quando voltar a dizer "Ouvir".
    _tts.definirOuvinteDaFala(_aoMudarFala);
  }

  ConfiguracaoNarrador _configuracao = const ConfiguracaoNarrador();
  // Verdadeiro ate ler a configuracao guardada e preparar a voz.
  bool _carregando = true;
  // Termina junto com `carregar`: quem pede para ouvir antes disso espera, para
  // saber se o narrador esta ligado.
  final Completer<void> _carregamento = Completer<void>();
  // null ate a verificacao; falso se o aparelho nao tem a voz em portugues.
  bool? _vozEmPortugues;
  String? _mensagemErro;
  // A voz esta falando agora (uma tela lida em voz alta, o exemplo de uma
  // velocidade ou o "Testar voz").
  bool _falando = false;
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

  // A voz esta falando agora.
  bool get falando => _falando;

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
    if (!_carregamento.isCompleted) _carregamento.complete();
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
      // Desligar cala a voz na hora, mesmo no meio de uma tela lida em voz alta.
      await pararDeOuvir();
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

  // Botao "Ouvir esta tela" (RF 08.2): le o [texto] em voz alta, na velocidade
  // que o paciente escolheu. So fala com o narrador ligado; com ele desligado a
  // tela nem mostra o botao. Devolve falso quando nao falou - o narrador esta
  // desligado, o aparelho nao tem voz ou a voz do sistema recusou (neste caso
  // [mensagemErro] explica).
  Future<bool> ouvir(String texto) async {
    if (!_tts.disponivel) return false;
    // O app acabou de abrir e a configuracao ainda esta sendo lida: espera um
    // instante para saber se o narrador esta ligado, mas sem travar para sempre.
    if (_carregando) {
      await _carregamento.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
    }
    if (_descartado || !_configuracao.ligado) return false;

    _mensagemErro = null;
    // Ja conta como falando: o botao vira "Parar" sem esperar a voz comecar.
    _falando = true;
    _avisar();
    try {
      await _tts.definirVelocidade(_configuracao.velocidade.taxa);
      await _tts.falar(texto);
      return true;
    } catch (erro) {
      debugPrint('Falha ao ler a tela em voz alta: $erro');
      _falando = false;
      _mensagemErro = _mensagemFalhaDeVoz;
      _avisar();
      return false;
    }
  }

  // Corta a fala em andamento: o botao "Parar" e a saida da tela que estava
  // sendo lida.
  Future<void> pararDeOuvir() async {
    if (_falando) {
      _falando = false;
      _avisar();
    }
    await _parar();
  }

  // O aviso da voz: comecou (true) ou terminou, foi cortada ou deu erro (false).
  void _aoMudarFala(bool falando) {
    if (_falando == falando) return;
    _falando = falando;
    _avisar();
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
      _mensagemErro = _mensagemFalhaDeVoz;
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
    // Quem fecha o painel (ex.: sair da conta) nao deixa a voz falando sozinha.
    _tts.definirOuvinteDaFala(null);
    if (_falando) unawaited(_parar());
    super.dispose();
  }
}
