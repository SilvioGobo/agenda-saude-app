import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/health_service.dart';
import '../../core/services/leitura_segundo_plano_service.dart';
import '../../core/theme/app_cores.dart';
import 'teste_segundo_plano_viewmodel.dart';

// Cartao do teste B2 do roteiro (RF04.2) na tela "Meu smartwatch". So
// aparece rodando o app com `--dart-define=TESTE_B2=true`: e ferramenta
// para quem faz o teste no aparelho real, nao para o paciente. O passo a
// passo esta em docs/b2-bpm-app-fechado.md.
class CardTesteSegundoPlano extends StatelessWidget {
  const CardTesteSegundoPlano({super.key});

  static const bool habilitado = bool.fromEnvironment('TESTE_B2');

  // Os parametros opcionais permitem aos testes usar servicos falsos.
  static Widget comProviders({
    HealthService? healthService,
    LeituraSegundoPlanoService? leituraSegundoPlano,
  }) {
    return ChangeNotifierProvider(
      create: (_) => TesteSegundoPlanoViewModel(
        healthService: healthService,
        leituraSegundoPlano: leituraSegundoPlano,
      )..verificar(),
      child: const CardTesteSegundoPlano(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TesteSegundoPlanoViewModel>();
    final colorScheme = Theme.of(context).colorScheme;
    final mensagem = viewModel.mensagem;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppCores.aviso, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'TESTE B2: BPM COM O APP FECHADO',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Ferramenta de teste (--dart-define=TESTE_B2=true). Passo a '
              'passo em docs/b2-bpm-app-fechado.md.',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (viewModel.verificando)
              const Center(child: CircularProgressIndicator())
            else ...[
              _Situacao(
                rotulo: 'Recurso no Health Connect',
                valor: viewModel.disponivel,
                sim: 'DISPONÍVEL',
                nao: 'INDISPONÍVEL',
              ),
              _Situacao(
                rotulo: 'Permissão de ler com o app fechado',
                valor: viewModel.permissaoConcedida,
                sim: 'CONCEDIDA',
                nao: 'NÃO CONCEDIDA',
              ),
              _Situacao(
                rotulo: 'Leitura a cada 15 minutos',
                valor: viewModel.ligado,
                sim: 'LIGADA',
                nao: 'DESLIGADA',
              ),
              const SizedBox(height: 12),
              if (viewModel.disponivel == true &&
                  viewModel.permissaoConcedida != true) ...[
                FilledButton(
                  onPressed: viewModel.pedirPermissao,
                  child: const Text('PEDIR PERMISSÃO'),
                ),
                const SizedBox(height: 12),
              ],
              if (viewModel.ligado == true)
                OutlinedButton(
                  onPressed: viewModel.desligar,
                  child: const Text('DESLIGAR LEITURA'),
                )
              else
                FilledButton(
                  onPressed: viewModel.ligar,
                  child: const Text('LIGAR LEITURA A CADA 15 MIN'),
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: viewModel.lerUmaVezAgora,
                child: const Text('LER UMA VEZ EM SEGUNDO PLANO'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: viewModel.verificar,
                child: const Text('VERIFICAR DE NOVO'),
              ),
            ],
            if (mensagem != null) ...[
              const SizedBox(height: 12),
              Text(mensagem, style: const TextStyle(fontSize: 16)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Situacao extends StatelessWidget {
  final String rotulo;
  final bool? valor;
  final String sim;
  final String nao;

  const _Situacao({
    required this.rotulo,
    required this.valor,
    required this.sim,
    required this.nao,
  });

  @override
  Widget build(BuildContext context) {
    final valor = this.valor;
    final cor = valor == null
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : (valor ? AppCores.sucesso : AppCores.aviso);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(rotulo, style: const TextStyle(fontSize: 16))),
          const SizedBox(width: 12),
          Text(
            valor == null ? '?' : (valor ? sim : nao),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }
}
