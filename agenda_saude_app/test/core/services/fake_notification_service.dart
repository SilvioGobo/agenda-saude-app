import 'dart:async';

import 'package:agenda_saude_app/core/services/notification_service.dart';

// Uma notificacao agendada no fake: o que o aparelho tocaria e quando.
typedef AgendamentoFalso = ({
  String titulo,
  String texto,
  DateTime dataHora,
  String? payload,
});

// Substituto em memoria das notificacoes do aparelho para os testes: guarda o
// que seria mostrado na bandeja e o que ficou agendado, e permite simular o
// toque numa notificacao.
class FakeNotificationService implements NotificationService {
  @override
  bool disponivel;
  bool permitidas;
  bool concederAoSolicitar;
  // Alarme exato permitido (Android 12+); o pedido o concede se
  // [concederAlarmeExatoAoSolicitar].
  bool alarmesExatos;
  bool concederAlarmeExatoAoSolicitar;

  int inicializacoes = 0;
  int solicitacoesDePermissao = 0;
  int aberturasDasConfiguracoes = 0;
  int solicitacoesDeAlarmeExato = 0;
  // Quantas vezes um lembrete foi agendado, contando as repeticoes do mesmo id.
  int agendamentos = 0;
  final List<({int id, String titulo, String texto, bool urgente, String? payload})>
      mostradas = [];
  final List<int> canceladas = [];
  // As notificacoes agendadas e ainda nao tocadas, por id.
  final Map<int, AgendamentoFalso> agendadas = {};

  final _toques = StreamController<String>.broadcast();

  FakeNotificationService({
    this.disponivel = true,
    this.permitidas = true,
    this.concederAoSolicitar = true,
    this.alarmesExatos = true,
    this.concederAlarmeExatoAoSolicitar = true,
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

  // Como o plugin: cancelar tira da bandeja e tambem desfaz o agendamento.
  @override
  Future<void> cancelar(int id) async {
    canceladas.add(id);
    agendadas.remove(id);
  }

  @override
  Future<void> agendarLembrete({
    required int id,
    required String titulo,
    required String texto,
    required DateTime dataHora,
    String? payload,
  }) async {
    agendamentos++;
    agendadas[id] = (
      titulo: titulo,
      texto: texto,
      dataHora: dataHora,
      payload: payload,
    );
  }

  @override
  Future<List<int>> idsAgendados({required String prefixoDoPayload}) async {
    return [
      for (final entrada in agendadas.entries)
        if (entrada.value.payload?.startsWith(prefixoDoPayload) ?? false)
          entrada.key,
    ];
  }

  @override
  Future<bool> alarmesExatosPermitidos() async => alarmesExatos;

  @override
  Future<void> solicitarAlarmesExatos() async {
    solicitacoesDeAlarmeExato++;
    if (concederAlarmeExatoAoSolicitar) alarmesExatos = true;
  }

  @override
  Stream<String> get toques => _toques.stream;
}
