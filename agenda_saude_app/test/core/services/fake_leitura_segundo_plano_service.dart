import 'package:agenda_saude_app/core/services/leitura_segundo_plano_service.dart';

// Substituto em memoria do agendamento da leitura com o app fechado (B2/B7):
// guarda se a tarefa periodica esta ligada, se o app avisou que esta aberto
// e quantas vezes cada acao foi pedida.
class FakeLeituraSegundoPlanoService implements LeituraSegundoPlanoService {
  bool ligada;
  Object? erro;
  int leiturasAvulsas = 0;
  int desligamentos = 0;
  bool appAberto = false;

  FakeLeituraSegundoPlanoService({this.ligada = false});

  @override
  Future<bool> estaLigada() async => ligada;

  @override
  Future<void> ligar() async {
    if (erro != null) throw erro!;
    ligada = true;
  }

  @override
  Future<void> desligar() async {
    desligamentos++;
    ligada = false;
  }

  @override
  Future<void> lerUmaVezAgora() async {
    leiturasAvulsas++;
  }

  @override
  void avisarAppAberto(bool aberto) => appAberto = aberto;
}
