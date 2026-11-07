import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/telefones_emergencia.dart';
import '../../core/services/telefone_service.dart';
import '../../core/theme/app_cores.dart';
import '../../data/repositories/acompanhante_repository.dart';
import '../../domain/models/acompanhante.dart';
import '../../domain/models/paciente.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/botao_ligar.dart';
import '../shared/titulo_tela.dart';
import 'falar_com_acompanhante_viewmodel.dart';

// Tela "Falar com Acompanhante" do paciente (Figura 13: atalho para
// chamadas de emergencia): cada acompanhante vinculado com um botao grande
// para ligar para ele e, no fim, o atalho para o SAMU (192). Do painel ate a
// ligacao sao dois toques: o botao do painel e o "LIGAR" desta tela.
class FalarComAcompanhanteView extends StatelessWidget {
  // Permite aos testes trocar o discador por um falso.
  final TelefoneService? telefoneService;

  const FalarComAcompanhanteView({super.key, this.telefoneService});

  // Os parametros opcionais permitem aos testes montar a tela com
  // repository e discador falsos.
  static Widget comProviders(
    Paciente paciente, {
    AcompanhanteRepository? acompanhanteRepository,
    TelefoneService? telefoneService,
  }) {
    return ChangeNotifierProvider(
      create: (_) => FalarComAcompanhanteViewModel(
        paciente: paciente,
        acompanhanteRepository: acompanhanteRepository,
      )..carregar(),
      child: FalarComAcompanhanteView(telefoneService: telefoneService),
    );
  }

  List<Widget> _acompanhantes(
    BuildContext context,
    FalarComAcompanhanteViewModel viewModel,
  ) {
    if (viewModel.carregando) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (viewModel.erroAoCarregar) {
      return [
        const Text(
          'NÃO FOI POSSÍVEL CARREGAR SEUS ACOMPANHANTES.',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppCores.perigo,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: viewModel.carregar,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('TENTAR DE NOVO'),
        ),
      ];
    }

    if (viewModel.acompanhantes.isEmpty) return const [_SemAcompanhante()];

    return [
      for (final acompanhante in viewModel.acompanhantes) ...[
        _CardAcompanhante(
          acompanhante: acompanhante,
          telefoneService: telefoneService,
        ),
        const SizedBox(height: 16),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FalarComAcompanhanteViewModel>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: BotaoBarraSuperior.largura,
        leading: BotaoBarraSuperior.voltar(
          aoTocar: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            const TituloTela(
              'FALAR COM ACOMPANHANTE',
              subtitulo: 'Toque em LIGAR para chamar quem acompanha você.',
            ),
            const SizedBox(height: 24),
            ..._acompanhantes(context, viewModel),
            const SizedBox(height: 16),
            Text(
              'EMERGÊNCIA',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Se estiver passando mal e ninguém atender, ligue para o SAMU.',
              style: TextStyle(
                fontSize: 18,
                height: 1.35,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            BotaoLigar(
              rotulo: 'LIGAR PARA O SAMU (192)',
              numero: TelefonesEmergencia.samu,
              icone: Icons.emergency_rounded,
              corFundo: AppCores.perigo,
              corTexto: Colors.white,
              telefoneService: telefoneService,
            ),
          ],
        ),
      ),
    );
  }
}

// Um acompanhante: inicial, nome, telefone e o botao verde de ligar. Sem
// telefone cadastrado, diz o que falta no lugar do botao.
class _CardAcompanhante extends StatelessWidget {
  final Acompanhante acompanhante;
  final TelefoneService? telefoneService;

  const _CardAcompanhante({
    required this.acompanhante,
    this.telefoneService,
  });

  String get _nome {
    final nome = acompanhante.nome.trim();
    return nome.isEmpty ? 'Acompanhante' : nome;
  }

  String get _primeiroNome => _nome.split(RegExp(r'\s+')).first;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final telefone = acompanhante.telefone;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    _nome[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nome,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (acompanhante.temTelefone)
                        Text(
                          formatarTelefone(telefone!),
                          style: TextStyle(
                            fontSize: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (acompanhante.temTelefone)
              BotaoLigar(
                rotulo: 'LIGAR PARA ${_primeiroNome.toUpperCase()}',
                numero: telefone!,
                icone: Icons.call_rounded,
                corFundo: AppCores.sucesso,
                corTexto: Colors.white,
                telefoneService: telefoneService,
              )
            else ...[
              const Text(
                'SEM TELEFONE CADASTRADO',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppCores.aviso,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Peça para $_primeiroNome cadastrar o telefone no Agenda '
                'Saúde.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.35,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Paciente sem nenhum acompanhante vinculado: explica como vincular.
class _SemAcompanhante extends StatelessWidget {
  const _SemAcompanhante();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.person_add_alt_1_rounded,
              size: 48,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'VOCÊ AINDA NÃO TEM ACOMPANHANTE',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Passe o seu código de vínculo (Menu > Meu código de vínculo) '
              'para quem vai acompanhar você.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                height: 1.35,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
