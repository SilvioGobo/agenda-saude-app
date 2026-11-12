import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../../domain/alimentos/catalogo_alimentos.dart';
import '../../domain/medicacao/catalogo_remedios.dart';
import '../../domain/models/paciente.dart';
import '../shared/barra_acoes.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/titulo_tela.dart';
import 'minhas_alergias_viewmodel.dart';
import 'secao_alergias.dart';

// "Minhas alergias" (Personalizar rotina): as alergias da triagem, para mudar
// depois. Com elas o app avisa ao escolher um alimento em "Minhas refeicoes"
// ou um remedio em "Meus remedios". Salvar e Cancelar ficam fixos na base,
// como nas outras telas de Personalizar rotina.
class MinhasAlergiasView extends StatelessWidget {
  // Os catalogos das buscas; null = os do app (os testes passam outros).
  final Future<CatalogoAlimentos> Function()? carregarAlimentos;
  final Future<CatalogoRemedios> Function()? carregarRemedios;

  const MinhasAlergiasView({
    super.key,
    this.carregarAlimentos,
    this.carregarRemedios,
  });

  static Widget comProviders(
    Paciente paciente, {
    ValueChanged<Paciente>? aoSalvar,
  }) {
    return ChangeNotifierProvider(
      create: (_) =>
          MinhasAlergiasViewModel(paciente: paciente, aoSalvar: aoSalvar),
      child: const MinhasAlergiasView(),
    );
  }

  Future<void> _salvar(BuildContext context) async {
    final salvou = await context.read<MinhasAlergiasViewModel>().salvar();
    if (!context.mounted || !salvou) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MinhasAlergiasViewModel>();

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
              'Minhas alergias',
              subtitulo:
                  'O app avisa quando você escolher, nas refeições ou nos '
                  'remédios, algo a que você tem alergia.',
            ),
            const SizedBox(height: 24),
            SecaoAlergias(
              alimentos: viewModel.alimentos,
              remedios: viewModel.remedios,
              outras: viewModel.outras,
              aoAdicionarAlimento: viewModel.adicionarAlimento,
              aoTirarAlimento: viewModel.tirarAlimento,
              aoAdicionarRemedio: viewModel.adicionarRemedio,
              aoTirarRemedio: viewModel.tirarRemedio,
              aoMudarOutras: viewModel.definirOutras,
              carregarAlimentos: carregarAlimentos,
              carregarRemedios: carregarRemedios,
            ),
          ],
        ),
      ),
    );
  }
}
