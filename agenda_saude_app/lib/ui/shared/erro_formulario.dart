import 'package:flutter/material.dart';

import '../../core/theme/app_cores.dart';

// Erro de um formulario da rotina: caixa alta, icone e vermelho (nunca so a
// cor), anunciado pelo leitor de tela assim que aparece. E o mesmo visual dos
// erros da tela de glicemia e insulina.
class ErroFormulario extends StatelessWidget {
  final String texto;

  const ErroFormulario(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: texto,
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_rounded, color: AppCores.perigo, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                texto.toUpperCase(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppCores.perigo,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
