import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/health_service.dart';
import '../../core/theme/app_cores.dart';
import '../configuracoes/configuracoes_viewmodel.dart';
import '../shared/botao_ouvir_tela.dart';
import 'narracao_da_explicacao.dart';
import 'sincronizacao_bpm_viewmodel.dart';

// Botao "Como funciona?" do destaque dos batimentos no painel e do card de
// "Meu smartwatch": e o "?" desses cards, com o texto ao lado, porque o guia
// visual pede icone sempre acompanhado de texto.
class BotaoComoFunciona extends StatelessWidget {
  final VoidCallback aoTocar;

  const BotaoComoFunciona({super.key, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: aoTocar,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          iconSize: 26,
        ),
        icon: const Icon(Icons.help_outline_rounded),
        label: const Text('Como funciona?'),
      ),
    );
  }
}

// Explicacao de como os batimentos chegam ao app. O app nao se liga direto no
// relogio: o caminho e relogio -> app da marca -> Health Connect -> Agenda
// Saude, e "conectar" so da a permissao de ler o Health Connect. Sem relogio,
// ou com um relogio cujo app nao manda para o Health Connect, o app fica
// conectado e nenhum batimento chega. A explicacao diz o que conferir e onde
// fica o Health Connect, que na tela se chama "Saúde Connect": o nome que
// aparece no celular em portugues (em alguns aparelhos e "Conexão Saúde" ou
// "Health Connect", e a explicacao cita os tres). O botao de abrir so aparece
// com o Health Connect no aparelho: sem ele, o proprio card ja oferece
// instalar.
//
// A folha abre numa rota nova, que nao herda os providers da tela: o narrador
// vai junto (como no `rotaComNarrador`), para o "Ouvir esta tela" dela.
Future<void> mostrarExplicacaoBatimentos(
  BuildContext context,
  SincronizacaoBpmViewModel viewModel,
) {
  final narrador = Provider.of<ConfiguracoesViewModel?>(context, listen: false);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) {
      final explicacao = _ExplicacaoBatimentos(
        abrirSaudeConnect:
            viewModel.statusHealthConnect == StatusHealthConnect.disponivel
                ? viewModel.abrirHealthConnect
                : null,
      );
      return narrador == null
          ? explicacao
          : ChangeNotifierProvider.value(value: narrador, child: explicacao);
    },
  );
}

class _ExplicacaoBatimentos extends StatefulWidget {
  final Future<bool> Function()? abrirSaudeConnect;

  const _ExplicacaoBatimentos({this.abrirSaudeConnect});

  @override
  State<_ExplicacaoBatimentos> createState() => _ExplicacaoBatimentosState();
}

class _ExplicacaoBatimentosState extends State<_ExplicacaoBatimentos> {
  bool _naoAbriu = false;

  Future<void> _abrirSaudeConnect() async {
    final abriu = await widget.abrirSaudeConnect!();
    if (mounted) setState(() => _naoAbriu = !abriu);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final corpo = TextStyle(
      fontSize: 18,
      height: 1.35,
      color: colorScheme.onSurface,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: const Text(
                'Como o app recebe seus batimentos',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            const BotaoOuvirTela(texto: narrarExplicacaoBatimentos),
            Text(
              'O Agenda Saúde não se liga direto no relógio. Os batimentos '
              'fazem este caminho:',
              style: corpo,
            ),
            const SizedBox(height: 16),
            _Passo(
              numero: 1,
              texto: 'O relógio mede os batimentos.',
              estilo: corpo,
            ),
            _Passo(
              numero: 2,
              texto: 'O app do relógio (Samsung Health, Mi Fitness, Zepp...) '
                  'recebe as medições.',
              estilo: corpo,
            ),
            _Passo(
              numero: 3,
              texto: 'Esse app manda as medições para o Saúde Connect, do '
                  'Android.',
              estilo: corpo,
            ),
            _Passo(
              numero: 4,
              texto: 'O Agenda Saúde lê os batimentos no Saúde Connect.',
              estilo: corpo,
            ),
            const SizedBox(height: 4),
            Text(
              'Conectar o smartwatch aqui só dá permissão para o Agenda Saúde '
              'ler o Saúde Connect. Os batimentos só aparecem se o app do '
              'relógio também mandar as medições para lá.',
              style: corpo,
            ),
            const SizedBox(height: 24),
            const _Subtitulo('Se os batimentos não aparecem'),
            const SizedBox(height: 8),
            Text(
              'No app do seu relógio, ligue a opção Saúde Connect (ou Health '
              'Connect) e permita a frequência cardíaca.',
              style: corpo,
            ),
            const SizedBox(height: 8),
            Text(
              'Espere alguns minutos: o app do relógio manda as medições de '
              'tempos em tempos, e não na mesma hora.',
              style: corpo,
            ),
            const SizedBox(height: 8),
            Text(
              'Nem todo relógio tem essa opção. Sem ela, o Agenda Saúde não '
              'consegue ler os batimentos.',
              style: corpo,
            ),
            const SizedBox(height: 24),
            const _Subtitulo('Onde fica o Saúde Connect'),
            const SizedBox(height: 8),
            Text(
              'No Android 14 ou mais novo, ele já vem no celular: abra as '
              'Configurações e procure por "Saúde Connect" (em alguns '
              'celulares o nome é "Conexão Saúde" ou "Health Connect"). No '
              'Android 13 ou mais antigo, ele é um app da Play Store.',
              style: corpo,
            ),
            const SizedBox(height: 8),
            Text(
              'Lá dentro, procure Frequência cardíaca (em Sinais vitais) para '
              'ver se as medições do relógio estão chegando.',
              style: corpo,
            ),
            const SizedBox(height: 24),
            if (widget.abrirSaudeConnect != null) ...[
              FilledButton.icon(
                onPressed: _abrirSaudeConnect,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Abrir o Saúde Connect'),
              ),
              if (_naoAbriu) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    'Não deu para abrir por aqui. Abra as Configurações do '
                    'celular e procure por "Saúde Connect".',
                    style: corpo.copyWith(color: AppCores.aviso),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Subtitulo extends StatelessWidget {
  final String texto;

  const _Subtitulo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        texto,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// Um passo do caminho dos batimentos: o numero num circulo e o texto ao lado.
// O circulo cresce com a fonte do celular, para o numero caber.
class _Passo extends StatelessWidget {
  final int numero;
  final String texto;
  final TextStyle estilo;

  const _Passo({
    required this.numero,
    required this.texto,
    required this.estilo,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final diametro = MediaQuery.textScalerOf(context).scale(34);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: diametro,
              height: diametro,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$numero',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(texto, style: estilo)),
          ],
        ),
      ),
    );
  }
}
