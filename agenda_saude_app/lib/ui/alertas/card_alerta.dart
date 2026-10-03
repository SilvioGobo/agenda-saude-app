import 'package:flutter/material.dart';

import '../../domain/models/alerta.dart';

// Cor, icone e rotulo de cada nivel de alerta. "ATENÇÃO" usa o mesmo icone e
// o mesmo vermelho do selo de status do painel do paciente (Figura 13), para
// os dois perfis reconhecerem o mesmo aviso; os tons mais escuros garantem o
// contraste do texto pequeno (NF004).
({String rotulo, IconData icone, Color cor}) estiloDoAlerta(Alerta alerta) {
  if (alerta.ehEmergencia) {
    return (
      rotulo: 'EMERGÊNCIA',
      icone: Icons.emergency_rounded,
      cor: Colors.red.shade900,
    );
  }
  return (
    rotulo: 'ATENÇÃO',
    icone: Icons.warning_rounded,
    cor: Colors.red.shade700,
  );
}

// "Agora mesmo", "Há 5 minutos", "Hoje às 14:32", "Ontem às 09:10" ou
// "18/09 às 21:05".
String descreverHorario(DateTime dataHora, {DateTime? agora}) {
  final referencia = agora ?? DateTime.now();
  final diferenca = referencia.difference(dataHora);
  if (diferenca.inMinutes < 1) return 'Agora mesmo';
  if (diferenca.inMinutes < 60) {
    final minutos = diferenca.inMinutes;
    return 'Há $minutos ${minutos == 1 ? 'minuto' : 'minutos'}';
  }

  String doisDigitos(int valor) => valor.toString().padLeft(2, '0');
  final hora = '${doisDigitos(dataHora.hour)}:${doisDigitos(dataHora.minute)}';
  final hoje = DateTime(referencia.year, referencia.month, referencia.day);
  final dia = DateTime(dataHora.year, dataHora.month, dataHora.day);
  final dias = (hoje.difference(dia).inHours / 24).round();
  if (dias == 0) return 'Hoje às $hora';
  if (dias == 1) return 'Ontem às $hora';
  return '${doisDigitos(dia.day)}/${doisDigitos(dia.month)} às $hora';
}

// Item da tela de Notificacoes do acompanhante (RF06). Alerta nao lido ganha
// o mesmo destaque do selo de status (fundo tingido e borda na cor do nivel).
class CardAlerta extends StatelessWidget {
  final Alerta alerta;
  final String nomePaciente;
  final VoidCallback? onTap;
  final DateTime? agora;

  const CardAlerta({
    super.key,
    required this.alerta,
    required this.nomePaciente,
    this.onTap,
    this.agora,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final estilo = estiloDoAlerta(alerta);
    final naoLido = !alerta.lido;

    return Card(
      color: naoLido ? estilo.cor.withValues(alpha: 0.08) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: naoLido
            ? BorderSide(color: estilo.cor, width: 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emergencia ganha o circulo cheio para se destacar da atencao,
              // que usa o mesmo vermelho em tom mais claro.
              CircleAvatar(
                radius: 26,
                backgroundColor: alerta.ehEmergencia
                    ? estilo.cor
                    : estilo.cor.withValues(alpha: 0.15),
                child: Icon(
                  estilo.icone,
                  color: alerta.ehEmergencia ? Colors.white : estilo.cor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            estilo.rotulo,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: estilo.cor,
                            ),
                          ),
                        ),
                        if (naoLido)
                          Semantics(
                            label: 'Não lida',
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: estilo.cor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nomePaciente,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(alerta.mensagem, style: const TextStyle(fontSize: 17)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          descreverHorario(alerta.dataHora, agora: agora),
                          style: TextStyle(
                            fontSize: 15,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
