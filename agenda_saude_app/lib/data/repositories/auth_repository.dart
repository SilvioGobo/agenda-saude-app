import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth? _authInjetado;

  // Permite injetar um FirebaseAuth (ou um fake) nos testes, ou usa o real no app.
  // O acesso a FirebaseAuth.instance so acontece dentro do getter, nunca no
  // construtor, para nao exigir o Firebase inicializado ao criar um fake em teste.
  AuthRepository({FirebaseAuth? auth}) : _authInjetado = auth;

  FirebaseAuth get _auth => _authInjetado ?? FirebaseAuth.instance;

  // O Firebase Auth guarda a sessao no aparelho: depois de entrar uma vez,
  // o usuario continua logado ao reabrir o app ate chamar sair().
  String? get uidUsuarioAtual => _auth.currentUser?.uid;

  Future<void> sair() => _auth.signOut();

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

  // Pede ao Firebase Auth que mande ao [email] o link para criar uma nova senha
  // (RF 01.3). O e-mail e o link sao do proprio Firebase; o idioma vai antes
  // para a mensagem sair em portugues e nao no padrao do projeto. Com a protecao
  // contra enumeracao de contas ligada (padrao dos projetos novos), um e-mail
  // sem conta tambem termina sem erro; sem ela, o Firebase lanca
  // `user-not-found`.
  Future<void> enviarEmailRedefinicaoSenha({required String email}) async {
    await _auth.setLanguageCode('pt-BR');
    await _auth.sendPasswordResetEmail(email: email);
  }
}
