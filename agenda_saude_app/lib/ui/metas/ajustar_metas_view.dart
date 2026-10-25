import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/meta_hidratacao.dart';
import '../../core/theme/app_cores.dart';
import '../shared/barra_acoes.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/titulo_tela.dart';
import 'formato_metas.dart';
import 'metas_viewmodel.dart';

// Ajuste manual das metas da rotina (agua, passos e exercicio) com botoes
// "-" e "+" grandes, sem digitar numero. As metas de alimentacao ficam de
// fora: dependem de orientacao do medico ou do nutricionista.
class AjustarMetasView extends StatefulWidget {
  const AjustarMetasView({super.key});

  @override
  State<AjustarMetasView> createState() => _AjustarMetasViewState();
}

class _AjustarMetasViewState extends State<AjustarMetasView> {
  late int _hidratacaoMl;
  late int _passos;
  late int _exercicioMinutos;

  @override
  void initState() {
    super.initState();
    final metas = context.read<MetasViewModel>().metas!;
    _hidratacaoMl = metas.hidratacaoMl;
    _passos = metas.passos;
    _exercicioMinutos = metas.exercicioMinutosSemana;
  }

  Future<void> _salvar() async {
    final salvou = await context.read<MetasViewModel>().salvarAjustes(
      hidratacaoMl: _hidratacaoMl,
      passos: _passos,
      exercicioMinutosSemana: _exercicioMinutos,
    );
    if (!mounted || !salvou) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MetasViewModel>();
    final limiteLiquido = viewModel.paciente.limiteLiquidoMl;
    final copos = _hidratacaoMl ~/ MetaHidratacao.mlPorCopo;

    return Scaffold(
      bottomNavigationBar: BarraAcoes(
        children: [
          if (viewModel.mensagemErro != null)
            Semantics(
              liveRegion: true,
              child: Text(
                viewModel.mensagemErro!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppCores.perigo,
                ),
              ),
            ),
          FilledButton.icon(
            onPressed: viewModel.carregando ? null : _salvar,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Salvar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: BotaoBarraSuperior.largura,
        leading: BotaoBarraSuperior.voltar(
          aoTocar: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            const TituloTela(
              'Ajustar metas',
              subtitulo: 'Mude o que precisar e toque em Salvar.',
            ),
            const SizedBox(height: 24),
            _Ajuste(
              icone: Icons.water_drop_rounded,
              titulo: 'Água',
              valor: '$copos copos',
              detalhe: limiteLiquido == null
                  ? '${formatarMilhar(_hidratacaoMl)} ml'
                  : '${formatarMilhar(_hidratacaoMl)} ml · limite do médico: '
                        '${formatarMilhar(limiteLiquido)} ml',
              rotuloDiminuir: 'Diminuir um copo de água',
              rotuloAumentar: 'Aumentar um copo de água',
              aoDiminuir:
                  _hidratacaoMl - MetaHidratacao.mlPorCopo >=
                      viewModel.hidratacaoMinimaAjusteMl
                  ? () => setState(
                      () => _hidratacaoMl -= MetaHidratacao.mlPorCopo,
                    )
                  : null,
              aoAumentar:
                  _hidratacaoMl + MetaHidratacao.mlPorCopo <=
                      viewModel.hidratacaoMaximaMl
                  ? () => setState(
                      () => _hidratacaoMl += MetaHidratacao.mlPorCopo,
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            _Ajuste(
              icone: Icons.directions_walk_rounded,
              titulo: 'Passos por dia',
              valor: formatarMilhar(_passos),
              rotuloDiminuir: 'Diminuir 500 passos',
              rotuloAumentar: 'Aumentar 500 passos',
              aoDiminuir:
                  _passos - MetasViewModel.passosPasso >=
                      MetasViewModel.passosMinimo
                  ? () => setState(() => _passos -= MetasViewModel.passosPasso)
                  : null,
              aoAumentar:
                  _passos + MetasViewModel.passosPasso <=
                      MetasViewModel.passosMaximo
                  ? () => setState(() => _passos += MetasViewModel.passosPasso)
                  : null,
            ),
            const SizedBox(height: 16),
            _Ajuste(
              icone: Icons.fitness_center_rounded,
              titulo: 'Exercício por semana',
              valor: '$_exercicioMinutos minutos',
              rotuloDiminuir: 'Diminuir 15 minutos de exercício',
              rotuloAumentar: 'Aumentar 15 minutos de exercício',
              aoDiminuir:
                  _exercicioMinutos - MetasViewModel.exercicioPassoMinutos >=
                      MetasViewModel.exercicioMinimoMinutos
                  ? () => setState(
                      () => _exercicioMinutos -=
                          MetasViewModel.exercicioPassoMinutos,
                    )
                  : null,
              aoAumentar:
                  _exercicioMinutos + MetasViewModel.exercicioPassoMinutos <=
                      MetasViewModel.exercicioMaximoMinutos
                  ? () => setState(
                      () => _exercicioMinutos +=
                          MetasViewModel.exercicioPassoMinutos,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// Linha de ajuste: titulo, valor grande no meio e "-" / "+" de 56dp nas
// pontas. Os botoes falam o que fazem ("Aumentar 500 passos") para o leitor
// de tela, e ficam desligados no limite.
class _Ajuste extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String valor;
  final String? detalhe;
  final String rotuloDiminuir;
  final String rotuloAumentar;
  final VoidCallback? aoDiminuir;
  final VoidCallback? aoAumentar;

  const _Ajuste({
    required this.icone,
    required this.titulo,
    required this.valor,
    required this.rotuloDiminuir,
    required this.rotuloAumentar,
    required this.aoDiminuir,
    required this.aoAumentar,
    this.detalhe,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icone, size: 32, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _BotaoAjuste(
                  icone: Icons.remove_rounded,
                  rotulo: rotuloDiminuir,
                  aoTocar: aoDiminuir,
                ),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    label: '$titulo: $valor',
                    child: ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            valor,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _BotaoAjuste(
                  icone: Icons.add_rounded,
                  rotulo: rotuloAumentar,
                  aoTocar: aoAumentar,
                ),
              ],
            ),
            if (detalhe != null) ...[
              const SizedBox(height: 8),
              Text(
                detalhe!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BotaoAjuste extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final VoidCallback? aoTocar;

  const _BotaoAjuste({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: aoTocar != null,
      label: rotulo,
      onTap: aoTocar,
      excludeSemantics: true,
      child: IconButton.filledTonal(
        onPressed: aoTocar,
        iconSize: 32,
        constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
        icon: Icon(icone),
      ),
    );
  }
}
