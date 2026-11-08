import 'dart:math' as math;

// As contas do grafico de BPM do relatorio do dia (RF 04.3, Figura 17): onde cai
// cada horario e cada BPM na area do desenho. Ficam separadas do desenho para
// poderem ser testadas sem tela.
class EscalaDoGraficoBatimentos {
  // Os BPM do eixo vertical sao multiplos de 20: legiveis, e a zona de seguranca
  // (60 a 100, ou 60 a 90) cai em cima de duas marcas.
  static const int passoDoEixo = 20;

  // Folga entre a leitura mais extrema e a borda do grafico, em BPM.
  static const int folgaDoEixo = 10;

  // O dia do grafico: do comeco ao fim.
  final DateTime inicio;
  final DateTime fim;
  // O tamanho da area de desenho, em pixels logicos.
  final double largura;
  final double altura;
  // O BPM da base e o do topo da area.
  final int bpmMinimo;
  final int bpmMaximo;

  const EscalaDoGraficoBatimentos({
    required this.inicio,
    required this.fim,
    required this.largura,
    required this.altura,
    required this.bpmMinimo,
    required this.bpmMaximo,
  });

  // A posicao horizontal de um horario: 0 no comeco do dia e [largura] no fim.
  // Um horario fora do dia fica preso na borda mais proxima.
  double x(DateTime momento) {
    final total = fim.difference(inicio).inMicroseconds;
    if (total <= 0) return 0;
    final passado = momento.difference(inicio).inMicroseconds;
    return (passado / total).clamp(0.0, 1.0) * largura;
  }

  // A posicao vertical de um BPM, como no canvas: 0 no topo e [altura] na base.
  // Um BPM fora do eixo fica preso na borda.
  double y(num bpm) {
    final faixa = bpmMaximo - bpmMinimo;
    if (faixa <= 0) return altura;
    final fracao = ((bpm - bpmMinimo) / faixa).clamp(0.0, 1.0);
    return altura * (1 - fracao);
  }

  // De quantas em quantas marcas do eixo vertical se escreve o numero: 1 quando
  // cabe um embaixo do outro, mais quando a fonte grande do celular faria os
  // numeros se encostarem. [espacoEntreMarcas] e a distancia entre duas marcas.
  static int saltoDosNumeros({
    required double alturaDoNumero,
    required double espacoEntreMarcas,
  }) {
    if (espacoEntreMarcas <= 0) return 1;
    // 4 pixels de respiro entre um numero e o seguinte.
    return math.max(1, ((alturaDoNumero + 4) / espacoEntreMarcas).ceil());
  }

  // As marcas que levam numero quando se escreve uma a cada [salto]. A conta
  // parte da zona de seguranca: os limites dela ficam sempre rotulados (com
  // 40, 60, 80, 100, 120 e 140 e salto 2 saem 60, 100 e 140).
  static List<int> marcasComNumero({
    required List<int> marcas,
    required int zonaMinima,
    required int salto,
  }) {
    final ancora = marcas.indexWhere((marca) => marca >= zonaMinima);
    final partida = ancora < 0 ? 0 : ancora;
    return [
      for (var i = 0; i < marcas.length; i++)
        if ((i - partida) % salto == 0) marcas[i],
    ];
  }

  // As horas escritas sob o eixo horizontal: de 6 em 6 horas quando cabem, e so
  // 0h, 12h e 24h quando o numero maior ([larguraDoMaiorRotulo]) encostaria no
  // vizinho ([espacoEntreHoras] e a distancia entre duas marcas de 6 horas).
  static List<int> horasComNumero({
    required double larguraDoMaiorRotulo,
    required double espacoEntreHoras,
  }) {
    // 6 pixels de respiro entre um rotulo e o seguinte.
    return larguraDoMaiorRotulo + 6 <= espacoEntreHoras
        ? const [0, 6, 12, 18, 24]
        : const [0, 12, 24];
  }

  // O eixo vertical em que cabem as leituras ([menorBpm] a [maiorBpm]) e a zona
  // de seguranca, com folga, em multiplos de [passoDoEixo]; mais as marcas, uma
  // a cada [passoDoEixo] da base ao topo.
  static ({int minimo, int maximo, List<int> marcas}) eixoVertical({
    required int menorBpm,
    required int maiorBpm,
    required int zonaMinima,
    required int zonaMaxima,
  }) {
    final base = math.min(menorBpm, zonaMinima) - folgaDoEixo;
    final topo = math.max(maiorBpm, zonaMaxima) + folgaDoEixo;
    // O BPM nao passa de zero para baixo.
    final minimo = math.max(0, (base / passoDoEixo).floor() * passoDoEixo);
    final maximo = (topo / passoDoEixo).ceil() * passoDoEixo;
    return (
      minimo: minimo,
      maximo: maximo,
      marcas: [for (var bpm = minimo; bpm <= maximo; bpm += passoDoEixo) bpm],
    );
  }
}
