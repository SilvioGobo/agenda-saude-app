import 'package:flutter/material.dart';

// Card com a situacao da localizacao quando nao ha um local para mostrar:
// compartilhamento desligado, falta de permissao, GPS desligado, aguardando a
// primeira posicao... Icone grande num circulo, titulo, explicacao e a acao
// que resolve, no mesmo padrao do card que ocupa o lugar do BPM no painel do
// paciente. Problemas usam a cor de aviso e ganham borda.
class CardSituacaoLocalizacao extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String descricao;
  final Color cor;
  final Widget? acao;
  final bool destacarBorda;

  const CardSituacaoLocalizacao({
    super.key,
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.cor,
    this.acao,
    this.destacarBorda = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: destacarBorda
            ? BorderSide(color: cor, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icone, size: 44, color: cor),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              descricao,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                height: 1.35,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (acao != null) ...[
              const SizedBox(height: 20),
              acao!,
            ],
          ],
        ),
      ),
    );
  }
}
