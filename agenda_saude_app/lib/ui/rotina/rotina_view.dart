import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/paciente.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/titulo_tela.dart';
import 'card_hidratacao.dart';
import 'hidratacao_viewmodel.dart';

// "Minha Rotina" (Figura 14 do TCC): checklist do dia do paciente. Por ora tem
// a hidratacao (RF03.1); sono, exercicio, alimentacao e insulina entram como
// novos cartoes nesta mesma lista conforme o modulo de rotina avanca.
class RotinaView extends StatelessWidget {
  const RotinaView({super.key});

  // Monta a tela com o ViewModel de hidratacao do paciente.
  static Widget comProviders(Paciente paciente) {
    return ChangeNotifierProvider(
      create: (_) => HidratacaoViewModel(paciente: paciente),
      child: const RotinaView(),
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
          children: const [
            TituloTela(
              'Minha Rotina',
              subtitulo: 'Registre aqui o que você já fez hoje.',
            ),
            SizedBox(height: 24),
            CardHidratacao(),
          ],
        ),
      ),
    );
  }
}
