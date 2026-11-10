import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/momentos_glicemia.dart';
import '../../core/theme/app_cores.dart';
import '../../domain/lembretes/lembrete.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/seletor_horario.dart';
import '../shared/titulo_tela.dart';
import 'formato_lembretes.dart';
import 'lembretes_viewmodel.dart';

// Tela "Meus lembretes" (RF 07.3), aberta pelo menu do paciente: liga e desliga
// os avisos no celular, ajuda com as permissoes que o Android pede e mostra a
// lista de horarios. O horario da glicemia e da insulina se muda aqui, no
// relogio; o dos remedios, em "Meus remedios". Reaproveita o LembretesViewModel
// do painel (que continua agendando enquanto esta tela esta aberta), em vez de
// criar outro.
class LembretesView extends StatelessWidget {
  const LembretesView({super.key});

  static Widget comViewModel(LembretesViewModel viewModel) {
    return ChangeNotifierProvider.value(
      value: viewModel,
      child: const LembretesView(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LembretesViewModel>();
    final situacao = viewModel.situacao;

    return Scaffold(
      appBar: AppBar(
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
              'Meus lembretes',
              subtitulo: 'O celular avisa na hora de tomar os remédios e, para '
                  'quem tem diabetes, de medir a glicemia e aplicar a insulina. '
                  'Os avisos tocam mesmo com o app fechado.',
            ),
            const SizedBox(height: 24),
            if (situacao == SituacaoLembretes.naoSuportado)
              _CartaoAviso(
                icone: Icons.notifications_off_rounded,
                titulo: 'Lembretes indisponíveis',
                texto: 'Este aparelho não mostra avisos agendados. Os lembretes '
                    'funcionam em celulares Android.',
                cor: Theme.of(context).colorScheme.onSurfaceVariant,
              )
            else ...[
              _CartaoLigar(viewModel: viewModel),
              if (situacao == SituacaoLembretes.semPermissao) ...[
                const SizedBox(height: 16),
                _CartaoAviso(
                  icone: Icons.notifications_off_rounded,
                  titulo: 'Notificações desativadas',
                  texto: 'Sem elas o celular não mostra os lembretes. Ative '
                      'para receber os avisos.',
                  cor: AppCores.aviso,
                  rotuloDoBotao: 'Ativar notificações',
                  iconeDoBotao: Icons.notifications_active_rounded,
                  aoTocar: viewModel.ativarNotificacoes,
                ),
              ],
              if (situacao == SituacaoLembretes.semAlarmeExato) ...[
                const SizedBox(height: 16),
                _CartaoAviso(
                  icone: Icons.alarm_rounded,
                  titulo: 'Permita "Alarmes e lembretes"',
                  texto: 'Sem essa permissão o aviso pode atrasar alguns '
                      'minutos. Na tela que vai abrir, ligue a opção para o '
                      'Agenda Saúde.',
                  cor: AppCores.aviso,
                  rotuloDoBotao: 'Permitir alarmes',
                  iconeDoBotao: Icons.alarm_on_rounded,
                  aoTocar: viewModel.permitirAlarmesExatos,
                ),
              ],
              const SizedBox(height: 24),
              _Horarios(viewModel: viewModel),
            ],
          ],
        ),
      ),
    );
  }
}

// Diz se os lembretes estao ligados e tem o botao para ligar ou desligar. O
// estado fica em texto e icone - nunca so na cor (NF004).
class _CartaoLigar extends StatelessWidget {
  final LembretesViewModel viewModel;

  const _CartaoLigar({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ligados = viewModel.ligados;
    final cor = ligados ? AppCores.sucesso : colorScheme.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  ligados
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_rounded,
                  color: cor,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ligados ? 'Lembretes ligados' : 'Lembretes desligados',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: cor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ligados
                  ? 'O celular avisa na hora de cada lembrete da lista abaixo.'
                  : 'Você não vai receber avisos no celular. Seus remédios e '
                      'medições continuam na Minha Rotina.',
              style: TextStyle(
                fontSize: 18,
                height: 1.35,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (ligados)
              OutlinedButton.icon(
                onPressed: () => viewModel.alternarLembretes(false),
                icon: const Icon(Icons.notifications_off_rounded),
                label: const Text('Desligar lembretes'),
              )
            else
              FilledButton.icon(
                onPressed: () => viewModel.alternarLembretes(true),
                icon: const Icon(Icons.notifications_active_rounded),
                label: const Text('Ligar lembretes'),
              ),
          ],
        ),
      ),
    );
  }
}

// Aviso com a explicacao e, quando ha o que fazer, o botao que resolve (pedir
// uma permissao). Laranja: pede uma acao, mas nao e emergencia.
class _CartaoAviso extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String texto;
  final Color cor;
  final String? rotuloDoBotao;
  final IconData? iconeDoBotao;
  final VoidCallback? aoTocar;

  const _CartaoAviso({
    required this.icone,
    required this.titulo,
    required this.texto,
    required this.cor,
    this.rotuloDoBotao,
    this.iconeDoBotao,
    this.aoTocar,
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
                Icon(icone, color: cor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: cor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              texto,
              style: TextStyle(
                fontSize: 18,
                height: 1.35,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (rotuloDoBotao != null && aoTocar != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: aoTocar,
                icon: Icon(iconeDoBotao),
                label: Text(rotuloDoBotao!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// A lista de horarios, do primeiro ao ultimo do dia.
class _Horarios extends StatelessWidget {
  final LembretesViewModel viewModel;

  const _Horarios({required this.viewModel});

  // Glicemia e insulina tem o horario editavel; o do remedio se muda em "Meus
  // remedios". "Voltar para 07:00" so aparece com o aviso fora do horario padrao.
  Widget _linha(BuildContext context, Lembrete lembrete) {
    final momento = lembrete.nomeDoMomento;
    if (momento == null) return _LinhaDeLembrete(lembrete: lembrete);
    final padrao = MomentoGlicemia.porNome(momento).horarioPadrao;
    final voltarPara =
        padrao != null && viewModel.horarioFoiAlterado(momento) ? padrao : null;
    return _LinhaDeLembrete(
      lembrete: lembrete,
      aoMudarHorario: () => _mudarHorario(context, lembrete, momento),
      horarioPadrao: voltarPara,
      aoVoltarAoPadrao: voltarPara == null
          ? null
          : () => _voltarAoPadrao(context, momento, voltarPara),
    );
  }

  // Abre o relogio no horario de agora do aviso e guarda o escolhido. O
  // relogio so deixa escolher hora que existe; o que pode falhar e guardar no
  // aparelho. A lista se reordena pelo horario novo, entao o aviso de baixo
  // confirma o que mudou.
  Future<void> _mudarHorario(
    BuildContext context,
    Lembrete lembrete,
    String momento,
  ) async {
    final escolhido = await mostrarSeletorDeHorario(
      context,
      inicial: lembrete.horario,
      titulo: lembrete.tipo == TipoLembrete.insulina
          ? 'HORÁRIO DA INSULINA'
          : 'HORÁRIO DA GLICEMIA',
    );
    if (escolhido == null || escolhido == lembrete.horario) return;
    final mudou = await viewModel.definirHorarioDoMomento(momento, escolhido);
    if (!context.mounted) return;
    _avisar(
      context,
      mudou
          ? 'Horário mudado para $escolhido.'
          : 'Não foi possível mudar o horário. Tente de novo.',
    );
  }

  Future<void> _voltarAoPadrao(
    BuildContext context,
    String momento,
    String padrao,
  ) async {
    final voltou = await viewModel.restaurarHorarioDoMomento(momento);
    if (!context.mounted) return;
    _avisar(
      context,
      voltou
          ? 'Horário de volta para $padrao.'
          : 'Não foi possível voltar ao horário padrão. Tente de novo.',
    );
  }

  // Um aviso anterior sai, para o de agora aparecer na hora.
  void _avisar(BuildContext context, String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(texto, style: const TextStyle(fontSize: 18))),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lembretes = viewModel.lembretes;
    final temRemedio = lembretes.any((l) => l.tipo == TipoLembrete.remedio);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Seus horários',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (lembretes.isEmpty)
          Text(
            'Você ainda não tem lembretes. Cadastre seus remédios em "Meus '
            'remédios", na Minha Rotina, e o celular avisa na hora de tomar.',
            style: TextStyle(
              fontSize: 18,
              height: 1.35,
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          for (final lembrete in lembretes) ...[
            _linha(context, lembrete),
            const SizedBox(height: 12),
          ],
          if (temRemedio)
            Text(
              'Para mudar o horário de um remédio, use "Meus remédios" na '
              'Minha Rotina.',
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

// Um lembrete: o horario grande, o que fazer e, nos de glicemia e insulina, o
// botao para mudar o horario (e, depois de mudar, o de voltar ao padrao). O
// leitor de tela le "Tomar Losartana 50 mg, as 8 horas" de uma vez.
class _LinhaDeLembrete extends StatelessWidget {
  final Lembrete lembrete;
  final VoidCallback? aoMudarHorario;
  // O horario padrao do momento, so quando o aviso esta fora dele.
  final String? horarioPadrao;
  final VoidCallback? aoVoltarAoPadrao;

  const _LinhaDeLembrete({
    required this.lembrete,
    this.aoMudarHorario,
    this.horarioPadrao,
    this.aoVoltarAoPadrao,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              label: '${lembrete.resumo}, às ${falarHorario(lembrete.horario)}',
              child: ExcludeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lembrete.horario,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          lembrete.resumo,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (aoMudarHorario != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: aoMudarHorario,
                icon: const Icon(Icons.schedule_rounded),
                label: const Text('Mudar horário'),
              ),
            ],
            if (horarioPadrao != null && aoVoltarAoPadrao != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: aoVoltarAoPadrao,
                icon: const Icon(Icons.restore_rounded),
                label: Text('Voltar para $horarioPadrao'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
