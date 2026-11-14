import 'package:flutter/material.dart';

import '../../core/theme/app_cores.dart';
import '../../data/repositories/alimentos_repository.dart';
import '../../data/repositories/remedios_repository.dart';
import '../../domain/alimentos/catalogo_alimentos.dart';
import '../../domain/medicacao/catalogo_remedios.dart';
import '../shared/aviso_alergia.dart';
import '../shared/rotulo_pergunta.dart';
import 'buscar_alergia_view.dart';

// As alergias do paciente: a alimentos e a remedios, escolhidas nas listas
// (BuscarAlergiaView), e as outras (latex, picada de abelha...), em texto
// livre. A mesma secao na triagem e em "Minhas alergias": quem a usa guarda
// as listas e recebe cada mudanca.
class SecaoAlergias extends StatelessWidget {
  final List<String> alimentos;
  final List<String> remedios;
  final String outras;
  final ValueChanged<String> aoAdicionarAlimento;
  final ValueChanged<String> aoTirarAlimento;
  final ValueChanged<String> aoAdicionarRemedio;
  final ValueChanged<String> aoTirarRemedio;
  final ValueChanged<String> aoMudarOutras;
  // Os catalogos das buscas; null = os do app (os testes passam outros).
  final Future<CatalogoAlimentos> Function()? carregarAlimentos;
  final Future<CatalogoRemedios> Function()? carregarRemedios;

  const SecaoAlergias({
    super.key,
    required this.alimentos,
    required this.remedios,
    required this.outras,
    required this.aoAdicionarAlimento,
    required this.aoTirarAlimento,
    required this.aoAdicionarRemedio,
    required this.aoTirarRemedio,
    required this.aoMudarOutras,
    this.carregarAlimentos,
    this.carregarRemedios,
  });

  Future<void> _escolher(
    BuildContext context,
    Widget busca,
    ValueChanged<String> aoEscolher,
  ) async {
    final nome = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => busca));
    if (nome != null && context.mounted) aoEscolher(nome);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RotuloPergunta('Alergia a alimentos'),
        _Lista(itens: alimentos, aoTirar: aoTirarAlimento),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _escolher(
            context,
            BuscarAlergiaView.alimentos(
              (carregarAlimentos ??
                  AlimentosRepository.compartilhado.carregar)(),
            ),
            aoAdicionarAlimento,
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Adicionar alimento'),
        ),
        const SizedBox(height: 24),
        const RotuloPergunta('Alergia a remédios'),
        _Lista(itens: remedios, aoTirar: aoTirarRemedio),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _escolher(
            context,
            BuscarAlergiaView.remedios(
              (carregarRemedios ?? RemediosRepository.compartilhado.carregar)(),
            ),
            aoAdicionarRemedio,
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Adicionar remédio'),
        ),
        const SizedBox(height: 24),
        const RotuloPergunta('Outras alergias ou restrições'),
        // Uma linha so (cresce se o texto quebrar): o texto fica no meio da
        // caixa, e nao colado no topo de uma caixa de duas linhas.
        TextFormField(
          initialValue: outras,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontSize: 18),
          decoration: const InputDecoration(
            hintText: 'Ex.: látex, picada de abelha',
          ),
          onChanged: aoMudarOutras,
        ),
      ],
    );
  }
}

class _Lista extends StatelessWidget {
  final List<String> itens;
  final ValueChanged<String> aoTirar;

  const _Lista({required this.itens, required this.aoTirar});

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) {
      return Text(
        'Nenhuma.',
        style: TextStyle(
          fontSize: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in itens) ...[
          ItemDaLista(texto: item, aoTirar: () => aoTirar(item)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// Um item escolhido numa lista (uma alergia, um remedio em uso) com o botao
// "Tirar" e, quando [alergia] vem, o aviso de alergia embaixo.
class ItemDaLista extends StatelessWidget {
  final String texto;
  final String? alergia;
  final VoidCallback aoTirar;

  const ItemDaLista({
    super.key,
    required this.texto,
    this.alergia,
    required this.aoTirar,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  texto,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: aoTirar,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  foregroundColor: AppCores.perigo,
                ),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Tirar'),
              ),
            ],
          ),
          if (alergia != null)
            Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 8),
              child: SeloAlergia(alergia!),
            ),
        ],
      ),
    );
  }
}
