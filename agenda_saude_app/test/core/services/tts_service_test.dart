import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/services/tts_service.dart';

// Testa a implementacao real da voz sem aparelho: o plugin conversa com o
// Android por um canal, e aqui o canal e trocado por um que anota as chamadas.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TtsServiceImpl Testes', () {
    const canal = MethodChannel('flutter_tts');
    late List<MethodCall> chamadas;
    late bool vozEmPortugues;
    late TtsServiceImpl servico;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      chamadas = [];
      vozEmPortugues = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(canal, (chamada) async {
        chamadas.add(chamada);
        if (chamada.method == 'isLanguageAvailable') return vozEmPortugues;
        return 1;
      });
      servico = TtsServiceImpl();
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(canal, null);
    });

    List<String> metodos() => chamadas.map((c) => c.method).toList();

    // No Android o plugin manda {text, focus}; nas demais so o texto.
    String? textoFalado(MethodCall chamada) {
      final argumentos = chamada.arguments;
      return argumentos is Map ? argumentos['text'] as String? : argumentos as String?;
    }

    test('Deve usar a voz em português quando o aparelho a tem', () async {
      final temVoz = await servico.inicializar();

      expect(temVoz, isTrue);
      final idioma = chamadas.firstWhere((c) => c.method == 'setLanguage');
      expect(idioma.arguments, 'pt-BR');
    });

    test('Deve avisar que falta a voz em português, sem trocar o idioma', () async {
      vozEmPortugues = false;

      final temVoz = await servico.inicializar();

      expect(temVoz, isFalse);
      expect(metodos(), isNot(contains('setLanguage')));
    });

    test('Deve deixar a voz no volume máximo', () async {
      await servico.inicializar();

      final volume = chamadas.firstWhere((c) => c.method == 'setVolume');
      expect(volume.arguments, 1.0);
    });

    test('Deve passar a velocidade ao plugin', () async {
      await servico.definirVelocidade(0.35);

      final velocidade = chamadas.singleWhere((c) => c.method == 'setSpeechRate');
      expect(velocidade.arguments, 0.35);
    });

    test('Deve cortar a fala anterior antes de falar a nova', () async {
      await servico.falar('Olá');

      expect(metodos(), ['stop', 'speak']);
      expect(textoFalado(chamadas.last), 'Olá');
    });

    test('Não deve falar um texto vazio', () async {
      await servico.falar('   ');

      expect(chamadas, isEmpty);
    });

    test('Deve parar a fala', () async {
      await servico.parar();

      expect(metodos(), ['stop']);
    });

    test('Não deve fazer nada em plataforma sem voz do sistema', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      expect(servico.disponivel, isFalse);
      expect(await servico.inicializar(), isFalse);
      await servico.definirVelocidade(0.5);
      await servico.falar('Olá');
      await servico.parar();

      expect(chamadas, isEmpty);
    });
  });
}
