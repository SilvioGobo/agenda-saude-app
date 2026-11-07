import 'package:agenda_saude_app/core/services/leitura_segundo_plano_service.dart';

// Substituto em memoria do agendamento da leitura com o app fechado (teste
// B2): guarda se a tarefa periodica esta ligada e quantas vezes cada acao
// foi pedida.
class FakeLeituraSegundoPlanoService implements LeituraSegundoPlanoService {
  bool ligada;
  Object? erro;
  int leiturasAvulsas = 0;

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
    ligada = false;
  }

  @override
  Future<void> lerUmaVezAgora() async {
    leiturasAvulsas++;
  }
}
