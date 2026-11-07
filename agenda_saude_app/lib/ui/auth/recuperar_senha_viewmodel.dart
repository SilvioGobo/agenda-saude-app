import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/repositories/auth_repository.dart';
import 'auth_viewmodel.dart' show emailValido;

// Tela "Recuperar senha" (RF 01.3): a pessoa informa o e-mail da conta e o
// Firebase manda o link para criar uma nova senha.
class RecuperarSenhaViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;

  RecuperarSenhaViewModel({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepository();

  bool carregando = false;
  String? mensagemErro;

  // E-mail para o qual o pedido foi feito; null enquanto nao enviou.
  String? emailEnviado;

  Future<bool> enviar(String email) async {
    final emailLimpo = email.trim();
    if (emailLimpo.isEmpty) {
      mensagemErro = 'Digite o e-mail da sua conta.';
      notifyListeners();
      return false;
    }
    if (!emailValido(emailLimpo)) {
      mensagemErro = 'Informe um e-mail válido.';
      notifyListeners();
      return false;
    }

    carregando = true;
    mensagemErro = null;
    emailEnviado = null;
    notifyListeners();

    try {
      await _authRepository.enviarEmailRedefinicaoSenha(email: emailLimpo);
      emailEnviado = emailLimpo;
      return true;
    } on FirebaseAuthException catch (e) {
      // Sem a protecao contra enumeracao de contas o Firebase avisa que nao ha
      // conta com o e-mail. A tela responde igual nos dois casos ("se tiver
      // conta, enviamos"), para nao revelar quais e-mails estao cadastrados.
      if (e.code == 'user-not-found') {
        emailEnviado = emailLimpo;
        return true;
      }
      mensagemErro = _traduzirErro(e.code);
      return false;
    } catch (e) {
      debugPrint('Recuperar senha falhou: $e');
      mensagemErro = 'Não foi possível enviar o e-mail. Tente novamente.';
      return false;
    } finally {
      carregando = false;
      notifyListeners();
    }
  }

  String _traduzirErro(String codigo) {
    switch (codigo) {
      case 'invalid-email':
        return 'O e-mail informado não é válido.';
      case 'network-request-failed':
        return 'Sem conexão com a internet. Verifique sua rede.';
      case 'too-many-requests':
        return 'Muitos pedidos em pouco tempo. Aguarde alguns minutos e tente de novo.';
      default:
        return 'Não foi possível enviar o e-mail. Tente novamente.';
    }
  }
}
