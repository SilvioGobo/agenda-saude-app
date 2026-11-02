import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/faixas_glicemia.dart';
import '../../core/theme/app_cores.dart';
import '../../domain/relatorios/resumo_do_dia.dart';
import '../../domain/relatorios/resumo_do_mes.dart';
import '../insulina/formatacao_diabete.dart';
import 'calendario_mensal.dart';
import 'cartao_relatorio.dart';
import 'estado_relatorio.dart';
import 'formato_relatorios.dart';
import 'grafico_diario.dart';
import 'relatorio_mes_viewmodel.dart';

// O relatorio de um mes (RF05), igual para o paciente e para o acompanhante:
// o calendario da rotina - que abre o relatorio de cada dia - e um cartao com
// numeros e grafico para cada parte da rotina. So conta os dias que ja
// terminaram. Precisa de um [RelatorioMesViewModel] acima na arvore.
class RelatorioMesConteudo extends StatelessWidget {
  // Abre o relatorio do dia que o usuario tocou no calendario.
  final ValueChanged<DateTime> aoAbrirDia;

  const RelatorioMesConteudo({super.key, required this.aoAbrirDia});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RelatorioMesViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NavegacaoDoMes(viewModel: viewModel),
        const SizedBox(height: 16),
        switch (viewModel.estado) {
          EstadoRelatorio.carregando => const CarregandoRelatorio(),
          EstadoRelatorio.erro => ErroDeRelatorio(
              aoTentarDeNovo: viewModel.carregar,
            ),
          EstadoRelatorio.pronto => _RelatorioPronto(
              resumo: viewModel.resumo!,
              mostrarGlicemia: viewModel.paciente.possuiDiabetes,
              aoAbrirDia: aoAbrirDia,
            ),
        },
      ],
    );
  }
}

// "Novembro de 2026" com os botoes para o mes anterior e o proximo. Com a
// fonte do celular muito grande os botoes ficam um embaixo do outro (NF004).
class _NavegacaoDoMes extends StatelessWidget {
  final RelatorioMesViewModel viewModel;

  const _NavegacaoDoMes({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final carregando = viewModel.estado == EstadoRelatorio.carregando;
    final fonteMuitoGrande = MediaQuery.textScalerOf(context).scale(16) > 24;

    final anterior = OutlinedButton.icon(
      onPressed: carregando ? null : viewModel.mesAnterior,
      icon: const Icon(Icons.chevron_left_rounded),
      label: const Text('Mês anterior'),
    );
    final proximo = OutlinedButton.icon(
      onPressed:
          carregando || !viewModel.podeAvancar ? null : viewModel.proximoMes,
      icon: const Icon(Icons.chevron_right_rounded),
      iconAlignment: IconAlignment.end,
      label: const Text('Próximo mês'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            tituloDoMes(viewModel.mes),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (fonteMuitoGrande) ...[
          anterior,
          const SizedBox(height: 12),
          proximo,
        ] else
          Row(
            children: [
              Expanded(child: anterior),
              const SizedBox(width: 12),
              Expanded(child: proximo),
            ],
          ),
      ],
    );
  }
}

class _RelatorioPronto extends StatelessWidget {
  final ResumoDoMes resumo;
  final bool mostrarGlicemia;
  final ValueChanged<DateTime> aoAbrirDia;

  const _RelatorioPronto({
    required this.resumo,
    required this.mostrarGlicemia,
    required this.aoAbrirDia,
  });

  @override
  Widget build(BuildContext context) {
    if (!resumo.temDiasEncerrados) {
      return const CartaoRelatorio(
        icone: Icons.calendar_month_rounded,
        titulo: 'Mês em andamento',
        filhos: [
          Text(
            'Ainda não terminou nenhum dia deste mês. O relatório aparece a '
            'partir de amanhã.',
            style: TextStyle(fontSize: 18, height: 1.35),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CartaoCalendario(resumo: resumo, aoAbrirDia: aoAbrirDia),
        const SizedBox(height: 16),
        _CartaoHidratacao(resumo: resumo),
        const SizedBox(height: 16),
        _CartaoRefeicoes(resumo: resumo),
        if (mostrarGlicemia) ...[
          const SizedBox(height: 16),
          _CartaoGlicemia(resumo: resumo),
        ],
        const SizedBox(height: 16),
        _CartaoBatimentos(resumo: resumo),
      ],
    );
  }
}

// "9 de 30 dias" - o total concorda em numero ("1 de 1 dia").
String _deDias(int quantidade, int total) =>
    '$quantidade de $total ${total == 1 ? 'dia' : 'dias'}';

double _maior(List<double?> serie) => serie
    .whereType<double>()
    .fold(0.0, (maior, valor) => valor > maior ? valor : maior);

// Cartao do calendario. Tem menos margem lateral que os outros cartoes para
// as celulas ficarem o mais perto possivel de 48dp de largura (NF004).
class _CartaoCalendario extends StatelessWidget {
  final ResumoDoMes resumo;
  final ValueChanged<DateTime> aoAbrirDia;

  const _CartaoCalendario({required this.resumo, required this.aoAbrirDia});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final completos = resumo.diasCompletos;
    final parciais = resumo.diasParciais;
    final semRegistro = resumo.diasSemRegistro;
    final comAlerta = resumo.diasComAlertaGrave.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: CabecalhoDoCartao(
                icone: Icons.calendar_month_rounded,
                titulo: 'Rotina do mês',
                resumo: '${_deDias(resumo.diasComRegistro, resumo.diasEncerrados)} '
                    'com registro',
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Toque em um dia para ver o relatório dele.',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.35,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            CalendarioMensal(
              resumo: resumo,
              aoTocarDia: (dia) => aoAbrirDia(
                DateTime(resumo.mes.year, resumo.mes.month, dia),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinhaDoRelatorio(
                    icone: iconeDaSituacao(SituacaoDoDia.completo),
                    cor: corDaSituacao(context, SituacaoDoDia.completo),
                    texto: completos == 1
                        ? '1 dia completo'
                        : '$completos dias completos',
                  ),
                  const SizedBox(height: 8),
                  LinhaDoRelatorio(
                    icone: iconeDaSituacao(SituacaoDoDia.parcial),
                    cor: corDaSituacao(context, SituacaoDoDia.parcial),
                    texto: parciais == 1
                        ? '1 dia parcial'
                        : '$parciais dias parciais',
                  ),
                  const SizedBox(height: 8),
                  LinhaDoRelatorio(
                    icone: iconeDaSituacao(SituacaoDoDia.semRegistro),
                    cor: corDaSituacao(context, SituacaoDoDia.semRegistro),
                    texto: semRegistro == 1
                        ? '1 dia sem registro'
                        : '$semRegistro dias sem registro',
                  ),
                  if (comAlerta > 0) ...[
                    const SizedBox(height: 8),
                    LinhaDoRelatorio(
                      icone: Icons.warning_rounded,
                      cor: AppCores.perigo,
                      texto: comAlerta == 1
                          ? '1 dia com alerta de saúde'
                          : '$comAlerta dias com alerta de saúde',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoHidratacao extends StatelessWidget {
  final ResumoDoMes resumo;

  const _CartaoHidratacao({required this.resumo});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final media = resumo.mediaAguaMl;
    final meta = resumo.metaAguaMl;
    final serie = resumo.serieAgua;
    final nomeDoMesAtual = nomeDoMes(resumo.mes.month);

    return CartaoRelatorio(
      icone: Icons.water_drop_rounded,
      titulo: 'Hidratação',
      resumo: media == null
          ? 'Nenhuma água anotada'
          : 'Média de ${formatarMl(media.round())} por dia',
      filhos: [
        LinhaDoRelatorio(
          icone: resumo.diasMetaDeAgua > 0
              ? Icons.check_circle_rounded
              : Icons.flag_rounded,
          cor: resumo.diasMetaDeAgua > 0 ? AppCores.sucesso : null,
          texto: 'Meta de ${formatarMl(meta)} batida em '
              '${_deDias(resumo.diasMetaDeAgua, resumo.diasEncerrados)}',
        ),
        LinhaDoRelatorio(
          icone: Icons.edit_calendar_rounded,
          texto: 'Água anotada em '
              '${_deDias(resumo.diasComAgua, resumo.diasEncerrados)}',
        ),
        if (resumo.diasComAgua > 0)
          GraficoDiario(
            valores: serie,
            maximo: [meta * 1.25, _maior(serie) * 1.05]
                .reduce((a, b) => a > b ? a : b),
            linhas: [
              LinhaDeReferencia(
                valor: meta.toDouble(),
                rotulo: 'Meta: ${formatarMl(meta)}',
              ),
            ],
            legendas: [
              const LegendaDeCor(
                cor: AppCores.sucesso,
                rotulo: 'Meta atingida',
              ),
              LegendaDeCor(cor: colorScheme.outline, rotulo: 'Abaixo da meta'),
            ],
            corDaBarra: (valor) =>
                valor >= meta ? AppCores.sucesso : colorScheme.outline,
            descricao: 'Gráfico da água de cada dia de $nomeDoMesAtual. '
                'Média de ${formatarMl(media!.round())} nos dias com anotação, '
                'meta de ${formatarMl(meta)}.',
          ),
      ],
    );
  }
}

class _CartaoRefeicoes extends StatelessWidget {
  final ResumoDoMes resumo;

  const _CartaoRefeicoes({required this.resumo});

  @override
  Widget build(BuildContext context) {
    final previstas = resumo.refeicoesPrevistas;
    final feitas = resumo.refeicoesFeitas;

    return CartaoRelatorio(
      icone: Icons.restaurant_rounded,
      titulo: 'Refeições',
      resumo: previstas == 0
          ? 'Sem refeições no plano'
          : '$feitas de $previstas feitas '
              '(${formatarPorcentagem(feitas / previstas)})',
      filhos: [
        if (previstas > 0) ...[
          BarraDeProgresso(
            valor: feitas / previstas,
            completa: feitas == previstas,
          ),
          LinhaDoRelatorio(
            icone: Icons.check_circle_rounded,
            cor: resumo.diasComTodasAsRefeicoes > 0 ? AppCores.sucesso : null,
            texto: 'Todas as refeições feitas em '
                '${_deDias(resumo.diasComTodasAsRefeicoes, resumo.diasEncerrados)}',
          ),
        ],
      ],
    );
  }
}

class _CartaoGlicemia extends StatelessWidget {
  final ResumoDoMes resumo;

  const _CartaoGlicemia({required this.resumo});

  @override
  Widget build(BuildContext context) {
    final glicemia = resumo.glicemia;
    final serie = resumo.serieGlicemia;
    final nomeDoMesAtual = nomeDoMes(resumo.mes.month);
    final soAltas = glicemia.altas - glicemia.muitoAltas;

    return CartaoRelatorio(
      icone: Icons.bloodtype_rounded,
      titulo: 'Glicemia e insulina',
      resumo: glicemia.media == null
          ? 'Nenhuma medição anotada'
          : 'Média de ${formatarGlicemia(glicemia.media!)}',
      filhos: [
        LinhaDoRelatorio(
          icone: Icons.edit_calendar_rounded,
          texto: 'Medições feitas: ${resumo.medicoesFeitas} de '
              '${resumo.medicoesPrevistas}',
        ),
        if (glicemia.medicoes > 0)
          LinhaDoRelatorio(
            icone: Icons.check_circle_rounded,
            cor: AppCores.sucesso,
            texto: 'Na faixa de ${FaixasGlicemia.alvoMinimo} a '
                '${FaixasGlicemia.alvoMaximo} mg/dL: '
                '${formatarPorcentagem(glicemia.naFaixa / glicemia.medicoes)} '
                'das medições (${glicemia.naFaixa} de ${glicemia.medicoes})',
          ),
        if (glicemia.baixas > 0)
          LinhaDoRelatorio(
            icone: Icons.arrow_downward_rounded,
            cor: AppCores.perigo,
            negrito: true,
            texto: 'Glicemia baixa ${descreverVezes(glicemia.baixas)} '
                '(${listarDias(resumo.diasComHipoglicemia)})',
          ),
        if (glicemia.muitoAltas > 0)
          LinhaDoRelatorio(
            icone: Icons.arrow_upward_rounded,
            cor: AppCores.perigo,
            negrito: true,
            texto: 'Glicemia muito alta, acima de '
                '${FaixasGlicemia.muitoAltaAcimaDe} mg/dL: '
                '${descreverVezes(glicemia.muitoAltas)} '
                '(${listarDias(resumo.diasComGlicemiaMuitoAlta)})',
          ),
        if (soAltas > 0)
          LinhaDoRelatorio(
            icone: Icons.arrow_upward_rounded,
            cor: AppCores.aviso,
            texto: 'Glicemia alta, de ${FaixasGlicemia.alvoMaximo + 1} a '
                '${FaixasGlicemia.muitoAltaAcimaDe} mg/dL: '
                '${descreverVezes(soAltas)}',
          ),
        if (glicemia.medicoes > 0 &&
            glicemia.baixas == 0 &&
            glicemia.muitoAltas == 0)
          const LinhaDoRelatorio(
            icone: Icons.check_circle_rounded,
            cor: AppCores.sucesso,
            texto: 'Nenhuma glicemia baixa ou muito alta no mês',
          ),
        if (resumo.insulinaTotal > 0)
          LinhaDoRelatorio(
            icone: Icons.vaccines_rounded,
            texto: 'Insulina: ${formatarDose(resumo.insulinaTotal)} no mês, '
                'em ${_deDias(resumo.diasComInsulina, resumo.diasEncerrados)}',
          ),
        if (glicemia.medicoes > 0)
          GraficoDiario(
            valores: serie,
            maximo: [250.0, _maior(serie) * 1.1].reduce((a, b) => a > b ? a : b),
            linhas: [
              LinhaDeReferencia(
                valor: FaixasGlicemia.alvoMinimo.toDouble(),
                rotulo: 'Limite baixo: ${FaixasGlicemia.alvoMinimo} mg/dL',
              ),
              LinhaDeReferencia(
                valor: FaixasGlicemia.alvoMaximo.toDouble(),
                rotulo: 'Limite alto: ${FaixasGlicemia.alvoMaximo} mg/dL',
              ),
            ],
            legendas: const [
              LegendaDeCor(cor: AppCores.sucesso, rotulo: 'Na faixa'),
              LegendaDeCor(cor: AppCores.aviso, rotulo: 'Alta'),
              LegendaDeCor(cor: AppCores.perigo, rotulo: 'Baixa ou muito alta'),
            ],
            corDaBarra: (valor) =>
                corDaClassificacao(FaixasGlicemia.classificar(valor)),
            descricao: 'Gráfico da glicemia média de cada dia de '
                '$nomeDoMesAtual. Média do mês de '
                '${falarGlicemia(glicemia.media!)}, com faixa ideal de '
                '${FaixasGlicemia.alvoMinimo} a ${FaixasGlicemia.alvoMaximo}.',
          ),
      ],
    );
  }
}

// Os batimentos do mes sao contados pelos alertas: ler as dezenas de milhares
// de leituras do smartwatch de um mes para tirar uma media nao compensa. As
// leituras de cada dia aparecem no relatorio do dia.
class _CartaoBatimentos extends StatelessWidget {
  final ResumoDoMes resumo;

  const _CartaoBatimentos({required this.resumo});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final emergencias = resumo.emergencias;
    final avisos = resumo.avisos;
    final total = emergencias + avisos;

    return CartaoRelatorio(
      icone: Icons.favorite_rounded,
      titulo: 'Batimentos',
      resumo: total == 0
          ? 'Nenhum alerta no mês'
          : '$total ${total == 1 ? 'alerta' : 'alertas'} no mês',
      filhos: [
        if (emergencias > 0)
          LinhaDoRelatorio(
            icone: Icons.warning_rounded,
            cor: AppCores.perigo,
            negrito: true,
            texto: 'Emergência: ${descreverVezes(emergencias)} '
                '(${listarDias(resumo.diasComEmergencia)})',
          ),
        if (avisos > 0)
          LinhaDoRelatorio(
            icone: Icons.info_rounded,
            cor: AppCores.aviso,
            texto: 'Atenção: ${descreverVezes(avisos)} '
                '(${listarDias(resumo.diasComAviso)})',
          ),
        if (total == 0)
          const LinhaDoRelatorio(
            icone: Icons.check_circle_rounded,
            cor: AppCores.sucesso,
            texto: 'Os batimentos não geraram alertas neste mês.',
          ),
        Text(
          'Os batimentos medidos em cada dia aparecem no relatório do dia: '
          'toque nele no calendário.',
          style: TextStyle(
            fontSize: 16,
            height: 1.35,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
