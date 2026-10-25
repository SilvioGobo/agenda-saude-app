import 'dart:async';

import 'package:agenda_saude_app/core/services/localizacao_service.dart';

// Substituto em memoria do GPS do celular para os testes: permissao, GPS e
// posicao sao definidos pelo teste.
class FakeLocalizacaoService implements LocalizacaoService {
  PermissaoLocalizacao permissao;
  PermissaoLocalizacao respostaAoSolicitar;
  bool gps;
  PosicaoGps posicao;
  Object? erroAoLer;
  // Quando definido, a leitura so termina quando o teste completar: simula
  // o GPS demorando a responder.
  Completer<PosicaoGps>? leituraPendente;

  int solicitacoesDePermissao = 0;
  int leiturasDePosicao = 0;
  int aberturasDasConfiguracoesDoApp = 0;
  int aberturasDasConfiguracoesDeLocalizacao = 0;

  FakeLocalizacaoService({
    this.permissao = PermissaoLocalizacao.concedida,
    this.respostaAoSolicitar = PermissaoLocalizacao.concedida,
    this.gps = true,
    PosicaoGps? posicao,
  }) : posicao = posicao ??
            PosicaoGps(
              latitude: -22.2210,
              longitude: -54.8056,
              precisaoMetros: 12,
              dataHora: DateTime(2026, 10, 25, 14, 0),
            );

  @override
  Future<bool> gpsLigado() async => gps;

  @override
  Future<PermissaoLocalizacao> verificarPermissao() async => permissao;

  @override
  Future<PermissaoLocalizacao> solicitarPermissao() async {
    solicitacoesDePermissao++;
    permissao = respostaAoSolicitar;
    return permissao;
  }

  @override
  Future<PosicaoGps> posicaoAtual() async {
    leiturasDePosicao++;
    if (leituraPendente != null) return leituraPendente!.future;
    if (erroAoLer != null) throw erroAoLer!;
    return posicao;
  }

  @override
  Future<void> abrirConfiguracoesDoApp() async {
    aberturasDasConfiguracoesDoApp++;
  }

  @override
  Future<void> abrirConfiguracoesDeLocalizacao() async {
    aberturasDasConfiguracoesDeLocalizacao++;
  }
}
