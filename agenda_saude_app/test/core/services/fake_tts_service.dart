import 'package:agenda_saude_app/core/services/tts_service.dart';

// Substituto em memoria da voz do aparelho para os testes: guarda o que seria
// falado e a velocidade pedida, sem emitir som.
class FakeTtsService implements TtsService {
  @override
  bool disponivel;
  // O que `inicializar` devolve: a voz em portugues esta instalada?
  bool vozEmPortugues;

  int inicializacoes = 0;
  int paradas = 0;
  // A ultima velocidade pedida; null ate alguem pedir.
  double? velocidade;
  final List<String> faladas = [];

  FakeTtsService({this.disponivel = true, this.vozEmPortugues = true});

  @override
  Future<bool> inicializar() async {
    inicializacoes++;
    return vozEmPortugues;
  }

  @override
  Future<void> definirVelocidade(double taxa) async {
    velocidade = taxa;
  }

  @override
  Future<void> falar(String texto) async {
    faladas.add(texto);
  }

  @override
  Future<void> parar() async {
    paradas++;
  }
}
