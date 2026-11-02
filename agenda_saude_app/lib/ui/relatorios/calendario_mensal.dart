import 'package:flutter/material.dart';

import '../../core/theme/app_cores.dart';
import '../../domain/relatorios/resumo_do_dia.dart';
import '../../domain/relatorios/resumo_do_mes.dart';

// Calendario do mes (RF05): uma celula por dia, pintada pela situacao da
// rotina - completa, parcial ou sem registro - sempre com icone e texto
// falado alem da cor. Dias que ja terminaram abrem o relatorio do dia ao
// toque; hoje e os dias que ainda nao chegaram ficam sem cor. Um triangulo
// vermelho, ao lado do icone, marca os dias com emergencia de batimentos,
// hipoglicemia ou glicemia muito alta. A semana comeca no domingo.
class CalendarioMensal extends StatelessWidget {
  final ResumoDoMes resumo;
  final ValueChanged<int>? aoTocarDia;

  const CalendarioMensal({super.key, required this.resumo, this.aoTocarDia});

  static const List<String> _iniciais = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
  static const List<String> _nomes = [
    'domingo',
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
  ];

  @override
  Widget build(BuildContext context) {
    // DateTime.weekday: segunda = 1 ... domingo = 7. Com a semana comecando no
    // domingo, quantas celulas vazias vem antes do dia 1.
    final vazias = resumo.mes.weekday % 7;
    final semanas = ((vazias + resumo.diasNoMes) / 7).ceil();

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Semantics(
                  label: _nomes[i],
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _iniciais[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (var semana = 0; semana < semanas; semana++)
          Row(
            children: [
              for (var coluna = 0; coluna < 7; coluna++)
                Expanded(child: _celula(semana * 7 + coluna - vazias + 1)),
            ],
          ),
      ],
    );
  }

  Widget _celula(int dia) {
    if (dia < 1 || dia > resumo.diasNoMes) {
      return const SizedBox(height: _CelulaDoDia.altura);
    }
    final encerrado = resumo.diaEncerrado(dia);
    return _CelulaDoDia(
      dia: dia,
      situacao: encerrado?.situacao,
      ehHoje: resumo.diaDeHoje == dia,
      comAlerta: encerrado?.temAlertaGrave ?? false,
      aoTocar: encerrado == null || aoTocarDia == null
          ? null
          : () => aoTocarDia!(dia),
    );
  }
}

// Icone de cada situacao do dia - o mesmo da celula e da legenda.
IconData iconeDaSituacao(SituacaoDoDia situacao) {
  switch (situacao) {
    case SituacaoDoDia.completo:
      return Icons.check_circle_rounded;
    case SituacaoDoDia.parcial:
      return Icons.incomplete_circle_rounded;
    case SituacaoDoDia.semRegistro:
      return Icons.remove_circle_outline_rounded;
  }
}

// Cor do icone de cada situacao do dia.
Color corDaSituacao(BuildContext context, SituacaoDoDia situacao) {
  switch (situacao) {
    case SituacaoDoDia.completo:
      return AppCores.sucesso;
    case SituacaoDoDia.parcial:
      return AppCores.aviso;
    case SituacaoDoDia.semRegistro:
      return Theme.of(context).colorScheme.onSurfaceVariant;
  }
}

class _CelulaDoDia extends StatelessWidget {
  static const double altura = 56;

  final int dia;
  // Null quando o dia ainda nao terminou (hoje ou futuro).
  final SituacaoDoDia? situacao;
  final bool ehHoje;
  final bool comAlerta;
  final VoidCallback? aoTocar;

  const _CelulaDoDia({
    required this.dia,
    required this.situacao,
    required this.ehHoje,
    required this.comAlerta,
    required this.aoTocar,
  });

  Color _fundo(ColorScheme colorScheme) {
    switch (situacao) {
      case SituacaoDoDia.completo:
        return AppCores.sucessoContainer;
      case SituacaoDoDia.parcial:
        return AppCores.avisoContainer;
      case SituacaoDoDia.semRegistro:
        return colorScheme.surfaceContainerHighest;
      case null:
        return Colors.transparent;
    }
  }

  Color _texto(ColorScheme colorScheme) {
    switch (situacao) {
      case SituacaoDoDia.completo:
        return AppCores.onSucessoContainer;
      case SituacaoDoDia.parcial:
        return AppCores.onAvisoContainer;
      case SituacaoDoDia.semRegistro:
        return colorScheme.onSurface;
      case null:
        return colorScheme.onSurfaceVariant;
    }
  }

  String get _descricao {
    final String estado;
    if (ehHoje) {
      estado = 'hoje, ainda em andamento';
    } else {
      switch (situacao) {
        case SituacaoDoDia.completo:
          estado = 'rotina completa';
        case SituacaoDoDia.parcial:
          estado = 'rotina parcial';
        case SituacaoDoDia.semRegistro:
          estado = 'sem registros';
        case null:
          estado = 'ainda não chegou';
      }
    }
    final alerta = comAlerta ? ', com alerta de saúde' : '';
    final toque = aoTocar != null ? '. Toque para ver o relatório do dia.' : '';
    return 'Dia $dia: $estado$alerta$toque';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final texto = _texto(colorScheme);
    final situacao = this.situacao;

    // O toque vale a celula inteira (InkWell por fora); a parte colorida deixa
    // 2dp de margem em volta so no desenho.
    return Semantics(
      button: aoTocar != null,
      label: _descricao,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: aoTocar,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Ink(
              height: altura - 4,
              decoration: BoxDecoration(
                color: _fundo(colorScheme),
                borderRadius: BorderRadius.circular(12),
                border: ehHoje
                    ? Border.all(color: colorScheme.primary, width: 2)
                    : null,
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$dia',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: texto,
                        ),
                      ),
                      if (situacao != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              iconeDaSituacao(situacao),
                              size: 20,
                              color: corDaSituacao(context, situacao),
                            ),
                            // O triangulo vermelho fica ao lado do icone da
                            // situacao, nao em cima do numero do dia.
                            if (comAlerta) ...[
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.warning_rounded,
                                size: 18,
                                color: AppCores.perigo,
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
