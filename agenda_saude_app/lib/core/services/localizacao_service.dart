import 'dart:async';

import 'package:geolocator/geolocator.dart';

// Situacao da permissao de localizacao do app no aparelho.
enum PermissaoLocalizacao {
  concedida,
  negada, // ainda da para mostrar o pedido do sistema de novo
  bloqueada, // "nao perguntar novamente": so liberando nas configuracoes
}

// Uma posicao medida pelo GPS do celular, ainda sem paciente associado.
class PosicaoGps {
  final double latitude;
  final double longitude;
  final double precisaoMetros;
  final DateTime dataHora;

  const PosicaoGps({
    required this.latitude,
    required this.longitude,
    required this.precisaoMetros,
    required this.dataHora,
  });
}

// A localizacao do celular (GPS) esta desligada nas configuracoes.
class GpsDesligadoException implements Exception {}

// O app perdeu a permissao de localizacao (ex.: revogada nas configuracoes).
class SemPermissaoLocalizacaoException implements Exception {}

// Contrato do acesso ao GPS do celular do paciente. A logica de
// compartilhamento depende so desta interface, entao nos testes basta
// injetar um fake em memoria.
abstract class LocalizacaoService {
  Future<bool> gpsLigado();

  Future<PermissaoLocalizacao> verificarPermissao();

  // Mostra o pedido de permissao do sistema ("Permitir durante o uso do
  // app"); retorna a situacao depois da resposta.
  Future<PermissaoLocalizacao> solicitarPermissao();

  // Posicao atual do celular. Lanca [GpsDesligadoException] ou
  // [SemPermissaoLocalizacaoException] quando nao da para medir.
  Future<PosicaoGps> posicaoAtual();

  // Necessario quando o usuario bloqueou a permissao e o Android nao mostra
  // mais o pedido.
  Future<void> abrirConfiguracoesDoApp();

  // Tela do sistema para ligar a localizacao (GPS) do celular.
  Future<void> abrirConfiguracoesDeLocalizacao();
}

// Implementacao real em cima do plugin `geolocator`. So pede a permissao "em
// uso": a localizacao e lida com o app aberto, sem rastrear em segundo plano.
class LocalizacaoServiceImpl implements LocalizacaoService {
  // Dentro de casa o GPS pode demorar a responder; passado esse tempo vale a
  // ultima posicao que o celular ja conhecia.
  static const _tempoLimite = Duration(seconds: 20);

  @override
  Future<bool> gpsLigado() => Geolocator.isLocationServiceEnabled();

  @override
  Future<PermissaoLocalizacao> verificarPermissao() async =>
      _converter(await Geolocator.checkPermission());

  @override
  Future<PermissaoLocalizacao> solicitarPermissao() async =>
      _converter(await Geolocator.requestPermission());

  static PermissaoLocalizacao _converter(LocationPermission permissao) {
    switch (permissao) {
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return PermissaoLocalizacao.concedida;
      case LocationPermission.deniedForever:
        return PermissaoLocalizacao.bloqueada;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return PermissaoLocalizacao.negada;
    }
  }

  @override
  Future<PosicaoGps> posicaoAtual() async {
    try {
      final posicao = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _tempoLimite,
        ),
      );
      return _converterPosicao(posicao);
    } on TimeoutException {
      final ultima = await Geolocator.getLastKnownPosition();
      if (ultima == null) rethrow;
      return _converterPosicao(ultima);
    } on LocationServiceDisabledException {
      throw GpsDesligadoException();
    } on PermissionDeniedException {
      throw SemPermissaoLocalizacaoException();
    }
  }

  static PosicaoGps _converterPosicao(Position posicao) {
    return PosicaoGps(
      latitude: posicao.latitude,
      longitude: posicao.longitude,
      precisaoMetros: posicao.accuracy,
      dataHora: posicao.timestamp,
    );
  }

  @override
  Future<void> abrirConfiguracoesDoApp() async {
    await Geolocator.openAppSettings();
  }

  @override
  Future<void> abrirConfiguracoesDeLocalizacao() async {
    await Geolocator.openLocationSettings();
  }
}
