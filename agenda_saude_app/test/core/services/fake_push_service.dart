import 'dart:async';

import 'package:agenda_saude_app/core/services/push_service.dart';

// Substituto em memoria do FCM para os testes: o token e definido pelo teste,
// que tambem pode simular a renovacao do token e o toque numa notificacao
// mostrada pelo sistema.
class FakePushService implements PushService {
  @override
  bool disponivel;
  String? token;
  // Id do alerta da notificacao que "abriu o app".
  String? alertaDeAbertura;
  Object? erroAoObterToken;

  int pedidosDeToken = 0;
  int tokensApagados = 0;

  final _renovacoes = StreamController<String>.broadcast();
  final _toques = StreamController<String>.broadcast();

  FakePushService({
    this.disponivel = true,
    this.token = 'token_aparelho_01',
    this.alertaDeAbertura,
  });

  void simularRenovacao(String novo) {
    token = novo;
    _renovacoes.add(novo);
  }

  void simularToque(String alertaId) => _toques.add(alertaId);

  @override
  Future<String?> obterToken() async {
    pedidosDeToken++;
    if (erroAoObterToken != null) throw erroAoObterToken!;
    return token;
  }

  @override
  Stream<String> get tokenRenovado => _renovacoes.stream;

  @override
  Future<void> apagarToken() async {
    tokensApagados++;
    token = null;
  }

  @override
  Future<String?> alertaQueAbriuOApp() async {
    final alertaId = alertaDeAbertura;
    alertaDeAbertura = null;
    return alertaId;
  }

  @override
  Stream<String> get alertaTocado => _toques.stream;
}
