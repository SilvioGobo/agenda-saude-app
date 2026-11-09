import 'package:flutter/material.dart';

import '../../domain/models/alerta.dart';
import '../localizacao/localizacao_paciente_view.dart';
import '../shared/rota_com_narrador.dart';
import 'alertas_viewmodel.dart';
import 'card_alerta.dart';
import 'emergencia_view.dart';

// Detalhes de uma ocorrencia (RF06.4), pela lista ou pela notificacao. A
// emergencia abre a tela cheia vermelha com os botoes de ligar (Figura 16);
// o alerta de atencao abre uma folha com o motivo, a leitura de BPM do
// momento e uma orientacao do que o acompanhante deve fazer. Abrir os
// detalhes conta como leitura do alerta.
Future<void> abrirDetalhesDoAlerta(
  BuildContext context,
  AlertasViewModel viewModel,
  Alerta alerta,
) {
  viewModel.marcarComoLido(alerta);
  final nomePaciente = viewModel.nomeDoPaciente(alerta.pacienteId);

  if (alerta.ehEmergencia) {
    final paciente = viewModel.pacienteDoAlerta(alerta);
    return Navigator.of(context).push(
      // Leva junto o narrador, se houver, para a emergencia ser falada.
      rotaComNarrador<void>(
        context,
        EmergenciaView(
          alerta: alerta,
          nomePaciente: nomePaciente,
          paciente: paciente,
          // O acompanhante precisa saber onde o paciente esta, para ir ate
          // ele ou passar o endereco ao SAMU.
          telaDeLocalizacao: paciente == null
              ? null
              : (_) => LocalizacaoPacienteView.comProviders(paciente),
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DetalhesAlerta(alerta: alerta, nomePaciente: nomePaciente),
  );
}

class _DetalhesAlerta extends StatelessWidget {
  final Alerta alerta;
  final String nomePaciente;

  const _DetalhesAlerta({required this.alerta, required this.nomePaciente});

  String get _orientacao {
    if (alerta.ehPendencia) {
      return 'Ligue ou mande uma mensagem para lembrar $nomePaciente da '
          'atividade. Se já foi feita, peça para marcar em Minha Rotina, para '
          'o relatório ficar certo.';
    }
    if (alerta.ehSemDados) {
      return 'Sem as medições, o app não consegue avisar se os batimentos de '
          '$nomePaciente saírem da zona de segurança. Ligue e peça para colocar '
          'o relógio no pulso e abrir o Agenda Saúde.';
    }
    return 'Os batimentos de $nomePaciente saíram da zona de segurança. Entre '
        'em contato para saber como está se sentindo. Se continuar assim por '
        'alguns minutos, você receberá um alerta de emergência.';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final estilo = estiloDoAlerta(alerta);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(estilo.icone, color: estilo.cor, size: 32),
                const SizedBox(width: 10),
                Text(
                  estilo.rotulo,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: estilo.cor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              nomePaciente,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              descreverHorario(alerta.dataHora),
              style: TextStyle(
                fontSize: 17,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (alerta.bpm != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: estilo.cor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: estilo.cor, width: 2),
                ),
                child: Column(
                  children: [
                    Icon(Icons.favorite_rounded, size: 32, color: estilo.cor),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(color: estilo.cor),
                        children: [
                          TextSpan(
                            text: '${alerta.bpm}',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(
                            text: ' BPM',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(alerta.mensagem, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            const Text(
              'O que fazer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(_orientacao, style: const TextStyle(fontSize: 17)),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendi'),
            ),
          ],
        ),
      ),
    );
  }
}
