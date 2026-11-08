import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

// Contrato da sintese de voz (RF 07 e RF 08). As telas do narrador dependem so
// desta interface, entao nos testes basta injetar um fake em memoria - igual ao
// NotificationService.
abstract class TtsService {
  // Falso onde nao ha voz do sistema (web, desktop): o app continua funcionando,
  // so sem narrador.
  bool get disponivel;

  // Prepara o motor de voz em portugues do Brasil. Devolve se a voz em portugues
  // esta instalada no aparelho; sem ela o sistema fala com a voz padrao dele.
  Future<bool> inicializar();

  // Muda a velocidade das proximas falas. [taxa] vai de 0 a 1, e 0,5 e a fala
  // normal.
  Future<void> definirVelocidade(double taxa);

  // Fala o [texto]. Se ja estiver falando, corta a fala anterior.
  Future<void> falar(String texto);

  // Para a fala em andamento.
  Future<void> parar();
}

// Implementacao real em cima do plugin `flutter_tts`.
class TtsServiceImpl implements TtsService {
  static const _idioma = 'pt-BR';

  final FlutterTts _tts;

  TtsServiceImpl({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  @override
  bool get disponivel =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> inicializar() async {
    if (!disponivel) return false;
    final temVozEmPortugues = await _tts.isLanguageAvailable(_idioma) == true;
    // Sem a voz em portugues, trocar o idioma faria o motor recusar a fala.
    if (temVozEmPortugues) await _tts.setLanguage(_idioma);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    return temVozEmPortugues;
  }

  @override
  Future<void> definirVelocidade(double taxa) async {
    if (!disponivel) return;
    await _tts.setSpeechRate(taxa);
  }

  @override
  Future<void> falar(String texto) async {
    if (!disponivel || texto.trim().isEmpty) return;
    // Uma fala nova substitui a anterior em vez de entrar na fila.
    await _tts.stop();
    await _tts.speak(texto);
  }

  @override
  Future<void> parar() async {
    if (!disponivel) return;
    await _tts.stop();
  }
}
