import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../configuracoes/configuracoes_viewmodel.dart';

// Botao "Ouvir esta tela" (RF 08.2): le em voz alta um resumo do que a tela
// mostra. O [texto] e curado por cada tela - so os pontos principais, em frases
// curtas -, e nao a arvore de widgets: ouvir cada botao e cada rotulo, um a um,
// cansaria.
//
// Aparece so quando faz sentido:
// - o narrador esta ligado (Menu > Acessibilidade) e o aparelho tem voz;
// - nao ha leitor de tela (TalkBack) ligado. Ele ja le a tela sozinho, e as duas
//   vozes falando juntas atrapalhariam: com ele ligado, o botao some e o
//   narrador nao fala.
// Sem um ConfiguracoesViewModel acima na arvore (ex.: o painel do acompanhante)
// o botao tambem nao aparece.
//
// Enquanto a voz fala, o botao vira "Parar de ouvir". A leitura para sozinha
// quando a tela sai da frente (volta, ou outra tela abre por cima), mas so se
// foi este botao que a comecou: nao corta, por exemplo, o "Testar voz".
//
// Fica logo abaixo do titulo da tela e traz o seu proprio espaco embaixo, para
// nao deixar um buraco quando esta escondido.
class BotaoOuvirTela extends StatefulWidget {
  // O texto a ler. So e pedido quando a leitura comeca, para refletir a tela
  // naquele instante.
  final String Function() texto;
  // Comeca a ler sozinho assim que a tela abre, sem esperar o toque: para a
  // tela de emergencia, em que o aviso tem de chegar a quem nao esta olhando.
  // Segue as mesmas regras do botao: so com o narrador ligado e sem leitor de
  // tela.
  final bool falarAoAbrir;
  // Cores para a tela de emergencia, toda vermelha: o botao padrao (verde-agua)
  // sumiria no fundo.
  final bool paraFundoVermelho;

  const BotaoOuvirTela({
    super.key,
    required this.texto,
    this.falarAoAbrir = false,
    this.paraFundoVermelho = false,
  });

  @override
  State<BotaoOuvirTela> createState() => _BotaoOuvirTelaState();
}

class _BotaoOuvirTelaState extends State<BotaoOuvirTela> {
  ConfiguracoesViewModel? _narrador;
  // Foi este botao que pediu a fala em andamento.
  bool _minhaFala = false;

  @override
  void initState() {
    super.initState();
    if (widget.falarAoAbrir) {
      // Depois do primeiro quadro, quando o contexto ja enxerga o narrador.
      WidgetsBinding.instance.addPostFrameCallback((_) => _falarAoAbrir());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Sem listen: o botao avisa a si mesmo pelo `addListener` abaixo.
    final narrador =
        Provider.of<ConfiguracoesViewModel?>(context, listen: false);
    if (!identical(narrador, _narrador)) {
      _narrador?.removeListener(_aoMudarNarrador);
      _narrador = narrador;
      _narrador?.addListener(_aoMudarNarrador);
    }

    // A leitura desta tela fica para tras quando outra abre por cima ou quando
    // o leitor de tela e ligado no meio dela.
    final naFrente = ModalRoute.of(context)?.isCurrent ?? true;
    final leitorDeTelaLigado = MediaQuery.accessibleNavigationOf(context);
    if (!naFrente || leitorDeTelaLigado) _pararSeForMinha();
  }

  void _aoMudarNarrador() {
    // A voz acabou (ou foi cortada): a fala deixa de ser deste botao.
    if (!(_narrador?.falando ?? false)) _minhaFala = false;
    if (mounted) setState(() {});
  }

  void _pararSeForMinha() {
    final narrador = _narrador;
    if (!_minhaFala || narrador == null) return;
    _minhaFala = false;
    // Adiado: isto roda ate dentro do `dispose`, quando a arvore de widgets
    // esta travada, e avisar os ouvintes do ViewModel nesse momento quebraria.
    if (narrador.falando) scheduleMicrotask(narrador.pararDeOuvir);
  }

  // Le o texto da tela. Devolve falso se nao falou (narrador desligado, sem voz
  // ou a voz do sistema recusou).
  Future<bool> _ler(ConfiguracoesViewModel narrador) async {
    _minhaFala = true;
    final falou = await narrador.ouvir(widget.texto());
    if (!falou) _minhaFala = false;
    return falou;
  }

  // A tela abriu: se o narrador esta ligado, le sozinho. Se nao esta, nao e
  // falha - so nao ha nada a dizer.
  Future<void> _falarAoAbrir() async {
    final narrador = _narrador;
    if (!mounted || narrador == null || !narrador.suportado) return;
    // Com o leitor de tela ligado ele ja le a tela, e as duas vozes juntas
    // atrapalhariam.
    if (MediaQuery.accessibleNavigationOf(context)) return;
    await _ler(narrador);
  }

  Future<void> _aoTocar() async {
    final narrador = _narrador;
    if (narrador == null) return;

    // Segundo toque enquanto fala: parar.
    if (_minhaFala && narrador.falando) {
      _minhaFala = false;
      await narrador.pararDeOuvir();
      return;
    }

    if (await _ler(narrador) || !mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          narrador.mensagemErro ?? 'O celular não conseguiu falar agora.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _narrador?.removeListener(_aoMudarNarrador);
    _pararSeForMinha();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final narrador = _narrador;
    if (narrador == null ||
        !narrador.suportado ||
        !narrador.narradorLigado ||
        MediaQuery.accessibleNavigationOf(context)) {
      return const SizedBox.shrink();
    }

    final falando = _minhaFala && narrador.falando;
    final rotulo = Text(
      falando ? 'Parar de ouvir' : 'Ouvir esta tela',
      maxLines: 2,
      textAlign: TextAlign.center,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: falando
          ? FilledButton.icon(
              onPressed: _aoTocar,
              style: FilledButton.styleFrom(
                iconSize: 28,
                // No vermelho: fundo branco com texto vermelho, como o botao
                // do SAMU.
                backgroundColor: widget.paraFundoVermelho ? Colors.white : null,
                foregroundColor:
                    widget.paraFundoVermelho ? AppCores.perigo : null,
              ),
              icon: const Icon(Icons.stop_rounded),
              label: rotulo,
            )
          : OutlinedButton.icon(
              onPressed: _aoTocar,
              style: OutlinedButton.styleFrom(
                iconSize: 28,
                // No vermelho: contorno e texto brancos, como "Ver localizacao".
                foregroundColor: widget.paraFundoVermelho ? Colors.white : null,
                side: widget.paraFundoVermelho
                    ? const BorderSide(color: Colors.white, width: 2)
                    : null,
              ),
              icon: const Icon(Icons.volume_up_rounded),
              label: rotulo,
            ),
    );
  }
}
