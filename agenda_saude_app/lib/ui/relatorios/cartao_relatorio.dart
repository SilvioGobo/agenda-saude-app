import 'package:flutter/material.dart';

import '../../core/theme/app_cores.dart';

// Blocos de tela compartilhados pelo relatorio do dia e pelo do mes.

// Cabecalho de um cartao: icone num circulo, titulo e, abaixo dele, o resumo
// em uma linha (ex.: "1.750 ml de 2.000 ml"). Mesmo desenho dos cartoes da
// rotina (hidratacao, refeicoes), para o relatorio parecer da mesma familia.
class CabecalhoDoCartao extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String? resumo;

  const CabecalhoDoCartao({
    super.key,
    required this.icone,
    required this.titulo,
    this.resumo,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(icone, size: 32, color: colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              if (resumo != null)
                Text(
                  resumo!,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// Cartao do relatorio: cabecalho e, embaixo, os [filhos] em coluna.
class CartaoRelatorio extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String? resumo;
  final List<Widget> filhos;

  const CartaoRelatorio({
    super.key,
    required this.icone,
    required this.titulo,
    this.resumo,
    this.filhos = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CabecalhoDoCartao(icone: icone, titulo: titulo, resumo: resumo),
            for (final filho in filhos) ...[const SizedBox(height: 16), filho],
          ],
        ),
      ),
    );
  }
}

// Uma linha de informacao com icone e texto (18, quebra de linha ate o fim).
// A cor vale para o icone e para o texto; sem ela usa a cor de texto comum.
class LinhaDoRelatorio extends StatelessWidget {
  final IconData icone;
  final String texto;
  final Color? cor;
  final bool negrito;

  const LinhaDoRelatorio({
    super.key,
    required this.icone,
    required this.texto,
    this.cor,
    this.negrito = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 26, color: cor ?? colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 18,
                height: 1.35,
                fontWeight: negrito ? FontWeight.bold : FontWeight.normal,
                color: cor ?? colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Barra de progresso do cartao, no mesmo estilo da rotina. De 0 a 1.
class BarraDeProgresso extends StatelessWidget {
  final double valor;
  final bool completa;

  const BarraDeProgresso({super.key, required this.valor, this.completa = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: valor,
        minHeight: 16,
        backgroundColor: colorScheme.surfaceContainerHighest,
        color: completa ? AppCores.sucesso : colorScheme.primary,
      ),
    );
  }
}

// Leitura em andamento.
class CarregandoRelatorio extends StatelessWidget {
  const CarregandoRelatorio({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

// A leitura falhou: sem numeros (um relatorio incompleto pareceria que o
// paciente nao fez nada) e um botao grande para tentar de novo. Aviso laranja,
// porque nao e alerta de saude.
class ErroDeRelatorio extends StatelessWidget {
  final VoidCallback aoTentarDeNovo;

  const ErroDeRelatorio({super.key, required this.aoTentarDeNovo});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppCores.avisoContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppCores.aviso, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.cloud_off_rounded, color: AppCores.aviso, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Não foi possível carregar',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppCores.aviso,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Confira se o celular está com internet e tente de novo.',
              style: TextStyle(
                fontSize: 18,
                height: 1.35,
                color: AppCores.onAvisoContainer,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: aoTentarDeNovo,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
