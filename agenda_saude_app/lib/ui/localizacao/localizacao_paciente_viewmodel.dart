import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/services/mapa_service.dart';
import '../../data/repositories/localizacao_repository.dart';
import '../../domain/models/localizacao.dart';
import '../../domain/models/paciente.dart';

// Estado da tela "Localização" do acompanhante: a ultima posicao que o app do
// paciente enviou, em tempo real, com o endereco legivel e o atalho para o
// app de mapas.
class LocalizacaoPacienteViewModel extends ChangeNotifier {
  // Com o app do paciente aberto a posicao chega a cada minuto; passado este
  // tempo sem novidade, o app dele provavelmente esta fechado ou sem internet.
  static const Duration limiteDesatualizada = Duration(minutes: 15);

  final Paciente paciente;
  final LocalizacaoRepository _localizacaoRepository;
  final MapaService _mapaService;
  final DateTime Function() _agora;

  StreamSubscription<Localizacao?>? _assinatura;
  Timer? _relogio;
  bool _descartado = false;

  LocalizacaoPacienteViewModel({
    required this.paciente,
    LocalizacaoRepository? localizacaoRepository,
    MapaService? mapaService,
    DateTime Function()? agora,
  })  : _localizacaoRepository =
            localizacaoRepository ?? LocalizacaoRepository(),
        _mapaService = mapaService ?? MapaServiceImpl(),
        _agora = agora ?? DateTime.now {
    _escutar();
    // "Atualizada há X minutos" e o aviso de desatualizada dependem da hora
    // atual, entao a tela se redesenha a cada minuto mesmo sem dado novo.
    _relogio = Timer.periodic(const Duration(minutes: 1), (_) {
      notifyListeners();
    });
  }

  // Verdadeiro ate o Firestore entregar a primeira resposta.
  bool _carregando = true;
  bool get carregando => _carregando;

  // A leitura falhou (ex.: sem internet ou sem permissao).
  bool _erroDeLeitura = false;
  bool get erroDeLeitura => _erroDeLeitura;

  Localizacao? _localizacao;
  Localizacao? get localizacao => _localizacao;

  bool get compartilhando => _localizacao?.ativo ?? false;

  bool get temPosicao => compartilhando && _localizacao!.temPosicao;

  bool get desatualizada {
    final dataHora = _localizacao?.dataHora;
    if (!temPosicao || dataHora == null) return false;
    return _agora().difference(dataHora) > limiteDesatualizada;
  }

  DateTime agora() => _agora();

  String? _endereco;
  String? get endereco => _endereco;

  bool _buscandoEndereco = false;
  bool get buscandoEndereco => _buscandoEndereco;

  // Coordenadas (arredondadas) do endereco atual: so busca de novo quando o
  // paciente se mexe de verdade, nao a cada envio do mesmo lugar.
  String? _chaveEndereco;

  String get primeiroNome {
    final nome = paciente.nome.trim();
    return nome.isEmpty ? 'o paciente' : nome.split(RegExp(r'\s+')).first;
  }

  void _escutar() {
    _assinatura?.cancel();
    _assinatura =
        _localizacaoRepository.streamLocalizacao(paciente.id).listen(
      (localizacao) {
        _localizacao = localizacao;
        _carregando = false;
        _erroDeLeitura = false;
        notifyListeners();
        _atualizarEndereco();
      },
      onError: (Object erro) {
        debugPrint('Stream de localizacao falhou: $erro');
        _carregando = false;
        _erroDeLeitura = true;
        notifyListeners();
      },
    );
  }

  // Botao "Tentar novamente" quando a leitura falhou.
  void tentarNovamente() {
    _carregando = true;
    _erroDeLeitura = false;
    notifyListeners();
    _escutar();
  }

  Future<void> _atualizarEndereco() async {
    if (!temPosicao) return;
    final latitude = _localizacao!.latitude!;
    final longitude = _localizacao!.longitude!;
    // 4 casas decimais ~ 11 metros.
    final chave =
        '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
    if (chave == _chaveEndereco) return;

    _chaveEndereco = chave;
    _endereco = null;
    _buscandoEndereco = true;
    notifyListeners();

    final endereco = await _mapaService.enderecoDe(latitude, longitude);
    // Outra posicao chegou enquanto buscava: vale o endereco dela.
    if (chave != _chaveEndereco || _descartado) return;
    _endereco = endereco;
    _buscandoEndereco = false;
    notifyListeners();
  }

  // Retorna se conseguiu abrir o app de mapas.
  Future<bool> abrirNoMapa() async {
    if (!temPosicao) return false;
    return _mapaService.abrirNoMapa(
      _localizacao!.latitude!,
      _localizacao!.longitude!,
    );
  }

  @override
  void dispose() {
    _descartado = true;
    _assinatura?.cancel();
    _relogio?.cancel();
    super.dispose();
  }
}
