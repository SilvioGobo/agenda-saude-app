import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/auth_repository.dart';
import 'login_view.dart';
import 'login_viewmodel.dart';

// Encerra a sessao e volta para o login, limpando a pilha de telas (o
// "voltar" nao retorna mais ao painel). Chamado depois da confirmacao pelo
// BotaoSair e pelo item "Sair da conta" do menu do paciente.
Future<void> sairDaConta(
  BuildContext context, {
  required Future<void> Function() sair,
  LoginViewModel Function()? criarLoginViewModel,
}) async {
  try {
    await sair();
  } catch (e) {
    debugPrint('Falha ao sair da conta: $e');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível sair. Tente de novo.')),
    );
    return;
  }
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
    await sairDaConta(
      context,
      sair: (authRepository ?? AuthRepository()).sair,
      criarLoginViewModel: criarLoginViewModel,
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
