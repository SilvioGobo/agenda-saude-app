import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/repositories/acompanhante_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/paciente_repository.dart';
import '../../domain/models/acompanhante.dart';
import '../../domain/models/paciente.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;
  final PacienteRepository _pacienteRepository;
  final AcompanhanteRepository _acompanhanteRepository;
  final FirebaseFirestore? _firestoreInjetado;

  LoginViewModel({
    AuthRepository? authRepository,
    PacienteRepository? pacienteRepository,
    AcompanhanteRepository? acompanhanteRepository,
    FirebaseFirestore? firestore,
  })  : _authRepository = authRepository ?? AuthRepository(),
        _pacienteRepository = pacienteRepository ?? PacienteRepository(),
        _acompanhanteRepository =
            acompanhanteRepository ?? AcompanhanteRepository(),
        _firestoreInjetado = firestore;

  FirebaseFirestore get _firestore =>
      _firestoreInjetado ?? FirebaseFirestore.instance;

  bool carregando = false;
  String? mensagemErro;
  Paciente? pacienteLogado;
  Acompanhante? acompanhanteLogado;

  Future<bool> entrar({required String email, required String senha}) async {
    if (email.trim().isEmpty || senha.isEmpty) {
      mensagemErro = 'Preencha e-mail e senha.';
      notifyListeners();
      return false;
    }

    carregando = true;
    mensagemErro = null;
    notifyListeners();

    try {
      final uid = await _authRepository.entrar(
        email: email.trim(),
        senha: senha,
      );

      final encontrouPerfil = await _carregarPerfil(uid);
      if (!encontrouPerfil) {
        mensagemErro = 'Não foi possível identificar o perfil desta conta.';
      }

      carregando = false;
      notifyListeners();
      return encontrouPerfil;
    } on FirebaseAuthException catch (e) {
      mensagemErro = _traduzirErro(e.code);
      carregando = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Login falhou ao buscar perfil: $e');
      mensagemErro = 'Não foi possível entrar. Tente novamente.';
      carregando = false;
      notifyListeners();
      return false;
    }
  }

  // Abertura do app: se o aparelho ja tem uma sessao salva, recarrega o
  // perfil sem pedir e-mail e senha de novo. Nao chama notifyListeners
  // porque quem aguarda (AberturaView) redesenha quando o Future termina.
  Future<bool> restaurarSessao() async {
    final uid = _authRepository.uidUsuarioAtual;
    if (uid == null) return false;

    try {
      final encontrouPerfil = await _carregarPerfil(uid);
      // Conta do Auth sem perfil no Firestore (cadastro que falhou no meio):
      // desloga para a pessoa cair no login em vez de ficar presa.
      if (!encontrouPerfil) await _authRepository.sair();
      return encontrouPerfil;
    } catch (e) {
      // Mantem a sessao: na proxima abertura o app tenta de novo.
      debugPrint('Falha ao restaurar sessão: $e');
      mensagemErro =
          'Não foi possível carregar seus dados. Verifique sua conexão e entre novamente.';
      return false;
    }
  }

  // O doc de usuarios guarda Paciente e Acompanhante na mesma colecao,
  // entao primeiro descobrimos qual e o perfil antes de buscar os dados
  // completos no repository certo.
  Future<bool> _carregarPerfil(String uid) async {
    final doc = await _firestore.collection('usuarios').doc(uid).get();
    final perfil = doc.data()?['perfil'];

    if (perfil == 'Paciente') {
      final paciente = await _pacienteRepository.getPaciente(uid);
      pacienteLogado = paciente;
      // Contas criadas antes do modulo de vinculo tem o codigo no proprio
      // doc, mas nao em `codigos_vinculo`. Publicar aqui garante que o
      // acompanhante consiga encontra-las; falhar nisso nao impede o login.
      if (paciente != null) {
        try {
          await _pacienteRepository.publicarCodigoVinculo(paciente);
        } catch (e) {
          debugPrint('Falha ao publicar código de vínculo: $e');
        }
      }
      return paciente != null;
    }
    if (perfil == 'Acompanhante') {
      acompanhanteLogado = await _acompanhanteRepository.getAcompanhante(uid);
      return acompanhanteLogado != null;
    }
    return false;
  }

  String _traduzirErro(String codigo) {
    switch (codigo) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'invalid-email':
        return 'O e-mail informado não é válido.';
      case 'user-disabled':
        return 'Esta conta foi desativada.';
      default:
        return 'Não foi possível entrar. Tente novamente.';
    }
  }
}
