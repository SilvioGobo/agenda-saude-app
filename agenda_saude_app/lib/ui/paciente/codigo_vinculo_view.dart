import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/botao_barra_superior.dart';
import '../shared/botao_grande.dart';
import '../shared/titulo_tela.dart';

// Tela "Meu código de vínculo", aberta pelo menu do paciente: o código que o
// acompanhante digita para se vincular (RF05.4). So e preciso uma vez, por
// isso fica no menu e nao no painel. Letras grandes e espacadas para serem
// lidas em voz alta ou ditadas por telefone; o botao copia para enviar por
// mensagem.
class CodigoVinculoView extends StatelessWidget {
  final String codigo;

  const CodigoVinculoView({super.key, required this.codigo});

  Future<void> _copiar(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: codigo));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código copiado.', style: TextStyle(fontSize: 18)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disponivel = codigo.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: BotaoBarraSuperior.largura,
        leading: BotaoBarraSuperior.voltar(
          aoTocar: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            const TituloTela(
              'Meu código de vínculo',
              subtitulo: 'Passe este código para a pessoa que vai acompanhar '
                  'você. Ela digita o código no aplicativo dela para ver seus '
                  'batimentos e receber seus alertas.',
            ),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                child: Column(
                  children: [
                    Icon(
                      Icons.key_rounded,
                      size: 40,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    // O leitor de tela soletra o codigo, letra por letra.
                    Semantics(
                      label: disponivel
                          ? 'Código: ${codigo.split('').join(' ')}'
                          : 'Código indisponível',
                      child: ExcludeSemantics(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            disponivel ? codigo : 'Indisponível',
                            style: TextStyle(
                              fontSize: disponivel ? 44 : 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: disponivel ? 10 : 0,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (disponivel) ...[
              const SizedBox(height: 32),
              BotaoGrande(
                rotulo: 'Copiar código',
                icone: Icons.copy_rounded,
                principal: false,
                aoTocar: () => _copiar(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
