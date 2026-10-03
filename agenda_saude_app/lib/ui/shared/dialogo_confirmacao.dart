import 'package:flutter/material.dart';

// Pergunta de confirmacao antes de uma acao importante (ex.: sair da conta).
// Diferente do AlertDialog padrao, os botoes ocupam a largura toda e tem a
// altura dos botoes do tema (56dp), um embaixo do outro - os TextButton
// pequenos do canto do AlertDialog sao dificeis de acertar para idosos.
// Retorna true so se o usuario confirmar.
Future<bool> mostrarDialogoConfirmacao(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  required String rotuloConfirmar,
  required IconData iconeConfirmar,
  String rotuloCancelar = 'Cancelar',
}) async {
  final confirmou = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              titulo,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(mensagem, style: const TextStyle(fontSize: 18, height: 1.35)),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: Icon(iconeConfirmar),
              label: Text(rotuloConfirmar),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(rotuloCancelar),
            ),
          ],
        ),
      ),
    ),
  );
  return confirmou ?? false;
}
