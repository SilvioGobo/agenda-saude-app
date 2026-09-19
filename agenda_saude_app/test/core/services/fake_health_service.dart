import 'package:agenda_saude_app/core/services/health_service.dart';

// Substituto em memoria do Health Connect para os testes: as leituras sao
// definidas pelo teste e filtradas pelo intervalo pedido, como o plugin faz.
class FakeHealthService implements HealthService {
  StatusHealthConnect status;
  bool permissaoConcedida;
  bool concederAoSolicitar;
  List<LeituraBpm> leituras;
  Object? erroAoLer;

  int solicitacoesDePermissao = 0;
  int aberturasDaLoja = 0;
  final List<({DateTime inicio, DateTime fim})> intervalosLidos = [];

  FakeHealthService({
    this.status = StatusHealthConnect.disponivel,
    this.permissaoConcedida = true,
    this.concederAoSolicitar = true,
    List<LeituraBpm>? leituras,
  }) : leituras = leituras ?? [];

  @override
  Future<StatusHealthConnect> verificarDisponibilidade() async => status;

  @override
  Future<void> abrirInstalacaoHealthConnect() async {
    aberturasDaLoja++;
  }

  @override
  Future<bool> temPermissaoBpm() async => permissaoConcedida;

  @override
  Future<bool> solicitarPermissaoBpm() async {
    solicitacoesDePermissao++;
    permissaoConcedida = concederAoSolicitar;
    return permissaoConcedida;
  }

  @override
  Future<List<LeituraBpm>> lerBatimentos({
    required DateTime inicio,
    required DateTime fim,
  }) async {
    intervalosLidos.add((inicio: inicio, fim: fim));
    if (erroAoLer != null) throw erroAoLer!;
    return leituras
        .where((l) => !l.timestamp.isBefore(inicio) && !l.timestamp.isAfter(fim))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }
}
