import 'package:flutter/material.dart';

import '../../core/theme/app_cores.dart';

// Corpo das telas com a `BarraSuperiorFormulario`. O que impede de salvar (uma
// pergunta sem resposta, a falta de conexao) aparece numa faixa vermelha fixa
// logo abaixo da barra, perto do "Salvar" que a pessoa acabou de tocar, mesmo
// com a tela rolada ate o fim; o conteudo rola embaixo dela. As perguntas sem
// resposta continuam marcadas tambem no lugar delas.
class CorpoFormulario extends StatelessWidget {
  final String? erro;
  final Widget child;

  const CorpoFormulario({super.key, required this.erro, required this.child});

  @override
  Widget build(BuildContext context) {
    final erro = this.erro;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (erro != null) _FaixaErro(erro),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// Icone e texto (nunca so a cor), anunciada pelo leitor de tela assim que
// aparece.
class _FaixaErro extends StatelessWidget {
  final String texto;

  const _FaixaErro(this.texto);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: texto,
      child: ExcludeSemantics(
        child: Container(
          color: AppCores.perigoContainer,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_rounded, color: AppCores.perigo, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  texto,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                    color: AppCores.onPerigoContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
