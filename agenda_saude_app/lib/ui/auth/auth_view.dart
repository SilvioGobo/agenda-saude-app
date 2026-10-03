import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../acompanhante/acompanhante_view.dart';
import '../shared/botao_selecionavel.dart';
import '../shared/logo_agenda_saude.dart';
import '../triagem/triagem_view.dart';
import '../triagem/triagem_viewmodel.dart';
import 'auth_viewmodel.dart';
import 'login_view.dart';
import 'login_viewmodel.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _cadastrar(BuildContext context) async {
    final viewModel = context.read<AuthViewModel>();
    final sucesso = await viewModel.cadastrar(
      nome: _nomeController.text,
      email: _emailController.text,
      senha: _senhaController.text,
    );

    if (!context.mounted || !sucesso) return;

    final pacienteCriado = viewModel.pacienteCriado;
    if (viewModel.perfilSelecionado == 'Paciente' && pacienteCriado != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider(
            create: (_) => TriagemViewModel(paciente: pacienteCriado),
            child: const TriagemView(),
          ),
        ),
      );
      return;
    }

    final acompanhanteCriado = viewModel.acompanhanteCriado;
    if (acompanhanteCriado != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AcompanhanteView.comProviders(acompanhanteCriado),
        ),
      );
    }
  }

  void _irParaLogin(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => LoginViewModel(),
          child: const LoginView(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Criar Conta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LogoAgendaSaude(),
              const SizedBox(height: 32),
              const Text(
                'Você é:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: BotaoSelecionavel(
                      rotulo: 'Sou Paciente',
                      icone: Icons.elderly_rounded,
                      selecionado: viewModel.perfilSelecionado == 'Paciente',
                      aoTocar: () => viewModel.selecionarPerfil('Paciente'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BotaoSelecionavel(
                      rotulo: 'Sou Acompanhante',
                      icone: Icons.groups_rounded,
                      selecionado:
                          viewModel.perfilSelecionado == 'Acompanhante',
                      aoTocar: () => viewModel.selecionarPerfil('Acompanhante'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nomeController,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(labelText: 'Nome completo'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _senhaController,
                builder: (context, valor, _) {
                  final forca = calcularForcaSenha(valor.text);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _senhaController,
                        obscureText: true,
                        style: const TextStyle(fontSize: 18),
                        decoration: const InputDecoration(labelText: 'Senha'),
                      ),
                      if (valor.text.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Força da senha: ${_rotuloForca(forca)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _corForca(forca),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              if (viewModel.mensagemErro != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    viewModel.mensagemErro!,
                    style: const TextStyle(color: AppCores.perigo, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ElevatedButton(
                onPressed:
                    viewModel.carregando ? null : () => _cadastrar(context),
                child: viewModel.carregando
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text('Cadastrar'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _irParaLogin(context),
                child: const Text('Já tem conta? Entrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _rotuloForca(ForcaSenha forca) {
  switch (forca) {
    case ForcaSenha.forte:
      return 'Forte';
    case ForcaSenha.media:
      return 'Média';
    case ForcaSenha.fraca:
    case ForcaSenha.vazia:
      return 'Fraca';
  }
}

Color _corForca(ForcaSenha forca) {
  switch (forca) {
    case ForcaSenha.forte:
      return AppCores.sucesso;
    case ForcaSenha.media:
      return AppCores.aviso;
    case ForcaSenha.fraca:
    case ForcaSenha.vazia:
      return AppCores.perigo;
  }
}
