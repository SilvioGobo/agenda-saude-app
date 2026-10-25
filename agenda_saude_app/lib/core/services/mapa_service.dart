import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

// Contrato do que o acompanhante faz com a localizacao do paciente: ler o
// endereco e abrir o ponto no app de mapas. A tela depende so desta
// interface, entao nos testes basta injetar um fake em memoria.
abstract class MapaService {
  // Endereco legivel das coordenadas ("Rua das Flores, 120 - Centro,
  // Dourados") ou null quando o celular nao consegue descobrir (sem
  // internet, sem servico de endereco no aparelho...).
  Future<String?> enderecoDe(double latitude, double longitude);

  // Abre o app de mapas do celular com um alfinete nas coordenadas; retorna
  // se conseguiu abrir.
  Future<bool> abrirNoMapa(double latitude, double longitude);
}

// Junta as partes do endereco no formato brasileiro, pulando as que vierem
// vazias. Null quando nao ha nem rua nem bairro nem cidade.
String? montarEndereco({
  String? rua,
  String? numero,
  String? bairro,
  String? cidade,
}) {
  String? limpo(String? texto) {
    final valor = texto?.trim() ?? '';
    return valor.isEmpty ? null : valor;
  }

  final ruaLimpa = limpo(rua);
  final numeroLimpo = limpo(numero);
  final logradouro = ruaLimpa == null
      ? null
      : (numeroLimpo == null ? ruaLimpa : '$ruaLimpa, $numeroLimpo');
  final regiao = [limpo(bairro), limpo(cidade)].whereType<String>().join(', ');

  final partes = [logradouro, if (regiao.isNotEmpty) regiao]
      .whereType<String>()
      .toList();
  return partes.isEmpty ? null : partes.join(' - ');
}

// Implementacao real: endereco pelo servico do proprio sistema (plugin
// `geocoding`, sem chave de API) e mapa pelo link do Google Maps, que abre o
// app de mapas instalado ou o navegador.
class MapaServiceImpl implements MapaService {
  Geocoding? _geocoding;

  @override
  Future<String?> enderecoDe(double latitude, double longitude) async {
    try {
      // Criado so no primeiro uso: em plataforma sem o plugin (web,
      // desktop) o construtor ja falha.
      _geocoding ??= Geocoding(locale: const Locale('pt', 'BR'));
      final lugares =
          await _geocoding!.placemarkFromCoordinates(latitude, longitude);
      if (lugares.isEmpty) return null;
      final lugar = lugares.first;
      return montarEndereco(
        rua: lugar.thoroughfare ?? lugar.street,
        numero: lugar.subThoroughfare,
        bairro: lugar.subLocality,
        // No Brasil o Android costuma trazer a cidade em
        // subAdministrativeArea e deixar locality vazio.
        cidade: lugar.locality?.trim().isNotEmpty == true
            ? lugar.locality
            : lugar.subAdministrativeArea,
      );
    } catch (erro) {
      debugPrint('Falha ao buscar o endereco: $erro');
      return null;
    }
  }

  @override
  Future<bool> abrirNoMapa(double latitude, double longitude) async {
    final link = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$latitude,$longitude',
    });
    try {
      return await launchUrl(link, mode: LaunchMode.externalApplication);
    } catch (erro) {
      debugPrint('Falha ao abrir o mapa: $erro');
      return false;
    }
  }
}
