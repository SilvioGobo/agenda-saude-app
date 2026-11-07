import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_cores.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/botao_barra_superior.dart';
import '../shared/titulo_tela.dart';
import 'recuperar_senha_viewmodel.dart';

// Tela "Recuperar senha" (RF 01.3), aberta pelo "Esqueci minha senha" do
// login: a pessoa confirma o e-mail da conta e o Firebase manda o link para
// criar uma nova senha. Depois de enviar, o botao principal vira "Voltar para
// o login" e o reenvio fica como segunda opcao.
class RecuperarSenhaView extends StatefulWidget {
  // E-mail que a pessoa ja tinha digitado no login, para nao digitar de novo.
  final String emailInicial;

  const RecuperarSenhaView({super.key, this.emailInicial = ''});

  // O parametro opcional permite aos testes trocar o Firebase Auth por um
  // repository falso.
  static Widget comProviders({
    String emailInicial = '',
    AuthRepository? authRepository,
  }) {
    return ChangeNotifierProvider(
      create: (_) => RecuperarSenhaViewModel(authRepository: authRepository),
      child: RecuperarSenhaView(emailInicial: emailInicial),
    );
  }

  @override
  State<RecuperarSenhaView> createState() => _RecuperarSenhaViewState();
}

class _RecuperarSenhaViewState extends State<RecuperarSenhaView> {
  late final TextEditingController _emailController =
      TextEditingController(text: widget.emailInicial.trim());

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _enviar(BuildContext context) {
    context.read<RecuperarSenhaViewModel>().enviar(_emailController.text);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RecuperarSenhaViewModel>();
    final emailEnviado = viewModel.emailEnviado;

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
              'Recuperar senha',
              subtitulo:
                  'Digite o e-mail da sua conta. Vamos enviar um link para você criar uma nova senha.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _enviar(context),
              style: const TextStyle(fontSize: 18),
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
            const SizedBox(height: 24),
            if (viewModel.mensagemErro != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    viewModel.mensagemErro!,
                    style: const TextStyle(color: AppCores.perigo, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (emailEnviado != null) ...[
              _PedidoEnviado(email: emailEnviado),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Voltar para o login'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: viewModel.carregando ? null : () => _enviar(context),
                child: const Text('Não chegou? Enviar de novo'),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: viewModel.carregando ? null : () => _enviar(context),
                child: viewModel.carregando
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text('Enviar e-mail'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Voltar para o login'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Confirmacao verde com icone, titulo e texto - nunca so a cor (NF004). Fala
// "se tiver conta": a resposta e a mesma para e-mail cadastrado ou nao.
class _PedidoEnviado extends StatelessWidget {
  final String email;

  const _PedidoEnviado({required this.email});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppCores.sucessoContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppCores.sucesso, width: 3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.mark_email_read_rounded,
                  color: AppCores.sucesso,
                  size: 36,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'E-MAIL ENVIADO',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppCores.sucesso,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Pedido enviado para $email. Se esse e-mail tiver uma conta, você '
              'vai receber o link para criar uma nova senha. Abra a mensagem e '
              'toque no link. Se não encontrar, olhe também a caixa de spam.',
              style: const TextStyle(
                fontSize: 18,
                height: 1.35,
                color: AppCores.onSucessoContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
