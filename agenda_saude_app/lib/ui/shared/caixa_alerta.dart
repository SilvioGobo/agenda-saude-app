import 'package:flutter/material.dart';

import '../../core/theme/app_cores.dart';

// Caixa vermelha de alerta de saude com titulo e orientacao (ex.: BPM fora
// da zona de seguranca no painel do paciente). Cor, icone e titulo em
// maiusculas indicam o alerta juntos - nunca so a cor - e o leitor de tela
// anuncia o alerta assim que ele aparece (liveRegion).
class CaixaAlerta extends StatelessWidget {
  final String titulo;
  final String mensagem;
  final IconData icone;

  const CaixaAlerta({
    super.key,
    required this.titulo,
    required this.mensagem,
    this.icone = Icons.warning_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppCores.perigoContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppCores.perigo, width: 3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icone, color: AppCores.perigo, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppCores.perigo,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              mensagem,
              style: const TextStyle(
                fontSize: 18,
                height: 1.35,
                color: AppCores.onPerigoContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
