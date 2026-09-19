import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Card do painel do paciente com o codigo que o acompanhante digita para se
// vincular a ele (RF05.4). Letras grandes e espacadas para ser lido em voz
// alta ou de longe; o botao copia para enviar por mensagem.
class CardCodigoVinculo extends StatelessWidget {
  final String codigo;

  const CardCodigoVinculo({super.key, required this.codigo});

  Future<void> _copiar(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: codigo));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código copiado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
        child: Row(
          children: [
            Icon(Icons.key_rounded, size: 32, color: colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Código para o acompanhante',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    codigo.isEmpty ? 'Indisponível' : codigo,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            if (codigo.isNotEmpty)
              IconButton(
                tooltip: 'Copiar código',
                iconSize: 28,
                onPressed: () => _copiar(context),
                icon: const Icon(Icons.copy_rounded),
              ),
          ],
        ),
      ),
    );
  }
}
