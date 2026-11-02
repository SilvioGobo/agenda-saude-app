import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/faixas_glicemia.dart';
import '../../core/constants/momentos_glicemia.dart';
import '../../core/theme/app_cores.dart';
import '../../domain/models/alerta.dart';
import '../../domain/models/registro_diabete.dart';
import '../../domain/relatorios/resumo_do_dia.dart';
import '../insulina/formatacao_diabete.dart';
import '../rotina/resumo_nutricional.dart';
import '../shared/caixa_alerta.dart';
import '../shared/card_status.dart';
import 'cartao_relatorio.dart';
import 'estado_relatorio.dart';
import 'formato_relatorios.dart';
import 'relatorio_dia_viewmodel.dart';

// O relatorio de um dia da rotina (RF05), igual para o paciente e para o
// acompanhante: como o dia fechou, o que pede atencao e um cartao para cada
// parte da rotina - hidratacao, refeicoes, glicemia e insulina (so para
// diabeticos) e batimentos. Os textos falam do dia sem dizer "voce" nem o
// nome, para servirem aos dois. Precisa de um [RelatorioDiaViewModel] acima na
// arvore.
class RelatorioDiaConteudo extends StatelessWidget {
  const RelatorioDiaConteudo({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RelatorioDiaViewModel>();

    switch (viewModel.estado) {
      case EstadoRelatorio.carregando:
        return const CarregandoRelatorio();
      case EstadoRelatorio.erro:
        return ErroDeRelatorio(aoTentarDeNovo: viewModel.carregar);
      case EstadoRelatorio.pronto:
        return _RelatorioPronto(
          viewModel: viewModel,
          resumo: viewModel.resumo!,
        );
    }
  }
}

class _RelatorioPronto extends StatelessWidget {
  final RelatorioDiaViewModel viewModel;
  final ResumoDoDia resumo;

  const _RelatorioPronto({required this.viewModel, required this.resumo});

  @override
  Widget build(BuildContext context) {
    final pontos = _pontosDeAtencao(resumo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SituacaoGeral(resumo: resumo),
        if (pontos.isNotEmpty) ...[
          const SizedBox(height: 16),
          CaixaAlerta(
            titulo: 'PONTOS DE ATENÇÃO',
            mensagem: pontos.map((ponto) => '• $ponto').join('\n'),
          ),
        ],
        const SizedBox(height: 16),
        _CartaoHidratacao(hidratacao: resumo.hidratacao),
        const SizedBox(height: 16),
        _CartaoRefeicoes(viewModel: viewModel, refeicoes: resumo.refeicoes),
        if (resumo.diabetes != null) ...[
          const SizedBox(height: 16),
          _CartaoGlicemia(diabetes: resumo.diabetes!),
        ],
        const SizedBox(height: 16),
        _CartaoBatimentos(resumo: resumo),
      ],
    );
  }
}

// O que o acompanhante precisa ver primeiro: emergencia de batimentos,
// hipoglicemia e glicemia muito alta - as mesmas coisas que o app pinta de
// vermelho. Avisos menores ficam nos cartoes.
List<String> _pontosDeAtencao(ResumoDoDia resumo) {
  final pontos = <String>[];

  // Os alertas vem do mais recente para o mais antigo.
  final emergencias =
      resumo.alertas.where((alerta) => alerta.ehEmergencia).toList();
  if (emergencias.length == 1) {
    final alerta = emergencias.single;
    final bpm = alerta.bpm == null ? '' : ' (${alerta.bpm} BPM)';
    pontos.add(
      'Alerta de emergência nos batimentos às '
      '${formatarHora(alerta.dataHora)}$bpm.',
    );
  } else if (emergencias.length > 1) {
    pontos.add(
      '${emergencias.length} alertas de emergência nos batimentos. O último '
      'foi às ${formatarHora(emergencias.first.dataHora)}.',
    );
  }

  final glicemia = resumo.diabetes?.glicemia;
  if (glicemia != null) {
    if (glicemia.baixas > 0) {
      pontos.add(
        'Glicemia baixa ${descreverVezes(glicemia.baixas)}: a menor foi '
        '${formatarGlicemia(glicemia.menor!)}.',
      );
    }
    if (glicemia.muitoAltas > 0) {
      pontos.add(
        'Glicemia muito alta ${descreverVezes(glicemia.muitoAltas)}: a maior '
        'foi ${formatarGlicemia(glicemia.maior!)}.',
      );
    }
  }
  return pontos;
}

// Selo do dia ("ROTINA COMPLETA") e uma linha dizendo o que foi cumprido e o
// que faltou.
class _SituacaoGeral extends StatelessWidget {
  final ResumoDoDia resumo;

  const _SituacaoGeral({required this.resumo});

  String get _detalhe {
    final itens = [
      ('meta de água', resumo.hidratacao.metaAtingida),
      if (resumo.refeicoes.total > 0)
        ('refeições', resumo.refeicoes.todasFeitas),
      if (resumo.diabetes != null) ('glicemia', resumo.diabetes!.completo),
    ];
    final cumpridos = [
      for (final (nome, cumprido) in itens)
        if (cumprido) nome,
    ];
    final faltaram = [
      for (final (nome, cumprido) in itens)
        if (!cumprido) nome,
    ];

    switch (resumo.situacao) {
      case SituacaoDoDia.completo:
        return 'Tudo cumprido: ${juntarComE(cumpridos)}.';
      case SituacaoDoDia.parcial:
        return cumpridos.isEmpty
            ? 'Faltou: ${juntarComE(faltaram)}.'
            : 'Cumprido: ${juntarComE(cumpridos)}. '
                'Faltou: ${juntarComE(faltaram)}.';
      case SituacaoDoDia.semRegistro:
        return 'Nada da rotina foi anotado neste dia.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (rotulo, icone, cor) = switch (resumo.situacao) {
      SituacaoDoDia.completo => (
          'ROTINA COMPLETA',
          Icons.check_circle_rounded,
          AppCores.sucesso,
        ),
      SituacaoDoDia.parcial => (
          'ROTINA PARCIAL',
          Icons.incomplete_circle_rounded,
          AppCores.aviso,
        ),
      SituacaoDoDia.semRegistro => (
          'SEM REGISTROS',
          Icons.remove_circle_outline_rounded,
          AppCores.aviso,
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardStatus(rotulo: rotulo, icone: icone, cor: cor),
        const SizedBox(height: 8),
        Text(
          _detalhe,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            height: 1.35,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CartaoHidratacao extends StatelessWidget {
  final HidratacaoDoDia hidratacao;

  const _CartaoHidratacao({required this.hidratacao});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final h = hidratacao;

    return CartaoRelatorio(
      icone: Icons.water_drop_rounded,
      titulo: 'Hidratação',
      resumo: h.registrou
          ? '${formatarMl(h.totalMl)} de ${formatarMl(h.metaMl)}'
          : 'Nenhuma água anotada',
      filhos: [
        if (h.registrou) ...[
          BarraDeProgresso(valor: h.progresso, completa: h.metaAtingida),
          Text(
            '${h.copos} de ${h.metaCopos} copos',
            style: TextStyle(fontSize: 18, color: colorScheme.onSurfaceVariant),
          ),
        ],
        if (h.metaAtingida)
          const CardStatus(
            rotulo: 'META ATINGIDA',
            icone: Icons.check_circle_rounded,
            cor: AppCores.sucesso,
          )
        else if (h.registrou)
          LinhaDoRelatorio(
            icone: Icons.info_rounded,
            cor: AppCores.aviso,
            texto: 'Faltaram ${formatarMl(h.metaMl - h.totalMl)} para a meta.',
          )
        else
          LinhaDoRelatorio(
            icone: Icons.flag_rounded,
            texto: 'Meta do dia: ${formatarMl(h.metaMl)}.',
          ),
      ],
    );
  }
}

class _CartaoRefeicoes extends StatelessWidget {
  final RelatorioDiaViewModel viewModel;
  final RefeicoesDoDia refeicoes;

  const _CartaoRefeicoes({required this.viewModel, required this.refeicoes});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final r = refeicoes;

    return CartaoRelatorio(
      icone: Icons.restaurant_rounded,
      titulo: 'Refeições',
      resumo: r.total == 0
          ? 'Sem refeições no plano'
          : '${r.feitas} de ${r.total} feitas',
      filhos: [
        if (r.total > 0)
          BarraDeProgresso(valor: r.progresso, completa: r.todasFeitas),
        if (r.planejadas.isNotEmpty || r.foraDoPlano.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in r.planejadas)
                _LinhaDeRefeicao(nome: item.refeicao.nome, feitaEm: item.feitaEm),
              for (final extra in r.foraDoPlano)
                _LinhaDeRefeicao(nome: extra.nome, feitaEm: extra.dataHora),
            ],
          ),
        if (viewModel.temNutrientes)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ResumoNutricional(
                titulo: 'Estimativa de nutrientes',
                nutrientes: viewModel.nutrientesConsumidos,
                metas: viewModel.metas,
              ),
              Text(
                'Calculada pelos alimentos cadastrados em cada refeição feita.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.35,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// "Café da manhã - Feito às 07:10" / "Almoço - Não feito". Icone, texto e cor
// dizem a mesma coisa (nunca so a cor - NF004).
class _LinhaDeRefeicao extends StatelessWidget {
  final String nome;
  final DateTime? feitaEm;

  const _LinhaDeRefeicao({required this.nome, required this.feitaEm});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final feita = feitaEm != null;
    final cor = feita ? AppCores.sucesso : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            feita
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 32,
            color: cor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  feita ? 'Feito às ${formatarHora(feitaEm!)}' : 'Não feito',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: cor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoGlicemia extends StatelessWidget {
  final DiabetesDoDia diabetes;

  const _CartaoGlicemia({required this.diabetes});

  @override
  Widget build(BuildContext context) {
    final d = diabetes;
    final glicemia = d.glicemia;

    return CartaoRelatorio(
      icone: Icons.bloodtype_rounded,
      titulo: 'Glicemia e insulina',
      resumo: '${d.medicoesFeitas} de ${d.medicoesPrevistas} medições',
      filhos: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in d.checklist)
              _LinhaDeGlicemia(
                rotulo: item.momento.rotulo,
                registro: item.registro,
              ),
            for (final registro in d.outrasMedicoes)
              _LinhaDeGlicemia(
                rotulo: MomentoGlicemia.outraMedicao.rotulo,
                registro: registro,
              ),
          ],
        ),
        if (glicemia.medicoes > 0)
          _Dados(
            dados: [
              (rotulo: 'Média', valor: formatarGlicemia(glicemia.media!)),
              (rotulo: 'Menor', valor: formatarGlicemia(glicemia.menor!)),
              (rotulo: 'Maior', valor: formatarGlicemia(glicemia.maior!)),
            ],
          ),
        if (d.aplicacoes > 0)
          LinhaDoRelatorio(
            icone: Icons.vaccines_rounded,
            texto: 'Insulina no dia: ${formatarDose(d.insulinaTotal)} em '
                '${d.aplicacoes} ${d.aplicacoes == 1 ? 'aplicação' : 'aplicações'}.',
          ),
      ],
    );
  }
}

// Um momento do checklist de glicemia: o valor com a faixa em selo, a dose de
// insulina e a hora - ou "Não anotado". Em caixa alta, como na rotina (NF004).
class _LinhaDeGlicemia extends StatelessWidget {
  final String rotulo;
  final RegistroDiabete? registro;

  const _LinhaDeGlicemia({required this.rotulo, required this.registro});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final registro = this.registro;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rotulo,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          if (registro == null)
            Row(
              children: [
                Icon(
                  Icons.radio_button_unchecked_rounded,
                  size: 26,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Não anotado',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (registro.temGlicemia) ...[
                  Text(
                    formatarGlicemia(registro.nivelGlicose!),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  SeloFaixaGlicemia(
                    FaixasGlicemia.classificar(registro.nivelGlicose!),
                  ),
                ],
                if (registro.temInsulina)
                  Text(
                    descreverInsulina(
                      registro.tipoInsulina,
                      registro.doseInsulina!,
                    ),
                    style: TextStyle(fontSize: 18, color: colorScheme.onSurface),
                  ),
                Text(
                  descreverHora(registro.dataHora),
                  style: TextStyle(
                    fontSize: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// Alguns numeros lado a lado, cada um com o nome em cima ("Média" /
// "130 mg/dL"), em colunas do mesmo tamanho. Com a fonte do celular muito
// grande passam a ficar um embaixo do outro (NF004).
class _Dados extends StatelessWidget {
  final List<({String rotulo, String valor})> dados;

  const _Dados({required this.dados});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fonteMuitoGrande = MediaQuery.textScalerOf(context).scale(20) > 28;

    // A folga a direita separa as colunas: sem ela o valor, encolhido pelo
    // FittedBox ate a largura da coluna, encostaria no da vizinha.
    Widget dado(({String rotulo, String valor}) item) {
      return Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.rotulo,
              style:
                  TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                item.valor,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (fonteMuitoGrande) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in dados)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: dado(item)),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in dados) Expanded(child: dado(item)),
      ],
    );
  }
}

class _CartaoBatimentos extends StatelessWidget {
  // Alertas listados no cartao; o resto vira "e mais N".
  static const int maximoAlertasVisiveis = 5;

  final ResumoDoDia resumo;

  const _CartaoBatimentos({required this.resumo});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final b = resumo.batimentos;
    final alertas = resumo.alertas;
    final zona = '${b.zonaMinima} a ${b.zonaMaxima} BPM';

    return CartaoRelatorio(
      icone: Icons.favorite_rounded,
      titulo: 'Batimentos',
      resumo: b.temLeituras
          ? 'Média de ${b.media!.round()} BPM'
          : 'Sem leituras',
      filhos: [
        if (b.temLeituras) ...[
          _Dados(
            dados: [
              (rotulo: 'Menor', valor: '${b.minimo} BPM'),
              (rotulo: 'Maior', valor: '${b.maximo} BPM'),
              (rotulo: 'Leituras', valor: '${b.leituras}'),
            ],
          ),
          if (b.foraDaZona == 0)
            LinhaDoRelatorio(
              icone: Icons.check_circle_rounded,
              cor: AppCores.sucesso,
              texto: 'Todas as leituras dentro da zona de segurança ($zona).',
            )
          else
            LinhaDoRelatorio(
              icone: Icons.warning_rounded,
              cor: AppCores.aviso,
              texto: '${b.foraDaZona} '
                  '${b.foraDaZona == 1 ? 'leitura' : 'leituras'} fora da zona '
                  'de segurança ($zona).',
            ),
        ] else
          LinhaDoRelatorio(
            icone: Icons.watch_off_rounded,
            cor: colorScheme.onSurfaceVariant,
            texto: 'O smartwatch não registrou batimentos neste dia.',
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Alertas do dia',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (alertas.isEmpty)
              const LinhaDoRelatorio(
                icone: Icons.check_circle_rounded,
                cor: AppCores.sucesso,
                texto: 'Nenhum alerta neste dia.',
              )
            else ...[
              for (final alerta in alertas.take(maximoAlertasVisiveis))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LinhaDeAlerta(alerta: alerta),
                ),
              if (alertas.length > maximoAlertasVisiveis)
                Text(
                  'e mais ${alertas.length - maximoAlertasVisiveis} '
                  '${alertas.length - maximoAlertasVisiveis == 1 ? 'alerta' : 'alertas'}',
                  style: TextStyle(
                    fontSize: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ],
        ),
      ],
    );
  }
}

class _LinhaDeAlerta extends StatelessWidget {
  final Alerta alerta;

  const _LinhaDeAlerta({required this.alerta});

  @override
  Widget build(BuildContext context) {
    final emergencia = alerta.ehEmergencia;

    return LinhaDoRelatorio(
      icone: emergencia ? Icons.warning_rounded : Icons.info_rounded,
      cor: emergencia ? AppCores.perigo : AppCores.aviso,
      texto: '${formatarHora(alerta.dataHora)} · '
          '${emergencia ? 'Emergência' : 'Atenção'}: ${alerta.mensagem}',
    );
  }
}
