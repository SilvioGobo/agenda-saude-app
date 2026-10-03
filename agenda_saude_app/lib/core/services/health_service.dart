import 'package:flutter/services.dart';
import 'package:health/health.dart';

// Situacao do Health Connect no aparelho (Android). O smartwatch nao fala
// direto com o app: o aplicativo da marca do relogio (Samsung Health, Mi
// Fitness, Zepp...) sincroniza com o Health Connect, e o app le de la.
enum StatusHealthConnect {
  disponivel,
  naoInstalado,
  precisaAtualizar,
  naoSuportado,
}

// Uma leitura de BPM vinda do Health Connect, ainda sem paciente associado.
class LeituraBpm {
  final int bpm;
  final DateTime timestamp;

  const LeituraBpm({required this.bpm, required this.timestamp});
}

// Contrato do acesso ao smartwatch (RF004). A logica de sincronizacao depende
// so desta interface, entao nos testes basta injetar um fake em memoria.
abstract class HealthService {
  Future<StatusHealthConnect> verificarDisponibilidade();

  // Abre a loja para instalar/atualizar o Health Connect.
  Future<void> abrirInstalacaoHealthConnect();

  Future<bool> temPermissaoBpm();

  // Mostra a tela de permissoes do Health Connect; retorna se foi concedida.
  Future<bool> solicitarPermissaoBpm();

  // Abre as configuracoes do Health Connect. Necessario quando o usuario ja
  // negou a permissao e o Android nao mostra mais o pop-up.
  Future<void> abrirConfiguracoesHealthConnect();

  // Leituras de BPM registradas entre [inicio] e [fim], da mais antiga para
  // a mais recente.
  Future<List<LeituraBpm>> lerBatimentos({
    required DateTime inicio,
    required DateTime fim,
  });
}

// Implementacao real em cima do plugin `health`.
class HealthServiceImpl implements HealthService {
  static const _canal = MethodChannel('agenda_saude_app/health_connect');

  final Health _health;
  bool _configurado = false;

  static const _tipos = [HealthDataType.HEART_RATE];
  static const _permissoes = [HealthDataAccess.READ];

  HealthServiceImpl({Health? health}) : _health = health ?? Health();

  // O plugin exige configure() uma vez antes de qualquer chamada.
  Future<void> _garantirConfigurado() async {
    if (_configurado) return;
    await _health.configure();
    _configurado = true;
  }

  @override
  Future<StatusHealthConnect> verificarDisponibilidade() async {
    await _garantirConfigurado();
    final status = await _health.getHealthConnectSdkStatus();
    switch (status) {
      case HealthConnectSdkStatus.sdkAvailable:
        return StatusHealthConnect.disponivel;
      case HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired:
        return StatusHealthConnect.precisaAtualizar;
      case HealthConnectSdkStatus.sdkUnavailable:
        return StatusHealthConnect.naoInstalado;
      case null:
        return StatusHealthConnect.naoSuportado;
    }
  }

  @override
  Future<void> abrirInstalacaoHealthConnect() async {
    await _garantirConfigurado();
    await _health.installHealthConnect();
  }

  @override
  Future<bool> temPermissaoBpm() async {
    await _garantirConfigurado();
    final tem = await _health.hasPermissions(_tipos, permissions: _permissoes);
    return tem ?? false;
  }

  @override
  Future<bool> solicitarPermissaoBpm() async {
    await _garantirConfigurado();
    return _health.requestAuthorization(_tipos, permissions: _permissoes);
  }

  @override
  Future<void> abrirConfiguracoesHealthConnect() async {
    await _canal.invokeMethod<bool>('abrirConfiguracoes');
  }

  @override
  Future<List<LeituraBpm>> lerBatimentos({
    required DateTime inicio,
    required DateTime fim,
  }) async {
    await _garantirConfigurado();
    final pontos = await _health.getHealthDataFromTypes(
      types: _tipos,
      startTime: inicio,
      endTime: fim,
    );

    final leituras = _health
        .removeDuplicates(pontos)
        .where((p) => p.value is NumericHealthValue)
        .map((p) => LeituraBpm(
              bpm: (p.value as NumericHealthValue).numericValue.round(),
              timestamp: p.dateFrom,
            ))
        .where((l) => l.bpm > 0)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return leituras;
  }
}
