import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/logo_agenda_saude.dart';
import '../shared/tela_provisoria.dart';
import '../triagem/triagem_view.dart';
import '../triagem/triagem_viewmodel.dart';
import 'auth_view.dart';
import 'auth_viewmodel.dart';
import 'login_viewmodel.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _entrar(BuildContext context) async {
    final viewModel = context.read<LoginViewModel>();
    final sucesso = await viewModel.entrar(
      email: _emailController.text,
      senha: _senhaController.text,
    );

    if (!context.mounted || !sucesso) return;

    final paciente = viewModel.pacienteLogado;
    if (paciente != null && !paciente.triagemConcluida) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider(
            create: (_) => TriagemViewModel(paciente: paciente),
            child: const TriagemView(),
          ),
        ),
      );
      return;
    }

    final mensagem = paciente != null
        ? 'Bem-vindo(a) de volta! Este será o painel do Paciente.'
        : 'Bem-vindo(a) de volta! Este será o painel do Acompanhante.';

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TelaProvisoria(titulo: 'Início', mensagem: mensagem),
      ),
    );
  }

  void _irParaCadastro(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => AuthViewModel(),
          child: const AuthView(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LoginViewModel>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const LogoAgendaSaude(),
              const SizedBox(height: 12),
              const Text(
                'Bem-vindo',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _senhaController,
                obscureText: true,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(labelText: 'Senha'),
              ),
              const SizedBox(height: 24),
              if (viewModel.mensagemErro != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    viewModel.mensagemErro!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ElevatedButton(
                onPressed:
                    viewModel.carregando ? null : () => _entrar(context),
                child: viewModel.carregando
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text('Entrar'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _irParaCadastro(context),
                child: const Text('Não tem conta? Cadastre-se'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
