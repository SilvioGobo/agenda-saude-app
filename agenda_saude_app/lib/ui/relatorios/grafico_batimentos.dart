import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_cores.dart';
import '../../domain/models/alerta.dart';
import '../../domain/relatorios/serie_de_batimentos.dart';
import 'escala_do_grafico_batimentos.dart';

// Grafico de linha dos batimentos do dia (RF 04.3, Figura 17): a curva do BPM ao
// longo das 24 horas, a zona de seguranca como uma faixa verde e um marcador em
// cada alerta do dia. Sem biblioteca, como o GraficoDiario do mes.
//
// A linha liga a media de cada intervalo (10 minutos) e uma barra fina atras
// dela mostra do menor ao maior BPM do intervalo, para uma subida rapida nao
// sumir na media. Onde o relogio ficou mais de uma hora sem medir a linha para:
// o buraco aparece como buraco. Os alertas se distinguem pela FORMA, nunca so
// pela cor: circulo vermelho = emergencia, losango laranja = atencao. A legenda
// explica tudo e a [descricao] resume o grafico em frases para o leitor de tela.
class GraficoBatimentos extends StatelessWidget {
  static const double altura = 200;

  final SerieDeBatimentos serie;
  final int zonaMinima;
  final int zonaMaxima;
  // Os alertas do dia; cada um vira um marcador na hora em que aconteceu.
  final List<Alerta> alertas;
  final String descricao;

  const GraficoBatimentos({
    super.key,
    required this.serie,
    required this.zonaMinima,
    required this.zonaMaxima,
    required this.alertas,
    required this.descricao,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textScaler = MediaQuery.textScalerOf(context);
    // Os numeros dos eixos crescem com a fonte do celular; a area do desenho
    // cresce junto (os dois eixos pedem espaco), para a curva nao ser espremida.
    final crescimentoDoTexto = textScaler.scale(16) - 16;
    final temEmergencia = alertas.any((alerta) => alerta.ehEmergencia);
    final temAtencao = alertas.any((alerta) => !alerta.ehEmergencia);
    // A fonte do tema (a mesma dos outros textos), a 16 - o minimo do guia visual.
    final estiloDoTexto = Theme.of(context).textTheme.bodyLarge!.copyWith(
          fontSize: 16,
          height: 1.2,
          color: colorScheme.onSurfaceVariant,
        );

    return Semantics(
      container: true,
      image: true,
      label: descricao,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: altura + crescimentoDoTexto * 4,
              child: CustomPaint(
                size: Size.infinite,
                painter: _PintorDoGrafico(
                  serie: serie,
                  zonaMinima: zonaMinima,
                  zonaMaxima: zonaMaxima,
                  alertas: alertas,
                  textScaler: textScaler,
                  estiloDoTexto: estiloDoTexto,
                  corDaCurva: colorScheme.primary,
                  corDaGrade: colorScheme.outlineVariant,
                  corDoEixo: colorScheme.outline,
                  corDoFundo: colorScheme.surfaceContainerLow,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _ItemDeLegenda(
                  marca: Container(
                    width: 24,
                    height: 3,
                    color: colorScheme.primary,
                  ),
                  rotulo: 'Média a cada ${serie.intervaloMinutos} minutos',
                ),
                _ItemDeLegenda(
                  marca: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppCores.sucessoContainer,
                      border: Border.all(color: AppCores.sucesso),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  rotulo: 'Zona de segurança ($zonaMinima a $zonaMaxima BPM)',
                ),
                if (temEmergencia)
                  _ItemDeLegenda(
                    marca: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: AppCores.perigo,
                        shape: BoxShape.circle,
                      ),
                    ),
                    rotulo: 'Alerta de emergência',
                  ),
                if (temAtencao)
                  _ItemDeLegenda(
                    marca: Transform.rotate(
                      angle: math.pi / 4,
                      child: Container(
                        width: 12,
                        height: 12,
                        color: AppCores.aviso,
                      ),
                    ),
                    rotulo: 'Alerta de atenção',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Uma entrada da legenda: a marca (traco, quadrado, circulo ou losango) e o texto.
class _ItemDeLegenda extends StatelessWidget {
  final Widget marca;
  final String rotulo;

  const _ItemDeLegenda({required this.marca, required this.rotulo});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Uma caixa de tamanho fixo para os losangos girados nao invadirem o texto.
        SizedBox(width: 24, height: 24, child: Center(child: marca)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            rotulo,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _PintorDoGrafico extends CustomPainter {
  // As marcas de hora do eixo horizontal, de 6 em 6 horas; quando o texto grande
  // do celular nao deixa espaco, so 0h, 12h e 24h levam o numero.
  static const List<int> horasDoEixo = [0, 6, 12, 18, 24];

  final SerieDeBatimentos serie;
  final int zonaMinima;
  final int zonaMaxima;
  final List<Alerta> alertas;
  final TextScaler textScaler;
  final TextStyle estiloDoTexto;
  final Color corDaCurva;
  final Color corDaGrade;
  final Color corDoEixo;
  final Color corDoFundo;

  const _PintorDoGrafico({
    required this.serie,
    required this.zonaMinima,
    required this.zonaMaxima,
    required this.alertas,
    required this.textScaler,
    required this.estiloDoTexto,
    required this.corDaCurva,
    required this.corDaGrade,
    required this.corDoEixo,
    required this.corDoFundo,
  });

  TextPainter _texto(String texto) {
    return TextPainter(
      text: TextSpan(text: texto, style: estiloDoTexto),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final menor = serie.minimo;
    final maior = serie.maximo;
    if (menor == null || maior == null) return;

    // O eixo cabe a curva, a zona e os alertas que tem BPM.
    var menorBpm = menor;
    var maiorBpm = maior;
    for (final alerta in alertas) {
      final bpm = alerta.bpm;
      if (bpm == null) continue;
      menorBpm = math.min(menorBpm, bpm);
      maiorBpm = math.max(maiorBpm, bpm);
    }
    final eixo = EscalaDoGraficoBatimentos.eixoVertical(
      menorBpm: menorBpm,
      maiorBpm: maiorBpm,
      zonaMinima: zonaMinima,
      zonaMaxima: zonaMaxima,
    );

    final rotulosDoEixo = {
      for (final marca in eixo.marcas) marca: _texto('$marca'),
    };
    final rotulosDasHoras = {
      for (final hora in horasDoEixo) hora: _texto('${hora}h'),
    };

    // Reserva o lado esquerdo para os numeros do BPM e a base para as horas.
    final larguraDosNumeros = rotulosDoEixo.values
            .map((rotulo) => rotulo.width)
            .reduce(math.max) +
        8;
    final alturaDosNumeros = rotulosDoEixo.values.first.height;
    final alturaDasHoras = rotulosDasHoras.values.first.height;
    final area = Rect.fromLTRB(
      larguraDosNumeros,
      alturaDosNumeros / 2,
      // O "24h" passa um pouco da borda direita da area.
      size.width - rotulosDasHoras[24]!.width / 2,
      size.height - alturaDasHoras - 6,
    );
    if (area.width <= 0 || area.height <= 0) return;

    // Com a fonte do celular grande nem todo numero cabe: escreve um sim, outro
    // nao, sempre mantendo os limites da zona de seguranca.
    final numerosDoEixo = EscalaDoGraficoBatimentos.marcasComNumero(
      marcas: eixo.marcas,
      zonaMinima: zonaMinima,
      salto: EscalaDoGraficoBatimentos.saltoDosNumeros(
        alturaDoNumero: alturaDosNumeros,
        espacoEntreMarcas: area.height / (eixo.marcas.length - 1),
      ),
    ).toSet();
    final horasEscritas = EscalaDoGraficoBatimentos.horasComNumero(
      larguraDoMaiorRotulo:
          rotulosDasHoras.values.map((rotulo) => rotulo.width).reduce(math.max),
      espacoEntreHoras: area.width / 4,
    ).toSet();

    final escala = EscalaDoGraficoBatimentos(
      inicio: serie.inicio,
      fim: serie.fim,
      largura: area.width,
      altura: area.height,
      bpmMinimo: eixo.minimo,
      bpmMaximo: eixo.maximo,
    );
    Offset ponto(DateTime momento, num bpm) =>
        Offset(area.left + escala.x(momento), area.top + escala.y(bpm));

    // 1. A zona de seguranca: uma faixa verde clara de lado a lado.
    canvas.drawRect(
      Rect.fromLTRB(
        area.left,
        area.top + escala.y(zonaMaxima),
        area.right,
        area.top + escala.y(zonaMinima),
      ),
      Paint()..color = AppCores.sucessoContainer,
    );

    // 2. A grade e os numeros do BPM.
    final grade = Paint()
      ..color = corDaGrade
      ..strokeWidth = 1;
    for (final marca in eixo.marcas) {
      final y = area.top + escala.y(marca);
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), grade);
      if (!numerosDoEixo.contains(marca)) continue;
      final rotulo = rotulosDoEixo[marca]!;
      rotulo.paint(
        canvas,
        Offset(larguraDosNumeros - 8 - rotulo.width, y - rotulo.height / 2),
      );
    }

    // 3. O eixo de baixo e as horas.
    canvas.drawLine(
      area.bottomLeft,
      area.bottomRight,
      Paint()
        ..color = corDoEixo
        ..strokeWidth = 2,
    );
    for (final hora in horasEscritas) {
      final rotulo = rotulosDasHoras[hora]!;
      final x = area.left + area.width * hora / 24;
      rotulo.paint(
        canvas,
        Offset(x - rotulo.width / 2, area.bottom + 6),
      );
    }

    // 4. A faixa do menor ao maior BPM de cada intervalo, atras da linha.
    final faixa = Paint()
      ..color = corDaCurva.withValues(alpha: 0.28)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final p in serie.pontos) {
      if (p.minimo == p.maximo) continue;
      canvas.drawLine(ponto(p.meio, p.maximo), ponto(p.meio, p.minimo), faixa);
    }

    // 5. A linha da media, um trecho por vez; ponto isolado vira um pingo.
    final linha = Paint()
      ..color = corDaCurva
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final pingo = Paint()..color = corDaCurva;
    for (final trecho in serie.trechos()) {
      if (trecho.length == 1) {
        canvas.drawCircle(ponto(trecho.first.meio, trecho.first.media), 4, pingo);
        continue;
      }
      final caminho = Path();
      for (var i = 0; i < trecho.length; i++) {
        final p = ponto(trecho[i].meio, trecho[i].media);
        i == 0 ? caminho.moveTo(p.dx, p.dy) : caminho.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(caminho, linha);
    }

    // 6. Os alertas por cima de tudo, as emergencias por ultimo.
    final ordenados = [...alertas]
      ..sort((a, b) => (a.ehEmergencia ? 1 : 0) - (b.ehEmergencia ? 1 : 0));
    for (final alerta in ordenados) {
      // Alerta sem BPM guardado vai para o alto do grafico, onde se enxerga.
      final centro = alerta.bpm == null
          ? Offset(area.left + escala.x(alerta.dataHora), area.top + 10)
          : ponto(alerta.dataHora, alerta.bpm!);
      if (alerta.ehEmergencia) {
        canvas.drawCircle(centro, 11, Paint()..color = corDoFundo);
        canvas.drawCircle(centro, 8.5, Paint()..color = AppCores.perigo);
      } else {
        canvas.drawPath(_losango(centro, 12), Paint()..color = corDoFundo);
        canvas.drawPath(_losango(centro, 9.5), Paint()..color = AppCores.aviso);
      }
    }
  }

  // Um losango (quadrado girado) com [raio] do centro as pontas.
  Path _losango(Offset centro, double raio) {
    return Path()
      ..moveTo(centro.dx, centro.dy - raio)
      ..lineTo(centro.dx + raio, centro.dy)
      ..lineTo(centro.dx, centro.dy + raio)
      ..lineTo(centro.dx - raio, centro.dy)
      ..close();
  }

  @override
  bool shouldRepaint(_PintorDoGrafico anterior) {
    return anterior.serie != serie ||
        anterior.zonaMinima != zonaMinima ||
        anterior.zonaMaxima != zonaMaxima ||
        anterior.alertas != alertas ||
        anterior.textScaler != textScaler ||
        anterior.estiloDoTexto != estiloDoTexto ||
        anterior.corDaCurva != corDaCurva ||
        anterior.corDaGrade != corDaGrade ||
        anterior.corDoEixo != corDoEixo ||
        anterior.corDoFundo != corDoFundo;
  }
}
