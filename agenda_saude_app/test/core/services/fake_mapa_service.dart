import 'package:agenda_saude_app/core/services/mapa_service.dart';

// Substituto em memoria do endereco e do app de mapas para os testes: guarda
// as coordenadas pedidas e responde com o endereco definido pelo teste.
class FakeMapaService implements MapaService {
  String? endereco;
  bool abreMapa;

  final List<({double latitude, double longitude})> enderecosPedidos = [];
  final List<({double latitude, double longitude})> mapasAbertos = [];

  FakeMapaService({
    this.endereco = 'Rua das Flores, 120 - Centro, Dourados',
    this.abreMapa = true,
  });

  @override
  Future<String?> enderecoDe(double latitude, double longitude) async {
    enderecosPedidos.add((latitude: latitude, longitude: longitude));
    return endereco;
  }

  @override
  Future<bool> abrirNoMapa(double latitude, double longitude) async {
    mapasAbertos.add((latitude: latitude, longitude: longitude));
    return abreMapa;
  }
}
