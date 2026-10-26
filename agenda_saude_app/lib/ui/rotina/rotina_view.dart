import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/paciente.dart';
import '../insulina/card_glicemia_insulina.dart';
import '../insulina/glicemia_insulina_viewmodel.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/titulo_tela.dart';
import 'card_hidratacao.dart';
import 'card_refeicoes.dart';
import 'hidratacao_viewmodel.dart';
import 'refeicoes_viewmodel.dart';

// "Minha Rotina" (Figura 14 do TCC): checklist do dia do paciente. Tem a
// hidratacao (RF03.1), as refeicoes (RF03.4) e, para quem marcou diabetes na
// triagem, glicemia e insulina (RF008); sono e exercicio entram como novos
// cartoes nesta mesma lista conforme o modulo avanca.
class RotinaView extends StatelessWidget {
  // Mostra o cartao de glicemia e insulina; exige um
  // GlicemiaInsulinaViewModel acima na arvore.
  final bool exibirDiabetes;

  const RotinaView({super.key, this.exibirDiabetes = false});

  // Monta a tela com os ViewModels do paciente. O de glicemia/insulina so e
  // criado para diabeticos - a interface adaptada pela triagem (UC02).
  // `aoAtualizarPaciente` avisa o painel quando o plano de refeicoes muda.
  static Widget comProviders(
    Paciente paciente, {
    ValueChanged<Paciente>? aoAtualizarPaciente,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => HidratacaoViewModel(paciente: paciente),
        ),
        ChangeNotifierProvider(
          create: (_) => RefeicoesViewModel(
            paciente: paciente,
            aoAtualizarPaciente: aoAtualizarPaciente,
          ),
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
            const SizedBox(height: 16),
            const CardRefeicoes(),
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
