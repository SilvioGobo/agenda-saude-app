import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/alimentos/catalogo_alimentos.dart';
import '../../domain/medicacao/catalogo_remedios.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/titulo_tela.dart';
import 'buscar_alergia_viewmodel.dart';

// Escolher uma alergia numa lista, como se escolhe o alimento da refeicao ou o
// remedio: digita, toca na opcao e a tela fecha devolvendo o nome (String).
// A alimentos, a lista e a da TACO sem o preparo ("Camarão" uma vez so); a
// remedios, os principios ativos da lista da Anvisa, achados tambem pelo nome
// da caixa ("Novalgina" acha "Dipirona").
class BuscarAlergiaView extends StatelessWidget {
  final String titulo;
  final String explicacao;
  final String rotuloCampo;
  final String exemplo;
  final String fonte;

  const BuscarAlergiaView({
    super.key,
    required this.titulo,
    required this.explicacao,
    required this.rotuloCampo,
    required this.exemplo,
    required this.fonte,
  });

  static Widget alimentos(Future<CatalogoAlimentos> catalogo) {
    return ChangeNotifierProvider(
      create: (_) => BuscarAlergiaViewModel(
        catalogo.then(
          (catalogo) =>
              (consulta) => [
                for (final nome in catalogo.buscarAlergias(consulta))
                  OpcaoDeAlergia(nome),
              ],
        ),
      ),
      child: const BuscarAlergiaView(
        titulo: 'Alergia a alimento',
        explicacao:
            'O aviso vale para todo alimento com esse nome: "Camarão" avisa '
            'no camarão cru, cozido ou frito.',
        rotuloCampo: 'Nome do alimento',
        exemplo: 'Ex.: amendoim, camarão, leite',
        fonte:
            'Alimentos da Tabela Brasileira de Composição de Alimentos '
            '(TACO), 4ª edição, NEPA/UNICAMP, 2011.',
      ),
    );
  }

  static Widget remedios(Future<CatalogoRemedios> catalogo) {
    return ChangeNotifierProvider(
      create: (_) => BuscarAlergiaViewModel(
        catalogo.then(
          (catalogo) =>
              (consulta) => [
                for (final achada in catalogo.buscarSubstancias(consulta))
                  OpcaoDeAlergia(
                    achada.nome,
                    detalhe: achada.remedio == null
                        ? 'Princípio ativo'
                        : 'Princípio ativo do ${achada.remedio}',
                  ),
              ],
        ),
      ),
      child: const BuscarAlergiaView(
        titulo: 'Alergia a remédio',
        explicacao:
            'Escolha o princípio ativo, a substância do remédio. Se não '
            'souber, digite o nome da caixa, como "Novalgina".',
        rotuloCampo: 'Remédio ou princípio ativo',
        exemplo: 'Ex.: dipirona, amoxicilina',
        fonte:
            'Lista de medicamentos com registro ativo na Anvisa (dados '
            'abertos, novembro de 2026).',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BuscarAlergiaViewModel>();
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
                  TituloTela(titulo, subtitulo: explicacao),
                  const SizedBox(height: 16),
                  TextField(
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      labelText: rotuloCampo,
                      hintText: exemplo,
                      prefixIcon: const Icon(Icons.search_rounded),
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
                  if (viewModel.carregando)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (viewModel.erroAoCarregar)
                    const _Aviso('A lista não abriu. Volte e tente de novo.')
                  else if (!viewModel.buscou)
                    const _Aviso(
                      'Digite o nome para procurar. Pode ser só o começo, '
                      'como "camar".',
                    )
                  else if (viewModel.resultados.isEmpty)
                    _Aviso(
                      'Nada encontrado para "${viewModel.consulta.trim()}". '
                      'Tente outra palavra ou escreva em "Outras alergias".',
                    )
                  else
                    for (final opcao in viewModel.resultados) ...[
                      _LinhaOpcao(opcao: opcao),
                      const SizedBox(height: 8),
                    ],
                  const SizedBox(height: 16),
                  Text(
                    fonte,
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
class _LinhaOpcao extends StatelessWidget {
  final OpcaoDeAlergia opcao;

  const _LinhaOpcao({required this.opcao});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final detalhe = opcao.detalhe;

    return Semantics(
      button: true,
      label:
          '${opcao.nome}${detalhe == null ? '' : ', $detalhe'}. '
          'Toque para escolher.',
      excludeSemantics: true,
      onTap: () => Navigator.of(context).pop(opcao.nome),
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => Navigator.of(context).pop(opcao.nome),
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
                    opcao.nome,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (detalhe != null)
                    Text(
                      detalhe,
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
