import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/mapa_service.dart';
import '../../core/theme/app_cores.dart';
import '../../data/repositories/localizacao_repository.dart';
import '../../domain/models/paciente.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/botao_grande.dart';
import '../shared/titulo_tela.dart';
import 'card_situacao_localizacao.dart';
import 'localizacao_paciente_viewmodel.dart';

// "Atualizado há 3 minutos", "Atualizado hoje às 14:32"... O horario e o da
// medicao do GPS no celular do paciente.
String descreverAtualizacao(DateTime dataHora, DateTime agora) {
  final diferenca = agora.difference(dataHora);
  if (diferenca.inMinutes < 1) return 'Atualizado agora mesmo';
  if (diferenca.inMinutes < 60) {
    final minutos = diferenca.inMinutes;
    return 'Atualizado há $minutos ${minutos == 1 ? 'minuto' : 'minutos'}';
  }

  String doisDigitos(int valor) => valor.toString().padLeft(2, '0');
  final hora = '${doisDigitos(dataHora.hour)}:${doisDigitos(dataHora.minute)}';
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final dia = DateTime(dataHora.year, dataHora.month, dataHora.day);
  final dias = (hoje.difference(dia).inHours / 24).round();
  if (dias == 0) return 'Atualizado hoje às $hora';
  if (dias == 1) return 'Atualizado ontem às $hora';
  return 'Atualizado em ${doisDigitos(dia.day)}/${doisDigitos(dia.month)} '
      'às $hora';
}

// Tela "Onde está ..." do acompanhante, aberta pelo card do paciente no
// painel: o ultimo local que o app do paciente enviou, com endereco, horario
// e o atalho para abrir no app de mapas do celular.
class LocalizacaoPacienteView extends StatelessWidget {
  const LocalizacaoPacienteView({super.key});

  // Os parametros opcionais permitem aos testes montar a tela com
  // repository, mapa e relogio falsos.
  static Widget comProviders(
    Paciente paciente, {
    LocalizacaoRepository? localizacaoRepository,
    MapaService? mapaService,
    DateTime Function()? agora,
  }) {
    return ChangeNotifierProvider(
      create: (_) => LocalizacaoPacienteViewModel(
        paciente: paciente,
        localizacaoRepository: localizacaoRepository,
        mapaService: mapaService,
        agora: agora,
      ),
      child: const LocalizacaoPacienteView(),
    );
  }

  Future<void> _abrirNoMapa(BuildContext context) async {
    final abriu = await context.read<LocalizacaoPacienteViewModel>().abrirNoMapa();
    if (!context.mounted || abriu) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível abrir o mapa neste celular.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  List<Widget> _conteudo(
    BuildContext context,
    LocalizacaoPacienteViewModel viewModel,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final nome = viewModel.primeiroNome;

    if (viewModel.carregando) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (viewModel.erroDeLeitura) {
      return [
        CardSituacaoLocalizacao(
          icone: Icons.cloud_off_rounded,
          titulo: 'Não foi possível carregar',
          descricao: 'Confira se o seu celular está com internet e tente de '
              'novo.',
          cor: AppCores.aviso,
          destacarBorda: true,
          acao: FilledButton.icon(
            onPressed: viewModel.tentarNovamente,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        ),
      ];
    }

    if (!viewModel.compartilhando) {
      return [
        CardSituacaoLocalizacao(
          icone: Icons.location_off_rounded,
          titulo: 'Localização não compartilhada',
          descricao: 'Peça para $nome ligar o compartilhamento no aplicativo, '
              'em Menu > Minha localização.',
          cor: colorScheme.onSurfaceVariant,
        ),
      ];
    }

    if (!viewModel.temPosicao) {
      return [
        CardSituacaoLocalizacao(
          icone: Icons.location_searching_rounded,
          titulo: 'Aguardando localização',
          descricao: '$nome já ligou o compartilhamento. O local aparece aqui '
              'quando o aplicativo estiver aberto no celular e encontrar o '
              'sinal do GPS.',
          cor: colorScheme.primary,
        ),
      ];
    }

    return [
      _CardUltimoLocal(viewModel: viewModel),
      if (viewModel.desatualizada) ...[
        const SizedBox(height: 16),
        _AvisoDesatualizada(nome: nome),
      ],
      const SizedBox(height: 32),
      BotaoGrande(
        rotulo: 'Abrir no mapa',
        icone: Icons.map_rounded,
        aoTocar: () => _abrirNoMapa(context),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LocalizacaoPacienteViewModel>();

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
            TituloTela(
              'Onde está ${viewModel.primeiroNome}',
              subtitulo: 'O local é atualizado enquanto o aplicativo estiver '
                  'aberto no celular de ${viewModel.primeiroNome}.',
            ),
            const SizedBox(height: 24),
            ..._conteudo(context, viewModel),
          ],
        ),
      ),
    );
  }
}

// Card com o ultimo local recebido: endereco em destaque, horario da medicao
// e a precisao do GPS. O leitor de tela le tudo numa frase so.
class _CardUltimoLocal extends StatelessWidget {
  final LocalizacaoPacienteViewModel viewModel;

  const _CardUltimoLocal({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final localizacao = viewModel.localizacao!;
    final desatualizada = viewModel.desatualizada;
    final cor = desatualizada ? AppCores.aviso : colorScheme.primary;

    final coordenadas = '${localizacao.latitude!.toStringAsFixed(5)}, '
        '${localizacao.longitude!.toStringAsFixed(5)}';
    final String local;
    if (viewModel.endereco != null) {
      local = viewModel.endereco!;
    } else if (viewModel.buscandoEndereco) {
      local = 'Buscando endereço...';
    } else {
      local = 'Endereço não encontrado';
    }
    final quando =
        descreverAtualizacao(localizacao.dataHora!, viewModel.agora());
    final precisao = localizacao.precisaoMetros == null
        ? null
        : 'Precisão de cerca de ${localizacao.precisaoMetros!.round()} metros';

    final leitura = [
      '${desatualizada ? 'Último local conhecido' : 'Local atual'}: '
          '${viewModel.endereco ?? 'coordenadas $coordenadas'}.',
      '$quando.',
      if (precisao != null) '$precisao.',
    ].join(' ');

    return Semantics(
      container: true,
      label: leitura,
      child: ExcludeSemantics(
        child: Card(
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
                    child: Icon(Icons.location_on_rounded, size: 48, color: cor),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  desatualizada ? 'Último local conhecido' : 'Local atual',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  local,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (viewModel.endereco == null && !viewModel.buscandoEndereco) ...[
                  const SizedBox(height: 4),
                  Text(
                    coordenadas,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  quando,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (precisao != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    precisao,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Aviso laranja quando o ultimo local e antigo: o app do paciente esta
// fechado ou sem internet. Nao e alerta de saude, entao nao usa vermelho.
class _AvisoDesatualizada extends StatelessWidget {
  final String nome;

  const _AvisoDesatualizada({required this.nome});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppCores.avisoContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppCores.aviso, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, color: AppCores.aviso, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Local pode estar desatualizado',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppCores.aviso,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'O aplicativo de $nome está fechado ou sem internet. Este é o '
            'último local recebido.',
            style: const TextStyle(
              fontSize: 18,
              height: 1.35,
              color: AppCores.onAvisoContainer,
            ),
          ),
        ],
      ),
    );
  }
}
