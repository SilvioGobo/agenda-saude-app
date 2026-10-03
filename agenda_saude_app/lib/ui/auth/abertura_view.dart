import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/logo_agenda_saude.dart';
import 'login_view.dart';
import 'login_viewmodel.dart';
import 'tela_inicial_usuario.dart';

// Primeira tela do app. Enquanto confere se ja existe uma sessao salva no
// aparelho mostra a logo; depois abre direto o painel de quem ja estava
// logado ou, se nao houver sessao, a tela de login.
class AberturaView extends StatefulWidget {
  const AberturaView({super.key});

  @override
  State<AberturaView> createState() => _AberturaViewState();
}

class _AberturaViewState extends State<AberturaView> {
  late final Future<bool> _restauracao;

  @override
  void initState() {
    super.initState();
    _restauracao = context.read<LoginViewModel>().restaurarSessao();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _restauracao,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LogoAgendaSaude(),
                  SizedBox(height: 32),
                  CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }

        final tela = snapshot.data == true
            ? telaInicialDoUsuario(context.read<LoginViewModel>())
            : null;
        return tela ?? const LoginView();
      },
    );
  }
}
