import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../acompanhante/acompanhante_view.dart';
import '../paciente/paciente_view.dart';
import '../triagem/triagem_view.dart';
import '../triagem/triagem_viewmodel.dart';
import 'login_viewmodel.dart';

// Primeira tela de quem acabou de entrar, seja digitando e-mail e senha ou
// pela sessao salva no aparelho: paciente que ainda nao fez a triagem (RF002)
// vai para ela; os demais vao direto para o proprio painel.
Widget? telaInicialDoUsuario(LoginViewModel viewModel) {
  final paciente = viewModel.pacienteLogado;
  if (paciente != null && !paciente.triagemConcluida) {
    return ChangeNotifierProvider(
      create: (_) => TriagemViewModel(paciente: paciente),
      child: const TriagemView(),
    );
  }
  if (paciente != null) return PacienteView.comProviders(paciente);

  final acompanhante = viewModel.acompanhanteLogado;
  if (acompanhante != null) return AcompanhanteView.comProviders(acompanhante);

  return null;
}
