import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/repositories/acompanhante_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/paciente_repository.dart';
import '../../domain/models/acompanhante.dart';
import '../../domain/models/paciente.dart';

enum ForcaSenha { vazia, fraca, media, forte }

// Usado tanto pela logica do AuthViewModel quanto pela AuthView, que mostra
// a forca da senha em tempo real enquanto o usuario digita.
ForcaSenha calcularForcaSenha(String senha) {
  if (senha.isEmpty) return ForcaSenha.vazia;
  if (senha.length < 6) return ForcaSenha.fraca;

  final apenasUmCaractereRepetido = RegExp(r'^(.)\1*$').hasMatch(senha);
  if (apenasUmCaractereRepetido) return ForcaSenha.fraca;

  final temLetra = senha.contains(RegExp(r'[A-Za-z]'));
  final temNumero = senha.contains(RegExp(r'[0-9]'));
  final temSimbolo = senha.contains(RegExp(r'[^A-Za-z0-9]'));
  final variedade = [temLetra, temNumero, temSimbolo].where((v) => v).length;

  if (senha.length >= 8 && variedade >= 2) return ForcaSenha.forte;
  if (variedade >= 1) return ForcaSenha.media;
  return ForcaSenha.fraca;
}

bool emailValido(String email) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
}

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;
  final PacienteRepository _pacienteRepository;
  final AcompanhanteRepository _acompanhanteRepository;

  AuthViewModel({
    AuthRepository? authRepository,
    PacienteRepository? pacienteRepository,
    AcompanhanteRepository? acompanhanteRepository,
  })  : _authRepository = authRepository ?? AuthRepository(),
        _pacienteRepository = pacienteRepository ?? PacienteRepository(),
        _acompanhanteRepository =
            acompanhanteRepository ?? AcompanhanteRepository();

  String? perfilSelecionado;
  bool carregando = false;
  String? mensagemErro;
  Paciente? pacienteCriado;

  void selecionarPerfil(String perfil) {
    perfilSelecionado = perfil;
    mensagemErro = null;
    notifyListeners();
  }

  Future<bool> cadastrar({
    required String nome,
    required String email,
    required String senha,
  }) async {
    if (perfilSelecionado == null) {
      mensagemErro = 'Selecione se você é Paciente ou Acompanhante.';
      notifyListeners();
      return false;
    }
    if (nome.trim().isEmpty || email.trim().isEmpty || senha.isEmpty) {
      mensagemErro = 'Preencha nome, e-mail e senha.';
      notifyListeners();
      return false;
    }
    if (!emailValido(email.trim())) {
      mensagemErro = 'Informe um e-mail válido.';
      notifyListeners();
      return false;
    }
    if (calcularForcaSenha(senha) == ForcaSenha.fraca) {
      mensagemErro =
          'Senha muito fraca. Use pelo menos 6 caracteres, misturando letras e números.';
      notifyListeners();
      return false;
    }

    carregando = true;
    mensagemErro = null;
    notifyListeners();

    try {
      final uid = await _authRepository.cadastrar(
        email: email.trim(),
        senha: senha,
      );

      if (perfilSelecionado == 'Paciente') {
        final paciente = Paciente(
          id: uid,
          nome: nome.trim(),
          email: email.trim(),
          perfil: 'Paciente',
          possuiDiabetes: false,
          possuiCardiopatia: false,
          codigoVinculo: _gerarCodigoVinculo(),
        );
        await _pacienteRepository.salvarPaciente(paciente);
        pacienteCriado = paciente;
      } else {
        final acompanhante = Acompanhante(
          id: uid,
          nome: nome.trim(),
          email: email.trim(),
          perfil: 'Acompanhante',
          pacientesVinculadosIds: [],
        );
        await _acompanhanteRepository.salvarAcompanhante(acompanhante);
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
      mensagemErro = 'Não foi possível completar o cadastro. Tente novamente.';
      carregando = false;
      notifyListeners();
      return false;
    }
  }

  String _traduzirErro(String codigo) {
    switch (codigo) {
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado.';
      case 'invalid-email':
        return 'O e-mail informado não é válido.';
      case 'weak-password':
        return 'A senha é muito fraca. Use pelo menos 6 caracteres.';
      default:
        return 'Não foi possível completar o cadastro. Tente novamente.';
    }
  }

  // Codigo de 6 caracteres que o Acompanhante usara para se vincular a este
  // Paciente futuramente (RF05.4) - nao ha letras/numeros ambiguos (0,O,1,I).
  String _gerarCodigoVinculo() {
    const caracteres = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final aleatorio = Random();
    return List.generate(
      6,
      (_) => caracteres[aleatorio.nextInt(caracteres.length)],
    ).join();
  }
}
