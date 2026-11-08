import 'package:flutter/material.dart';

import '../../core/constants/faixas_glicemia.dart';
import '../../core/constants/momentos_glicemia.dart';
import '../../core/constants/zona_seguranca_cardiaca.dart';
import '../../core/theme/app_cores.dart';
import '../../domain/models/batimento_cardiaco.dart';
import '../../domain/models/limites_alerta.dart';
import '../../domain/models/paciente.dart';
import '../../domain/models/registro_base.dart';
import '../../domain/models/registro_diabete.dart';
import '../alertas/card_alerta.dart';
import '../insulina/formatacao_diabete.dart';
import '../shared/card_status.dart';
import 'diabetes_acompanhante_viewmodel.dart';
import 'formato_status_paciente.dart';
import 'status_paciente_viewmodel.dart';

// Cartao de um paciente vinculado no painel do acompanhante (Figura 15 do
// TCC). Mostra a identificacao, as comorbidades da triagem, quantos alertas
// do paciente ainda nao foram lidos (RF06), o BPM mais recente com ha quanto
// tempo foi medido e o status consolidado (RF05.1), a ultima atividade da
// rotina, a ultima glicemia e a ultima dose de insulina dos diabeticos
// (RF008) e os atalhos para os relatorios (dia anterior e mes), para ver
// onde ele esta e para ajustar os limites de BPM que disparam o alerta
// (RF 06.1).
class CardPaciente extends StatelessWidget {
  final Paciente paciente;
  final int alertasNaoLidos;
  // Null enquanto carrega ou se o paciente nao e diabetico.
  final ResumoDiabete? resumoDiabete;
  // Saude em tempo real, vinda do StatusPacienteViewModel do card. Sem
  // `statusSaude` (ainda carregando) o bloco de BPM nao aparece.
  final StatusSaude? statusSaude;
  final BatimentoCardiaco? ultimoBatimento;
  final RegistroBase? ultimaAtividade;
  // Limites de BPM do paciente, tambem do ViewModel do card (seguem o
  // Firestore em tempo real); null = zona padrao.
  final LimitesAlerta? limitesAlerta;
  // Referencia para o "ha X minutos"; null usa o relogio do aparelho.
  final DateTime? agora;
  final VoidCallback? onDesvincular;
  final VoidCallback? onVerRelatorios;
  final VoidCallback? onVerLocalizacao;
  final VoidCallback? onAjustarLimites;

  const CardPaciente({
    super.key,
    required this.paciente,
    this.alertasNaoLidos = 0,
    this.resumoDiabete,
    this.statusSaude,
    this.ultimoBatimento,
    this.ultimaAtividade,
    this.limitesAlerta,
    this.agora,
    this.onDesvincular,
    this.onVerRelatorios,
    this.onVerLocalizacao,
    this.onAjustarLimites,
  });

  String get _primeiroNome {
    final nome = paciente.nome.trim();
    return nome.isEmpty ? 'o paciente' : nome.split(RegExp(r'\s+')).first;
  }

  bool get _mostrarResumoDiabete =>
      paciente.possuiDiabetes && resumoDiabete != null;

  // Glicemia ou insulina como ultima atividade ja aparece, com o horario, no
  // resumo do diabetes logo abaixo: a linha repetiria a mesma informacao.
  bool get _mostrarUltimaAtividade =>
      ultimaAtividade != null &&
      !(ultimaAtividade is RegistroDiabete && _mostrarResumoDiabete);

  String get _inicial {
    final nome = paciente.nome.trim();
    return nome.isEmpty ? '?' : nome[0].toUpperCase();
  }

  List<String> get _etiquetas {
    if (!paciente.triagemConcluida) return ['Triagem pendente'];
    final etiquetas = <String>[];
    if (paciente.possuiDiabetes) etiquetas.add('Diabetes');
    if (paciente.possuiCardiopatia) etiquetas.add('Cardiopatia');
    if (etiquetas.isEmpty) etiquetas.add('Sem comorbidades');
    return etiquetas;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    _inicial,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        paciente.nome.trim().isEmpty
                            ? 'Paciente'
                            : paciente.nome,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _etiquetas
                            .map(
                              (etiqueta) => Chip(
                                label: Text(etiqueta),
                                labelStyle: const TextStyle(fontSize: 14),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                            .toList(),
                      ),
                      if (alertasNaoLidos > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              size: 20,
                              color: AppCores.perigo,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                alertasNaoLidos == 1
                                    ? '1 alerta não lido'
                                    : '$alertasNaoLidos alertas não lidos',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppCores.perigo,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (onDesvincular != null)
                  PopupMenuButton<String>(
                    tooltip: 'Mais opções',
                    iconSize: 28,
                    onSelected: (_) => onDesvincular!(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'desvincular',
                        child: Row(
                          children: [
                            Icon(Icons.link_off_rounded),
                            SizedBox(width: 12),
                            Text('Desvincular', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (statusSaude != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _SaudeDoPaciente(
                  status: statusSaude!,
                  batimento: ultimoBatimento,
                  agora: agora ?? DateTime.now(),
                  primeiroNome: _primeiroNome,
                  bpmMinimo: ZonaSegurancaCardiaca.bpmMinimo(
                    possuiCardiopatia: paciente.possuiCardiopatia,
                    limites: limitesAlerta,
                  ),
                  bpmMaximo: ZonaSegurancaCardiaca.bpmMaximo(
                    possuiCardiopatia: paciente.possuiCardiopatia,
                    limites: limitesAlerta,
                  ),
                ),
              ),
            ],
            if (_mostrarUltimaAtividade) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _UltimaAtividade(
                  registro: ultimaAtividade!,
                  agora: agora ?? DateTime.now(),
                ),
              ),
            ],
            if (_mostrarResumoDiabete) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _ResumoDiabete(
                  resumo: resumoDiabete!,
                  usaInsulina: paciente.usaInsulina == true,
                ),
              ),
            ],
            if (onVerRelatorios != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                  onPressed: onVerRelatorios,
                  icon: const Icon(Icons.bar_chart_rounded),
                  label: const Text('Ver relatórios'),
                ),
              ),
            ],
            if (onVerLocalizacao != null) ...[
              const SizedBox(height: 16),
              // O card tem margem direita menor por causa do botao "Mais
              // opções"; os 12 extras deixam o botao com 20 dos dois lados.
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                  onPressed: onVerLocalizacao,
                  icon: const Icon(Icons.location_on_rounded),
                  label: const Text('Ver localização'),
                ),
              ),
            ],
            if (onAjustarLimites != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                  onPressed: onAjustarLimites,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Limites de alerta'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// BPM mais recente com ha quanto tempo foi medido e, logo abaixo, o selo do
// status consolidado (Figura 15). Sem leitura recente o selo vira "SEM
// DADOS" e uma frase diz ao acompanhante o que fazer.
class _SaudeDoPaciente extends StatelessWidget {
  final StatusSaude status;
  final BatimentoCardiaco? batimento;
  final DateTime agora;
  final String primeiroNome;
  final int bpmMinimo;
  final int bpmMaximo;

  const _SaudeDoPaciente({
    required this.status,
    required this.batimento,
    required this.agora,
    required this.primeiroNome,
    required this.bpmMinimo,
    required this.bpmMaximo,
  });

  String? get _explicacao {
    final batimento = this.batimento;
    switch (status) {
      case StatusSaude.estavel:
        return null;
      case StatusSaude.atencao:
        final direcao = batimento!.bpm > bpmMaximo ? 'Acima' : 'Abaixo';
        return '$direcao da zona de segurança ($bpmMinimo a $bpmMaximo '
            'batimentos por minuto).';
      case StatusSaude.semDados:
        if (batimento == null) {
          return 'O smartwatch ainda não enviou medições. Peça a '
              '$primeiroNome para abrir o Agenda Saúde com o relógio no pulso.';
        }
        // B10: o aviso "sem dados" sai pelo push depois do prazo, contado so
        // durante o dia.
        final horas = ZonaSegurancaCardiaca.prazoAvisoSemDados.inHours;
        return 'O smartwatch não envia medições há mais de uma hora. Peça a '
            '$primeiroNome para abrir o Agenda Saúde com o relógio no pulso. '
            'Se continuar assim por $horas horas, entre '
            '${ZonaSegurancaCardiaca.inicioDoDiaParaAviso}h e '
            '${ZonaSegurancaCardiaca.fimDoDiaParaAviso}h, você recebe um aviso.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final estilo = estiloDoStatus(status);
    final batimento = this.batimento;
    final explicacao = _explicacao;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (batimento == null)
          Text(
            'NENHUMA MEDIÇÃO DE BATIMENTOS',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          _BatimentoDoCard(batimento: batimento, status: status, agora: agora),
        const SizedBox(height: 12),
        CardStatus(rotulo: estilo.rotulo, icone: estilo.icone, cor: estilo.cor),
        if (explicacao != null) ...[
          const SizedBox(height: 8),
          Text(
            explicacao,
            style: TextStyle(
              fontSize: 16,
              height: 1.35,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

// "♥ 72 BPM" com o horario da medicao embaixo. Em "ATENÇÃO" o coracao fica
// vermelho; em "SEM DADOS" (leitura antiga) o numero fica apagado, para nao
// parecer o valor de agora. O leitor de tela le "72 por minuto".
class _BatimentoDoCard extends StatelessWidget {
  final BatimentoCardiaco batimento;
  final StatusSaude status;
  final DateTime agora;

  const _BatimentoDoCard({
    required this.batimento,
    required this.status,
    required this.agora,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final quando = descreverHorario(batimento.timestamp, agora: agora);
    final semDados = status == StatusSaude.semDados;
    final emAtencao = status == StatusSaude.atencao;

    final corCoracao = emAtencao
        ? AppCores.perigo
        : (semDados ? colorScheme.onSurfaceVariant : colorScheme.primary);
    final fundoCoracao = emAtencao
        ? AppCores.perigoContainer
        : (semDados
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primaryContainer);

    return Semantics(
      container: true,
      label: 'Batimentos: ${batimento.bpm} por minuto, medidos '
          '${quando[0].toLowerCase()}${quando.substring(1)}.',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: fundoCoracao,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.favorite_rounded, size: 32, color: corCoracao),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${batimento.bpm}',
                          style: TextStyle(
                            fontSize: 40,
                            height: 1.1,
                            fontWeight: FontWeight.bold,
                            color: semDados
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'BPM',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    quando.toUpperCase(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// O ultimo evento da rotina cumprido (Figura 15): "BEBEU ÁGUA: 250 ML",
// com ha quanto tempo.
class _UltimaAtividade extends StatelessWidget {
  final RegistroBase registro;
  final DateTime agora;

  const _UltimaAtividade({required this.registro, required this.agora});

  @override
  Widget build(BuildContext context) {
    final atividade = descreverAtividade(registro);
    return _LinhaResumo(
      icone: atividade.icone,
      titulo: atividade.texto,
      subtitulo: 'ÚLTIMA ATIVIDADE · '
          '${descreverHorario(registro.dataHora, agora: agora).toUpperCase()}',
    );
  }
}

// Ultima glicemia (com a faixa em selo de texto, icone e cor) e ultima dose
// de insulina, cada uma com o momento e o horario do registro. Em caixa
// alta, no mesmo padrao do cartao de glicemia do paciente (NF004).
class _ResumoDiabete extends StatelessWidget {
  final ResumoDiabete resumo;
  final bool usaInsulina;

  const _ResumoDiabete({required this.resumo, required this.usaInsulina});

  String _momentoEHorario(RegistroDiabete registro) =>
      '${MomentoGlicemia.porNome(registro.momento).rotulo} · '
      '${descreverHorario(registro.dataHora).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final glicemia = resumo.ultimaGlicemia;
    final insulina = resumo.ultimaInsulina;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LinhaResumo(
          icone: Icons.bloodtype_rounded,
          titulo: glicemia == null
              ? 'GLICEMIA: NADA ANOTADO AINDA'
              : 'GLICEMIA: ${formatarGlicemia(glicemia.nivelGlicose!)}',
          classificacao: glicemia == null
              ? null
              : FaixasGlicemia.classificar(glicemia.nivelGlicose!),
          subtitulo: glicemia == null ? null : _momentoEHorario(glicemia),
        ),
        if (usaInsulina || insulina != null) ...[
          const SizedBox(height: 12),
          _LinhaResumo(
            icone: Icons.vaccines_rounded,
            titulo: insulina == null
                ? 'INSULINA: NADA ANOTADO AINDA'
                : descreverInsulina(
                    insulina.tipoInsulina,
                    insulina.doseInsulina!,
                  ).toUpperCase(),
            subtitulo: insulina == null ? null : _momentoEHorario(insulina),
          ),
        ],
      ],
    );
  }
}

class _LinhaResumo extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final ClassificacaoGlicemia? classificacao;
  final String? subtitulo;

  const _LinhaResumo({
    required this.icone,
    required this.titulo,
    this.classificacao,
    this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final classificacao = this.classificacao;
    final subtitulo = this.subtitulo;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 28, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (classificacao != null) ...[
                const SizedBox(height: 4),
                SeloFaixaGlicemia(classificacao),
              ],
              if (subtitulo != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitulo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
