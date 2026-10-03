import 'dart:async';

import 'package:agenda_saude_app/core/services/notification_service.dart';

// Substituto em memoria das notificacoes do aparelho para os testes: guarda o
// que seria mostrado na bandeja e permite simular o toque numa notificacao.
class FakeNotificationService implements NotificationService {
  @override
  bool disponivel;
  bool permitidas;
  bool concederAoSolicitar;

  int inicializacoes = 0;
  int solicitacoesDePermissao = 0;
  int aberturasDasConfiguracoes = 0;
  final List<({int id, String titulo, String texto, bool urgente, String? payload})>
      mostradas = [];
  final List<int> canceladas = [];

  final _toques = StreamController<String>.broadcast();

  FakeNotificationService({
    this.disponivel = true,
    this.permitidas = true,
    this.concederAoSolicitar = true,
  });

  void simularToque(String payload) => _toques.add(payload);

  @override
  Future<void> inicializar() async {
    inicializacoes++;
  }

  @override
  Future<bool> notificacoesPermitidas() async => permitidas;

  @override
  Future<bool> solicitarPermissao() async {
    solicitacoesDePermissao++;
    if (concederAoSolicitar) permitidas = true;
    return permitidas;
  }

  @override
  Future<void> abrirConfiguracoes() async {
    aberturasDasConfiguracoes++;
  }

  @override
  Future<void> mostrar({
    required int id,
    required String titulo,
    required String texto,
    required DateTime dataHora,
    bool urgente = false,
    String? payload,
  }) async {
    mostradas.add((
      id: id,
      titulo: titulo,
      texto: texto,
      urgente: urgente,
      payload: payload,
    ));
  }

  @override
  Future<void> cancelar(int id) async {
    canceladas.add(id);
  }

  @override
  Stream<String> get toques => _toques.stream;
}
