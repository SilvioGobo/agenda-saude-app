import 'package:flutter/material.dart';

import '../../core/theme/app_cores.dart';

// Destaque do painel do paciente com o BPM mais recente (Figura 13 do TCC:
// "destaque absoluto para o componente numerico"). Numero em 76, coracao
// num circulo e o horario da medicao, para o paciente saber se a leitura e
// recente. O leitor de tela le "72 batimentos por minuto" em vez de "72 B P M".
class CardBatimentos extends StatelessWidget {
  final int bpm;
  final DateTime medidoEm;
  final bool emAlerta;

  const CardBatimentos({
    super.key,
    required this.bpm,
    required this.medidoEm,
    this.emAlerta = false,
  });

  String _quando(DateTime agora) {
    String doisDigitos(int n) => n.toString().padLeft(2, '0');
    final hora = '${doisDigitos(medidoEm.hour)}:${doisDigitos(medidoEm.minute)}';
    final mesmoDia = medidoEm.year == agora.year &&
        medidoEm.month == agora.month &&
        medidoEm.day == agora.day;
    if (mesmoDia) return 'Medido às $hora';
    return 'Medido em ${doisDigitos(medidoEm.day)}/'
        '${doisDigitos(medidoEm.month)} às $hora';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final corCoracao = emAlerta ? AppCores.perigo : colorScheme.primary;
    final fundoCoracao =
        emAlerta ? AppCores.perigoContainer : colorScheme.primaryContainer;
    final quando = _quando(DateTime.now());

    return Semantics(
      container: true,
      label: 'Seus batimentos: $bpm por minuto. $quando.',
      child: ExcludeSemantics(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              children: [
                Text(
                  'Seus batimentos',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: fundoCoracao,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.favorite_rounded,
                          size: 48,
                          color: corCoracao,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Text(
                        '$bpm',
                        style: TextStyle(
                          fontSize: 76,
                          height: 1,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'BPM',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  quando,
                  style: TextStyle(
                    fontSize: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Ocupa o lugar do BPM quando nao ha leitura para mostrar: smartwatch com
// problema (mensagem + acao para resolver, com borda na cor do aviso) ou
// ainda aguardando a primeira medicao.
class CardSemBatimentos extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String descricao;
  final Color cor;
  final Widget? acao;
  final bool destacarBorda;

  const CardSemBatimentos({
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
