import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/constants/zona_seguranca_cardiaca.dart';
import '../../core/services/health_service.dart';
import '../../data/repositories/dados_repository.dart';
import '../../domain/models/alerta.dart';
import '../../domain/models/batimento_cardiaco.dart';
import '../../domain/models/paciente.dart';

enum EstadoSincronizacao {
  verificando,
  naoSuportado, // plataforma sem Health Connect (web, desktop, iOS por enquanto)
  healthConnectAusente, // nao instalado ou desatualizado
  semPermissao,
  ativa,
  erro,
}

// Modulo de Sincronizacao IoT (RF004): enquanto o app esta em primeiro plano,
// le periodicamente o BPM do smartwatch via Health Connect, grava as leituras
// novas em `batimentos_cardiacos` e valida a zona de seguranca cardiaca.
// BPM fora da zona por tempo prolongado gera um Alerta (UC04.4 -> UC06).
//
// Leitura com o app fechado (background) fica para uma etapa posterior.
class SincronizacaoBpmViewModel extends ChangeNotifier
    with WidgetsBindingObserver {
  final Paciente paciente;
  final HealthService _healthService;
  final DadosMedicosRepository _dadosRepository;
  final Duration intervalo;
  final DateTime Function() _agora;
  final bool _plataformaSuportada;

  // Quanto de historico reler a cada sincronizacao - evita importar dias de
  // amostras de uma vez ao reabrir o app.
  static const Duration janelaMaxima = Duration(hours: 12);

  SincronizacaoBpmViewModel({
    required this.paciente,
    HealthService? healthService,
    DadosMedicosRepository? dadosRepository,
    this.intervalo = const Duration(seconds: 30),
    DateTime Function()? agora,
    bool? plataformaSuportada,
  })  : _healthService = healthService ?? HealthServiceImpl(),
        _dadosRepository = dadosRepository ?? DadosMedicosRepository(),
        _agora = agora ?? DateTime.now,
        _plataformaSuportada = plataformaSuportada ??
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  EstadoSincronizacao _estado = EstadoSincronizacao.verificando;
  EstadoSincronizacao get estado => _estado;

  StatusHealthConnect? _statusHealthConnect;
  StatusHealthConnect? get statusHealthConnect => _statusHealthConnect;

  DateTime? _ultimaSincronizacao;
  DateTime? get ultimaSincronizacao => _ultimaSincronizacao;

  int _leiturasImportadasNaUltima = 0;
  int get leiturasImportadasNaUltima => _leiturasImportadasNaUltima;

  bool _sincronizando = false;
  bool get sincronizando => _sincronizando;

  String? _mensagemErro;
  String? get mensagemErro => _mensagemErro;

  Timer? _timer;
  bool _observandoCicloDeVida = false;

  // Timestamps (em ms) das leituras da janela que ja estao no Firestore. Em vez
  // de importar so o que e mais novo que a ultima leitura, relemos a janela
  // inteira e ignoramos o que ja foi gravado: o relogio sincroniza em lote e
  // leituras antigas podem chegar ao Health Connect depois das mais novas.
  final Set<int> _timestampsGravados = {};
  bool _carregouGravados = false;

  // Estado do episodio atual fora da zona de seguranca (UC04.4).
  DateTime? _inicioForaDaZona;
  bool _alertaGeradoNesteEpisodio = false;

  // Verifica Health Connect + permissao e, se tudo ok, comeca a sincronizar.
  Future<void> iniciar() async {
    if (!_plataformaSuportada) {
      _estado = EstadoSincronizacao.naoSuportado;
      notifyListeners();
      return;
    }

    _estado = EstadoSincronizacao.verificando;
    _mensagemErro = null;
    notifyListeners();

    try {
      _statusHealthConnect = await _healthService.verificarDisponibilidade();
      if (_statusHealthConnect == StatusHealthConnect.naoSuportado) {
        _estado = EstadoSincronizacao.naoSuportado;
        notifyListeners();
        return;
      }
      if (_statusHealthConnect != StatusHealthConnect.disponivel) {
        _estado = EstadoSincronizacao.healthConnectAusente;
        notifyListeners();
        return;
      }

      final temPermissao = await _healthService.temPermissaoBpm();
      if (!temPermissao) {
        _estado = EstadoSincronizacao.semPermissao;
        notifyListeners();
        return;
      }

      await _ativar();
    } catch (e) {
      _falhar('Não foi possível acessar o smartwatch.', e);
    }
  }

  // Botao "Conectar smartwatch": abre a tela de permissoes do Health Connect.
  Future<void> conectar() async {
    try {
      final concedida = await _healthService.solicitarPermissaoBpm();
      if (!concedida) {
        _estado = EstadoSincronizacao.semPermissao;
        _mensagemErro = 'Permissão não concedida. Sem ela o app não consegue '
            'ler seus batimentos. Se a janela de permissão não aparecer, '
            'libere o acesso nas configurações do Health Connect.';
        notifyListeners();
        return;
      }
      await _ativar();
    } catch (e) {
      _falhar('Não foi possível pedir a permissão ao Health Connect.', e);
    }
  }

  Future<void> abrirConfiguracoesHealthConnect() async {
    try {
      await _healthService.abrirConfiguracoesHealthConnect();
    } catch (e) {
      _falhar('Não foi possível abrir as configurações do Health Connect.', e);
    }
  }

  Future<void> instalarHealthConnect() async {
    try {
      await _healthService.abrirInstalacaoHealthConnect();
    } catch (e) {
      _falhar('Não foi possível abrir a loja para instalar o Health Connect.', e);
    }
  }

  Future<void> _ativar() async {
    _estado = EstadoSincronizacao.ativa;
    _mensagemErro = null;
    notifyListeners();

    if (!_observandoCicloDeVida) {
      WidgetsBinding.instance.addObserver(this);
      _observandoCicloDeVida = true;
    }

    await sincronizarAgora();
    _reiniciarTimer();
  }

  void _reiniciarTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(intervalo, (_) => sincronizarAgora());
  }

  // Health Connect so pode ser lido com o app em primeiro plano (sem a
  // permissao de background), entao pausamos o polling quando ele sai de cena.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_estado != EstadoSincronizacao.ativa) return;

    if (state == AppLifecycleState.resumed) {
      sincronizarAgora();
      _reiniciarTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> sincronizarAgora() async {
    if (_sincronizando || _estado != EstadoSincronizacao.ativa) return;
    _sincronizando = true;
    notifyListeners();

    try {
      final agora = _agora();

      final limiteJanela = agora.subtract(janelaMaxima);

      if (!_carregouGravados) {
        final gravados = await _dadosRepository.getBatimentosDesde(
          paciente.id,
          limiteJanela,
        );
        _timestampsGravados
            .addAll(gravados.map((b) => b.timestamp.millisecondsSinceEpoch));
        _carregouGravados = true;
      }
      final limiteMs = limiteJanela.millisecondsSinceEpoch;
      _timestampsGravados.removeWhere((ms) => ms < limiteMs);

      final leituras = await _healthService.lerBatimentos(
        inicio: limiteJanela,
        fim: agora,
      );

      final novas = leituras
          .where((l) =>
              !_timestampsGravados.contains(l.timestamp.millisecondsSinceEpoch))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (novas.isNotEmpty) {
        await _dadosRepository.salvarBatimentos(
          novas
              .map((l) => BatimentoCardiaco(
                    id: '',
                    pacienteId: paciente.id,
                    bpm: l.bpm,
                    timestamp: l.timestamp,
                  ))
              .toList(),
        );
        _timestampsGravados
            .addAll(novas.map((l) => l.timestamp.millisecondsSinceEpoch));

        for (final leitura in novas) {
          await _avaliarZonaDeSeguranca(leitura);
        }
      }

      _ultimaSincronizacao = agora;
      _leiturasImportadasNaUltima = novas.length;
      _mensagemErro = null;
    } catch (e) {
      debugPrint('Sincronizacao de BPM falhou: $e');
      _mensagemErro = 'Falha ao sincronizar com o smartwatch.';
    } finally {
      _sincronizando = false;
      notifyListeners();
    }
  }

  // UC04.4: leituras fora da zona por `tempoProlongadoParaAlerta` seguidos
  // geram um unico alerta por episodio; voltar para a zona encerra o episodio.
  Future<void> _avaliarZonaDeSeguranca(LeituraBpm leitura) async {
    final dentroDaZona = ZonaSegurancaCardiaca.estaDentroDaZona(
      leitura.bpm,
      possuiCardiopatia: paciente.possuiCardiopatia,
    );

    if (dentroDaZona) {
      _inicioForaDaZona = null;
      _alertaGeradoNesteEpisodio = false;
      return;
    }

    _inicioForaDaZona ??= leitura.timestamp;
    final duracao = leitura.timestamp.difference(_inicioForaDaZona!);

    if (_alertaGeradoNesteEpisodio ||
        duracao < ZonaSegurancaCardiaca.tempoProlongadoParaAlerta) {
      return;
    }

    await _dadosRepository.gerarAlerta(Alerta(
      id: '',
      pacienteId: paciente.id,
      mensagem: 'Batimentos fora da zona de segurança há '
          '${duracao.inMinutes} minutos (última leitura: ${leitura.bpm} BPM).',
      dataHora: leitura.timestamp,
    ));
    _alertaGeradoNesteEpisodio = true;
  }

  void _falhar(String mensagem, Object erro) {
    debugPrint('$mensagem ($erro)');
    _estado = EstadoSincronizacao.erro;
    _mensagemErro = mensagem;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_observandoCicloDeVida) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }
}
