import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/auth_repository.dart';
import 'login_view.dart';
import 'login_viewmodel.dart';

// Botao "Sair" da barra superior dos paineis. Como a sessao fica salva no
// aparelho, e a unica forma de trocar de conta; pede confirmacao antes para
// um toque acidental nao deslogar o usuario.
class BotaoSair extends StatelessWidget {
  final AuthRepository? authRepository;
  // Permite aos testes montar a tela de login com repositories falsos.
  final LoginViewModel Function()? criarLoginViewModel;

  const BotaoSair({super.key, this.authRepository, this.criarLoginViewModel});

  Future<void> _sair(BuildContext context) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Para entrar de novo, será preciso digitar seu e-mail e senha.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (!context.mounted || confirmou != true) return;
    await (authRepository ?? AuthRepository()).sair();
    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => criarLoginViewModel?.call() ?? LoginViewModel(),
          child: const LoginView(),
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _sair(context),
      icon: const Icon(Icons.logout_rounded),
      label: const Text('Sair'),
    );
  }
}
