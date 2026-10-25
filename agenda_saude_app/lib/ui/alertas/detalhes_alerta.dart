import 'package:flutter/material.dart';

import '../../domain/models/alerta.dart';
import '../../domain/models/paciente.dart';
import '../localizacao/localizacao_paciente_view.dart';
import 'alertas_viewmodel.dart';
import 'card_alerta.dart';

// Detalhes de uma ocorrencia (RF06.4): o motivo do alerta, a leitura de BPM
// do momento e uma orientacao do que o acompanhante deve fazer. Abrir os
// detalhes, pela lista ou pela notificacao, conta como leitura do alerta.
Future<void> abrirDetalhesDoAlerta(
  BuildContext context,
  AlertasViewModel viewModel,
  Alerta alerta,
) {
  viewModel.marcarComoLido(alerta);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DetalhesAlerta(
      alerta: alerta,
      nomePaciente: viewModel.nomeDoPaciente(alerta.pacienteId),
      paciente: viewModel.pacienteDoAlerta(alerta),
    ),
  );
}

class _DetalhesAlerta extends StatelessWidget {
  final Alerta alerta;
  final String nomePaciente;
  final Paciente? paciente;

  const _DetalhesAlerta({
    required this.alerta,
    required this.nomePaciente,
    this.paciente,
  });

  // Na emergencia o acompanhante precisa saber onde o paciente esta, para ir
  // ate ele ou passar o endereco ao SAMU.
  bool get _mostrarLocalizacao => alerta.ehEmergencia && paciente != null;

  void _verLocalizacao(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocalizacaoPacienteView.comProviders(paciente!),
      ),
    );
  }

  String get _orientacao {
    if (alerta.ehEmergencia) {
      final endereco = _mostrarLocalizacao
          ? ' e informe o endereço que aparece em "Ver localização"'
          : '';
      return 'Os batimentos de $nomePaciente estão fora da zona de segurança '
          'há vários minutos. Ligue agora para saber como está. Se não '
          'atender ou relatar mal-estar, ligue para o SAMU (192)$endereco.';
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
            if (_mostrarLocalizacao) ...[
              // A folha continua aberta por baixo: ao voltar do mapa, a
              // orientacao ainda esta a mao.
              FilledButton.icon(
                onPressed: () => _verLocalizacao(context),
                icon: const Icon(Icons.location_on_rounded),
                label: const Text('Ver localização'),
              ),
              const SizedBox(height: 12),
            ],
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
