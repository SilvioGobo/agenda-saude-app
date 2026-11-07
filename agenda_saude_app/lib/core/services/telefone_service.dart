import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

// Contrato da ligacao telefonica (Figuras 13 e 16 do TCC): abre o discador
// do celular com o numero ja digitado. O Android nao deixa o app completar a
// chamada sozinho sem uma permissao perigosa (CALL_PHONE); com o discador a
// pessoa so confirma. As telas dependem so desta interface, entao nos testes
// basta injetar um fake em memoria.
abstract class TelefoneService {
  // Retorna se conseguiu abrir o discador.
  Future<bool> ligar(String numero);
}

// O numero como o discador espera: so os digitos, mais o "+" do codigo do
// pais quando houver. "(67) 99999-0000" vira "67999990000".
String numeroParaDiscar(String numero) {
  final limpo = numero.trim();
  final digitos = limpo.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitos.isEmpty) return '';
  return limpo.startsWith('+') ? '+$digitos' : digitos;
}

// O telefone para mostrar na tela: "(67) 99999-0000" (celular com DDD) ou
// "(67) 3411-2233" (fixo com DDD). Outros formatos ficam como vieram.
String formatarTelefone(String numero) {
  final digitos = numeroParaDiscar(numero);
  if (digitos.length == 11) {
    return '(${digitos.substring(0, 2)}) ${digitos.substring(2, 7)}-'
        '${digitos.substring(7)}';
  }
  if (digitos.length == 10) {
    return '(${digitos.substring(0, 2)}) ${digitos.substring(2, 6)}-'
        '${digitos.substring(6)}';
  }
  return numero.trim();
}

// O telefone como o app guarda no cadastro: so os digitos, com DDD
// ("67999990000"). Aceita o que a pessoa digitar - "(67) 99999-0000",
// "67 3411-2233", "+55 67 99999-0000" - e devolve null quando nao e um
// telefone brasileiro com DDD: celular de 11 digitos (comeca com 9 depois do
// DDD) ou fixo de 10 (comeca de 2 a 5). O DDD vai de 11 a 99, sem zero no fim.
String? normalizarTelefone(String entrada) {
  var digitos = entrada.replaceAll(RegExp(r'[^0-9]'), '');

  // Codigo do pais (+55): so sai quando sobra um numero completo. Um celular
  // de DDD 55 digitado sem ele ("55999990000") tem 11 digitos e fica como esta.
  if (digitos.length >= 12 && digitos.startsWith('55')) {
    digitos = digitos.substring(2);
  }
  if (digitos.length != 10 && digitos.length != 11) return null;

  final ddd = int.parse(digitos.substring(0, 2));
  if (ddd < 11 || ddd % 10 == 0) return null;

  final primeiroDigito = digitos[2];
  final celular = digitos.length == 11;
  if (celular ? primeiroDigito != '9' : !'2345'.contains(primeiroDigito)) {
    return null;
  }
  return digitos;
}

// Implementacao real: link `tel:` pelo plugin `url_launcher`, que abre o app
// de telefone do celular.
class TelefoneServiceImpl implements TelefoneService {
  @override
  Future<bool> ligar(String numero) async {
    final paraDiscar = numeroParaDiscar(numero);
    if (paraDiscar.isEmpty) return false;
    try {
      return await launchUrl(Uri(scheme: 'tel', path: paraDiscar));
    } catch (erro) {
      debugPrint('Falha ao abrir o discador: $erro');
      return false;
    }
  }
}
