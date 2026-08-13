import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth? _authInjetado;

  // Permite injetar um FirebaseAuth (ou um fake) nos testes, ou usa o real no app.
  // O acesso a FirebaseAuth.instance so acontece dentro do getter, nunca no
  // construtor, para nao exigir o Firebase inicializado ao criar um fake em teste.
  AuthRepository({FirebaseAuth? auth}) : _authInjetado = auth;

  FirebaseAuth get _auth => _authInjetado ?? FirebaseAuth.instance;

  // Cria a conta no Firebase Auth e retorna o UID do novo usuario
  Future<String> cadastrar({required String email, required String senha}) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: senha,
    );
    return credential.user!.uid;
  }

  // Autentica uma conta existente e retorna o UID do usuario
  Future<String> entrar({required String email, required String senha}) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: senha,
    );
    return credential.user!.uid;
  }
}
