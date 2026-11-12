import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/remedios_repository.dart';
import '../../domain/medicacao/catalogo_remedios.dart';
import '../../domain/medicacao/remedio.dart';
import '../shared/aviso_alergia.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/titulo_tela.dart';
import 'buscar_remedio_viewmodel.dart';

// Busca de remedios pelo nome da caixa ou pelo principio ativo, no molde da
// busca de alimentos: ao tocar num remedio a tela fecha e devolve esse
// [Remedio]. Quem nao acha o seu pode usar o nome digitado (sem principio
// ativo). O remedio que tem algo das [alergias] do paciente sai com "ALERGIA
// A ..." e pergunta antes de entrar na lista.
class BuscarRemedioView extends StatelessWidget {
  const BuscarRemedioView({super.key});

  // [catalogo] e o compartilhado do app se ninguem passar outro (os testes
  // passam um pequeno).
  static Widget comProviders({
    Future<CatalogoRemedios>? catalogo,
    List<String> alergias = const [],
  }) {
    return ChangeNotifierProvider(
      create: (_) => BuscarRemedioViewModel(
        catalogo ?? RemediosRepository.compartilhado.carregar(),
        alergias: alergias,
      ),
      child: const BuscarRemedioView(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BuscarRemedioViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final digitado = viewModel.digitado;

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
                  const TituloTela('Escolher remédio'),
                  const SizedBox(height: 16),
                  TextField(
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        BuscarRemedioViewModel.tamanhoMaximoNome,
                      ),
                    ],
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'Nome do remédio',
                      hintText: 'Ex.: losartana, Glifage',
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
                  if (viewModel.carregando)
                    const _Carregando()
                  else if (viewModel.erroAoCarregar)
                    const _Aviso(
                      'A lista de remédios não abriu. Digite o nome do '
                      'remédio e toque em "Usar".',
                    )
                  else if (!viewModel.buscou)
                    const _Aviso(
                      'Digite o nome que está na caixa do remédio ou o '
                      'princípio ativo. Pode ser só o começo, como "losar".',
                    )
                  else if (viewModel.resultados.isEmpty)
                    _Aviso(
                      'Nenhum remédio encontrado para '
                      '"${viewModel.consulta.trim()}".',
                    )
                  else
                    for (final remedio in viewModel.resultados) ...[
                      _LinhaRemedio(
                        remedio: remedio,
                        alergia: viewModel.alergiaDe(remedio),
                      ),
                      const SizedBox(height: 8),
                    ],
                  if (!viewModel.carregando && digitado != null) ...[
                    const SizedBox(height: 16),
                    _UsarDigitado(
                      remedio: digitado,
                      alergia: viewModel.alergiaDe(digitado),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Lista de medicamentos com registro ativo na Anvisa '
                    '(dados abertos, novembro de 2026).',
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

// Fecha devolvendo [remedio]; se ele tem algo de [alergia], pergunta antes.
Future<void> _escolher(
  BuildContext context,
  Remedio remedio,
  String? alergia,
) async {
  if (alergia != null) {
    final continuar = await confirmarApesarDaAlergia(
      context,
      alergia: alergia,
      mensagem:
          'Você informou alergia a ${alergia.toLowerCase()}, e '
          '"${remedio.nome}" tem ${alergia.toLowerCase()}. Fale com seu '
          'médico antes de tomar. Quer pôr este remédio na lista mesmo assim?',
      rotuloContinuar: 'Pôr na lista mesmo assim',
    );
    if (!continuar || !context.mounted) return;
  }
  Navigator.of(context).pop(remedio);
}

class _Carregando extends StatelessWidget {
  const _Carregando();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 24),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Abrindo a lista de remédios...',
            style: TextStyle(fontSize: 18),
          ),
        ],
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

// Um resultado: a linha inteira e o botao (72dp ou mais), com o nome e os
// principios ativos.
class _LinhaRemedio extends StatelessWidget {
  final Remedio remedio;
  // A alergia do paciente que o remedio tem; null = nenhuma.
  final String? alergia;

  const _LinhaRemedio({required this.remedio, this.alergia});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final substancias = remedio.descricaoSubstancias;
    final detalhe = substancias.isEmpty
        ? ''
        : (remedio.substancias.length == 1
              ? 'Princípio ativo: $substancias'
              : 'Princípios ativos: $substancias');
    final avisoAlergia = alergia == null ? '' : ' Atenção: alergia a $alergia.';

    return Semantics(
      button: true,
      label:
          '${remedio.nome}. ${detalhe.isEmpty ? '' : '$detalhe.'}'
          '$avisoAlergia Toque para escolher.',
      excludeSemantics: true,
      onTap: () => _escolher(context, remedio, alergia),
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _escolher(context, remedio, alergia),
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
                    remedio.nome,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (detalhe.isNotEmpty)
                    Text(
                      detalhe,
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (alergia != null) ...[
                    const SizedBox(height: 4),
                    SeloAlergia(alergia!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// "Não achou o seu?" e o botao que usa o nome digitado, sem principio ativo.
class _UsarDigitado extends StatelessWidget {
  final Remedio remedio;
  final String? alergia;

  const _UsarDigitado({required this.remedio, this.alergia});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Não achou o seu?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _escolher(context, remedio, alergia),
          icon: const Icon(Icons.edit_rounded),
          label: Text('Usar "${remedio.nome}"'),
        ),
      ],
    );
  }
}
