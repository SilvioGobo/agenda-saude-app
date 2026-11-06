import 'package:agenda_saude_app/core/services/telefone_service.dart';

// Substituto em memoria do discador para os testes: guarda os numeros
// chamados e responde se "abriu" o app de telefone.
class FakeTelefoneService implements TelefoneService {
  bool abreDiscador;
  final List<String> numerosChamados = [];

  FakeTelefoneService({this.abreDiscador = true});

  @override
  Future<bool> ligar(String numero) async {
    numerosChamados.add(numero);
    return abreDiscador;
  }
}
