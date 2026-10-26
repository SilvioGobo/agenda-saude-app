import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/alimentos/alimento.dart';
import '../../domain/alimentos/catalogo_alimentos.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/titulo_tela.dart';
import 'buscar_alimento_viewmodel.dart';

// Busca de alimentos por nome, para montar uma refeicao. Ao tocar num alimento
// a tela fecha e devolve esse [Alimento] a quem a abriu. A lista e a TACO
// (NEPA/UNICAMP), citada no rodape como a licenca da tabela pede.
class BuscarAlimentoView extends StatelessWidget {
  const BuscarAlimentoView({super.key});

  static Widget comProviders(CatalogoAlimentos catalogo) {
    return ChangeNotifierProvider(
      create: (_) => BuscarAlimentoViewModel(catalogo),
      child: const BuscarAlimentoView(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BuscarAlimentoViewModel>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: BotaoBarraSuperior.largura,
        leading: BotaoBarraSuperior.voltar(
          aoTocar: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TituloTela('Escolher alimento'),
                  const SizedBox(height: 16),
                  TextField(
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'Nome do alimento',
                      hintText: 'Ex.: arroz, banana, frango',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: viewModel.definirConsulta,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                children: [
                  if (!viewModel.buscou)
                    _Aviso(
                      'Digite o nome do alimento para procurar. Você pode '
                      'digitar só o começo das palavras, como "feij coz".',
                    )
                  else if (viewModel.resultados.isEmpty)
                    _Aviso(
                      'Nenhum alimento encontrado para "${viewModel.consulta.trim()}". '
                      'Tente outra palavra.',
                    )
                  else
                    for (final alimento in viewModel.resultados) ...[
                      _LinhaAlimento(alimento: alimento),
                      const SizedBox(height: 8),
                    ],
                  const SizedBox(height: 16),
                  Text(
                    'Valores por 100 g da Tabela Brasileira de Composição de '
                    'Alimentos (TACO), 4ª edição, NEPA/UNICAMP, 2011.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.35,
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

class _Aviso extends StatelessWidget {
  final String texto;

  const _Aviso(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 18,
          height: 1.35,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// Um resultado: a linha inteira e o botao (72dp ou mais).
class _LinhaAlimento extends StatelessWidget {
  final Alimento alimento;

  const _LinhaAlimento({required this.alimento});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final detalhe = '${alimento.kcal} kcal por 100 g';

    return Semantics(
      button: true,
      label: '${alimento.nome}, $detalhe. Toque para escolher.',
      excludeSemantics: true,
      onTap: () => Navigator.of(context).pop(alimento),
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => Navigator.of(context).pop(alimento),
          borderRadius: BorderRadius.circular(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    alimento.nome,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    alimento.grupo == null
                        ? detalhe
                        : '$detalhe · ${alimento.grupo}',
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
