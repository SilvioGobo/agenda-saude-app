import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/paciente.dart';
import '../insulina/card_glicemia_insulina.dart';
import '../insulina/glicemia_insulina_viewmodel.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/titulo_tela.dart';
import 'card_hidratacao.dart';
import 'hidratacao_viewmodel.dart';

// "Minha Rotina" (Figura 14 do TCC): checklist do dia do paciente. Tem a
// hidratacao (RF03.1) e, para quem marcou diabetes na triagem, glicemia e
// insulina (RF008); sono, exercicio e alimentacao entram como novos cartoes
// nesta mesma lista conforme o modulo de rotina avanca.
class RotinaView extends StatelessWidget {
  // Mostra o cartao de glicemia e insulina; exige um
  // GlicemiaInsulinaViewModel acima na arvore.
  final bool exibirDiabetes;

  const RotinaView({super.key, this.exibirDiabetes = false});

  // Monta a tela com os ViewModels do paciente. O de glicemia/insulina so e
  // criado para diabeticos - a interface adaptada pela triagem (UC02).
  static Widget comProviders(Paciente paciente) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => HidratacaoViewModel(paciente: paciente),
        ),
        if (paciente.possuiDiabetes)
          ChangeNotifierProvider(
            create: (_) => GlicemiaInsulinaViewModel(paciente: paciente),
          ),
      ],
      child: RotinaView(exibirDiabetes: paciente.possuiDiabetes),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              'Minha Rotina',
              subtitulo: 'Registre aqui o que você já fez hoje.',
            ),
            const SizedBox(height: 24),
            const CardHidratacao(),
            if (exibirDiabetes) ...[
              const SizedBox(height: 16),
              const CardGlicemiaInsulina(),
            ],
          ],
        ),
      ),
    );
  }
}
