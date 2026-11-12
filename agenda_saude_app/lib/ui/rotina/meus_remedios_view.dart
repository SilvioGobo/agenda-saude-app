import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../../domain/medicacao/catalogo_remedios.dart';
import '../../domain/medicacao/remedio.dart';
import '../shared/aviso_alergia.dart';
import '../shared/barra_acoes.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/erro_formulario.dart';
import '../shared/seletor_horario.dart';
import '../shared/titulo_tela.dart';
import 'buscar_remedio_view.dart';
import 'medicacao_viewmodel.dart';
import 'meus_remedios_viewmodel.dart';

// "Meus remedios" (RF003, Figura 14): onde o paciente cadastra os remedios que
// toma, com a dose e os horarios de cada um. Na rotina ele so marca "tomado" a
// cada dose. O remedio e escolhido na lista da Anvisa (`BuscarRemedioView`) e
// cada horario no relogio (`mostrarSeletorDeHorario`), sem digitar. Salvar e
// Cancelar ficam fixos na base, como em "Minhas refeicoes".
class MeusRemediosView extends StatelessWidget {
  // Catalogo de remedios da busca; null = o do app (os testes passam outro).
  final Future<CatalogoRemedios> Function()? carregarCatalogo;

  const MeusRemediosView({super.key, this.carregarCatalogo});

  // Abre a tela editando os remedios que a rotina esta mostrando. [alergias]
  // vem de quem abre quando o paciente pode te-las mudado depois de a rotina
  // ser criada ("Minhas alergias", na mesma tela de Personalizar rotina).
  static Widget comProviders(
    MedicacaoViewModel rotina, {
    List<String>? alergias,
    Future<CatalogoRemedios> Function()? carregarCatalogo,
  }) {
    return ChangeNotifierProvider(
      create: (_) => MeusRemediosViewModel(
        atual: rotina.medicamentos,
        aoSalvar: rotina.salvarMedicamentos,
        alergias: alergias ?? rotina.paciente.alergiasRemedios,
      ),
      child: MeusRemediosView(carregarCatalogo: carregarCatalogo),
    );
  }

  // Abre a busca de remedios e devolve o escolhido (null = voltou sem
  // escolher).
  static Future<Remedio?> escolherRemedio(
    BuildContext context, {
    required List<String> alergias,
    Future<CatalogoRemedios> Function()? carregarCatalogo,
  }) {
    return Navigator.of(context).push<Remedio>(
      MaterialPageRoute(
        builder: (_) => BuscarRemedioView.comProviders(
          catalogo: carregarCatalogo?.call(),
          alergias: alergias,
        ),
      ),
    );
  }

  Future<void> _adicionar(BuildContext context) async {
    final viewModel = context.read<MeusRemediosViewModel>();
    final escolhido = await escolherRemedio(
      context,
      alergias: viewModel.alergias,
      carregarCatalogo: carregarCatalogo,
    );
    if (escolhido == null || !context.mounted) return;
    viewModel.adicionar(escolhido);
  }

  Future<void> _salvar(BuildContext context) async {
    final salvou = await context.read<MeusRemediosViewModel>().salvar();
    if (!context.mounted || !salvou) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MeusRemediosViewModel>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: BotaoBarraSuperior.largura,
        leading: BotaoBarraSuperior.voltar(
          aoTocar: () => Navigator.of(context).pop(),
        ),
      ),
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
            onPressed: viewModel.salvando ? null : () => _salvar(context),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Salvar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            const TituloTela(
              'Meus remédios',
              subtitulo: 'Escolha cada remédio na lista e diga a dose e os '
                  'horários em que você toma. Na rotina, você só marca quando '
                  'tomar.',
            ),
            const SizedBox(height: 24),
            if (viewModel.remedios.isEmpty) ...[
              Text(
                'Você ainda não cadastrou nenhum remédio. Toque em "Adicionar '
                'remédio".',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.35,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
            ],
            for (final remedio in viewModel.remedios) ...[
              _EditorRemedio(
                key: ValueKey(remedio.id),
                remedio: remedio,
                carregarCatalogo: carregarCatalogo,
              ),
              const SizedBox(height: 16),
            ],
            OutlinedButton.icon(
              onPressed:
                  viewModel.podeAdicionar ? () => _adicionar(context) : null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar remédio'),
            ),
            if (!viewModel.podeAdicionar) ...[
              const SizedBox(height: 8),
              Text(
                'Você já tem o máximo de '
                '${MedicacaoViewModel.maximoRemedios} remédios.',
                style: TextStyle(
                  fontSize: 16,
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

// Um remedio: o nome escolhido na lista (com "Trocar"), a dose, os horarios ja
// adicionados e o botao que abre o relogio para adicionar mais um. O campo da
// dose guarda o proprio texto (`initialValue`); o ViewModel recebe cada
// mudanca.
class _EditorRemedio extends StatelessWidget {
  // Onde o relogio abre. Os remedios costumam comecar de manha; se ja houver
  // 08:00, a pessoa so gira o ponteiro.
  static const String horarioInicial = '08:00';

  final RemedioEmEdicao remedio;
  final Future<CatalogoRemedios> Function()? carregarCatalogo;

  const _EditorRemedio({
    super.key,
    required this.remedio,
    this.carregarCatalogo,
  });

  Future<void> _trocar(
    BuildContext context,
    MeusRemediosViewModel viewModel,
  ) async {
    final escolhido = await MeusRemediosView.escolherRemedio(
      context,
      alergias: viewModel.alergias,
      carregarCatalogo: carregarCatalogo,
    );
    if (escolhido == null || !context.mounted) return;
    viewModel.trocarRemedio(remedio, escolhido);
  }

  Future<void> _escolherHorario(
    BuildContext context,
    MeusRemediosViewModel viewModel,
  ) async {
    final horario = await mostrarSeletorDeHorario(
      context,
      inicial: horarioInicial,
      titulo: 'HORÁRIO DO REMÉDIO',
    );
    if (horario == null || !context.mounted) return;
    viewModel.adicionarHorario(remedio, horario);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<MeusRemediosViewModel>();
    // Observa para refazer a lista de horarios e o aviso quando mudam.
    context.watch<MeusRemediosViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final alergia = viewModel.alergiaDe(remedio);
    final substancias = Remedio(
      nome: remedio.nome,
      substancias: remedio.substancias,
    ).descricaoSubstancias;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // O nome nao se digita aqui: "Trocar" abre a busca de novo. Com a
            // fonte do celular muito aumentada o botao desce para a linha de
            // baixo (Wrap), como em _LinhaDeHorario.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      remedio.nome,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (substancias.isNotEmpty)
                      Text(
                        remedio.substancias.length == 1
                            ? 'Princípio ativo: $substancias'
                            : 'Princípios ativos: $substancias',
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _trocar(context, viewModel),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    iconSize: 24,
                  ),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Trocar'),
                ),
              ],
            ),
            if (alergia != null) ...[
              const SizedBox(height: 8),
              SeloAlergia(alergia),
              const SizedBox(height: 4),
              Text(
                'Fale com seu médico antes de tomar este remédio.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.35,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              key: ValueKey('dose-${remedio.id}'),
              initialValue: remedio.dose,
              onChanged: (valor) => viewModel.definirDose(remedio, valor),
              inputFormatters: [
                LengthLimitingTextInputFormatter(
                  MeusRemediosViewModel.tamanhoMaximoDose,
                ),
              ],
              style: const TextStyle(fontSize: 18),
              decoration: const InputDecoration(
                labelText: 'Dose (opcional)',
                hintText: 'Ex.: 50 mg',
              ),
            ),
            const SizedBox(height: 20),
            // O relogio verde de adicionar fica ao lado de "HORÁRIOS". So o
            // icone (o tooltip da o nome ao leitor de tela), diferente do
            // "Adicionar remédio", para os dois botoes nao se confundirem.
            Row(
              children: [
                Flexible(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'HORÁRIOS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  onPressed: viewModel.podeAdicionarHorario(remedio)
                      ? () => _escolherHorario(context, viewModel)
                      : null,
                  tooltip: 'Adicionar horário',
                  iconSize: 28,
                  style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
                  icon: const Icon(Icons.more_time_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (remedio.horarios.isEmpty)
              Text(
                'Nenhum horário ainda. Toque no relógio ao lado de HORÁRIOS '
                'e escolha a hora.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.35,
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final horario in remedio.horarios)
                _LinhaDeHorario(
                  horario: horario,
                  aoRemover: () => viewModel.removerHorario(remedio, horario),
                ),
            if (!viewModel.podeAdicionarHorario(remedio)) ...[
              const SizedBox(height: 8),
              Text(
                'Este remédio já tem o máximo de '
                '${MedicacaoViewModel.maximoHorariosPorRemedio} horários.',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (remedio.erroHorario != null) ...[
              const SizedBox(height: 8),
              ErroFormulario(remedio.erroHorario!),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => viewModel.remover(remedio.id),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  iconSize: 24,
                  foregroundColor: AppCores.perigo,
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remover este remédio'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Um horario ja adicionado: "08:00" grande e o botao "Remover" (48dp). Com a
// fonte do celular muito aumentada o botao nao cabe ao lado do horario e desce
// para a linha de baixo (Wrap), em vez de estourar a largura (NF004).
class _LinhaDeHorario extends StatelessWidget {
  final String horario;
  final VoidCallback aoRemover;

  const _LinhaDeHorario({required this.horario, required this.aoRemover});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule_rounded, size: 28, color: colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                horario,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: aoRemover,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              textStyle:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              iconSize: 24,
              foregroundColor: AppCores.perigo,
            ),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}
