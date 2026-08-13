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

      // O doc de usuarios guarda Paciente e Acompanhante na mesma colecao,
      // entao primeiro descobrimos qual e o perfil antes de buscar os dados
      // completos no repository certo.
      final doc = await _firestore.collection('usuarios').doc(uid).get();
      final perfil = doc.data()?['perfil'];

      if (perfil == 'Paciente') {
        pacienteLogado = await _pacienteRepository.getPaciente(uid);
      } else if (perfil == 'Acompanhante') {
        acompanhanteLogado = await _acompanhanteRepository.getAcompanhante(uid);
      } else {
        mensagemErro = 'Não foi possível identificar o perfil desta conta.';
        carregando = false;
        notifyListeners();
        return false;
      }

      carregando = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      mensagemErro = _traduzirErro(e.code);
      carregando = false;
      notifyListeners();
      return false;
    } catch (_) {
      mensagemErro = 'Não foi possível entrar. Tente novamente.';
      carregando = false;
      notifyListeners();
      return false;
    }
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
