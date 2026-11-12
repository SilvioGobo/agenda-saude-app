import 'package:flutter/material.dart';

import '../../core/theme/app_cores.dart';

// "ALERGIA A AMENDOIM", em vermelho com icone (nunca so a cor): marca o
// alimento ou o remedio que tem algo a que o paciente disse ter alergia, na
// busca e na refeicao ou no remedio ja escolhido.
class SeloAlergia extends StatelessWidget {
  final String alergia;

  const SeloAlergia(this.alergia, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.warning_rounded, color: AppCores.perigo, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'ALERGIA A ${alergia.toUpperCase()}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppCores.perigo,
            ),
          ),
        ),
      ],
    );
  }
}

// Pergunta antes de escolher algo a que o paciente disse ter alergia. O botao
// cheio e o seguro ("Escolher outro"); continuar exige o botao de baixo, em
// vermelho. Retorna true so se ele quiser continuar mesmo assim.
Future<bool> confirmarApesarDaAlergia(
  BuildContext context, {
  required String alergia,
  required String mensagem,
  required String rotuloContinuar,
}) async {
  final continuar = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_rounded,
                  color: AppCores.perigo,
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'ALERGIA A ${alergia.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppCores.perigo,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(mensagem, style: const TextStyle(fontSize: 18, height: 1.35)),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              icon: const Icon(Icons.search_rounded),
              label: const Text('Escolher outro'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: OutlinedButton.styleFrom(foregroundColor: AppCores.perigo),
              child: Text(rotuloContinuar, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    ),
  );
  return continuar ?? false;
}
