import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/services/health_service.dart';
import '../../core/services/leitura_segundo_plano_service.dart';
import '../../data/repositories/dados_repository.dart';
import '../../domain/batimentos/monitor_zona_seguranca.dart';
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
// Quando o painel do paciente passa a mostrar "ATENÇÃO" gera um alerta de
// atencao para o acompanhante (RF06); BPM fora da zona por tempo prolongado
// gera um alerta de emergencia (UC04.4 -> UC06). As regras dos alertas ficam
// em MonitorZonaSeguranca.
//
// Com o app fechado (B7, RF04.2), onde o Health Connect deixa e o paciente
// permite, a leitura continua a cada 15 minutos por uma tarefa do WorkManager
// (leitura_segundo_plano_service.dart). Este ViewModel liga essa tarefa com a
// permissao, desliga sem ela e mostra a situacao no cartao "COM O APP FECHADO".
class SincronizacaoBpmViewModel extends ChangeNotifier
    with WidgetsBindingObserver {
  final Paciente paciente;
  final HealthService _healthService;
  final DadosMedicosRepository _dadosRepository;
  final LeituraSegundoPlanoService _leituraComAppFechado;
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
    LeituraSegundoPlanoService? leituraComAppFechado,
    this.intervalo = const Duration(seconds: 30),
    DateTime Function()? agora,
    bool? plataformaSuportada,
  })  : _healthService = healthService ?? HealthServiceImpl(),
        _dadosRepository = dadosRepository ?? DadosMedicosRepository(),
        _leituraComAppFechado =
            leituraComAppFechado ?? LeituraSegundoPlanoServiceImpl(),
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

  // Leitura com o app fechado (B7). Null enquanto nao verificado.
  bool? _leituraAppFechadoDisponivel;
  bool? get leituraAppFechadoDisponivel => _leituraAppFechadoDisponivel;

  bool? _leituraAppFechadoPermitida;
  bool? get leituraAppFechadoPermitida => _leituraAppFechadoPermitida;

  // O Health Connect deste aparelho tem o recurso e o paciente permitiu.
  bool get leituraAppFechadoLigada =>
      (_leituraAppFechadoDisponivel ?? false) &&
      (_leituraAppFechadoPermitida ?? false);

  String? _mensagemLeituraAppFechado;
  String? get mensagemLeituraAppFechado => _mensagemLeituraAppFechado;

  Timer? _timer;
  bool _observandoCicloDeVida = false;
  bool _descartado = false;

  // Timestamps (em ms) das leituras da janela que ja estao no Firestore. Em vez
  // de importar so o que e mais novo que a ultima leitura, relemos a janela
  // inteira e ignoramos o que ja foi gravado: o relogio sincroniza em lote e
  // leituras antigas podem chegar ao Health Connect depois das mais novas.
  final Set<int> _timestampsGravados = {};
  bool _carregouGravados = false;

  // Episodio fora da zona e ultimo aviso de "ATENÇÃO", retomados do Firestore
  // junto com as leituras gravadas: o app pode ter sido fechado no meio de um
  // episodio, e a leitura com o app fechado pode ter gerado alertas.
  MonitorZonaSeguranca? _monitor;

  // Verifica Health Connect + permissao e, se tudo ok, comeca a sincronizar.
  Future<void> iniciar() async {
    if (!_plataformaSuportada) {
      _estado = EstadoSincronizacao.naoSuportado;
      _notificar();
      return;
    }

    _estado = EstadoSincronizacao.verificando;
    _mensagemErro = null;
    _notificar();

    try {
      _statusHealthConnect = await _healthService.verificarDisponibilidade();
      if (_statusHealthConnect == StatusHealthConnect.naoSuportado) {
        _estado = EstadoSincronizacao.naoSuportado;
        _notificar();
        return;
      }
      if (_statusHealthConnect != StatusHealthConnect.disponivel) {
        _estado = EstadoSincronizacao.healthConnectAusente;
        _notificar();
        return;
      }

      final temPermissao = await _healthService.temPermissaoBpm();
      if (!temPermissao) {
        _estado = EstadoSincronizacao.semPermissao;
        _notificar();
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
        _notificar();
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
    _notificar();

    if (!_observandoCicloDeVida) {
      WidgetsBinding.instance.addObserver(this);
      _observandoCicloDeVida = true;
    }
    _leituraComAppFechado.avisarAppAberto(true);

    await sincronizarAgora();
    _reiniciarTimer();
    await _atualizarLeituraComAppFechado();
  }

  void _reiniciarTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(intervalo, (_) => sincronizarAgora());
  }

  // Health Connect so pode ser lido com o app em primeiro plano (sem a
  // permissao de background), entao pausamos o polling quando ele sai de cena.
  // Fora da tela, quem le e a tarefa de 15 min, se estiver ligada (B7).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_estado != EstadoSincronizacao.ativa) return;

    if (state == AppLifecycleState.resumed) {
      _leituraComAppFechado.avisarAppAberto(true);
      // Enquanto o app esteve fora da tela, a leitura com o app fechado pode
      // ter gravado leituras e alertas: relemos a janela do Firestore.
      if (leituraAppFechadoLigada) _carregouGravados = false;
      sincronizarAgora();
      _reiniciarTimer();
      // O paciente pode ter mudado a permissao no Health Connect.
      _atualizarLeituraComAppFechado();
    } else {
      _timer?.cancel();
      _timer = null;
      _leituraComAppFechado.avisarAppAberto(false);
    }
  }

  Future<void> sincronizarAgora() async {
    if (_sincronizando || _estado != EstadoSincronizacao.ativa) return;
    _sincronizando = true;
    _notificar();

    try {
      final agora = _agora();

      final limiteJanela = agora.subtract(janelaMaxima);

      if (!_carregouGravados) {
        final gravados = await _dadosRepository.getBatimentosDesde(
          paciente.id,
          limiteJanela,
        );
        final alertas =
            await _dadosRepository.getAlertasDesde(paciente.id, limiteJanela);
        _timestampsGravados
          ..clear()
          ..addAll(gravados.map((b) => b.timestamp.millisecondsSinceEpoch));
        _monitor = MonitorZonaSeguranca.retomar(
          pacienteId: paciente.id,
          possuiCardiopatia: paciente.possuiCardiopatia,
          gravados: gravados,
          alertas: alertas,
        );
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
          .map((l) => BatimentoCardiaco(
                id: '',
                pacienteId: paciente.id,
                bpm: l.bpm,
                timestamp: l.timestamp,
              ))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (novas.isNotEmpty) {
        await _dadosRepository.salvarBatimentos(novas);
        _timestampsGravados
            .addAll(novas.map((l) => l.timestamp.millisecondsSinceEpoch));

        for (final alerta in _monitor!.avaliar(novas)) {
          await _dadosRepository.gerarAlerta(alerta);
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
      _notificar();
    }
  }

  // B7: a permissao do Health Connect e o liga/desliga da leitura com o app
  // fechado. Concedida, a tarefa fica agendada (se ja estava, mantem o
  // horario); tirada nas configuracoes do Health Connect, ou sem o recurso no
  // aparelho, a tarefa sai. Uma falha aqui nao atrapalha a leitura de 30 s.
  Future<void> _atualizarLeituraComAppFechado() async {
    try {
      final disponivel = await _healthService.leituraEmSegundoPlanoDisponivel();
      final permitida =
          disponivel && await _healthService.temPermissaoSegundoPlano();
      _leituraAppFechadoDisponivel = disponivel;
      _leituraAppFechadoPermitida = permitida;
      if (permitida) {
        await _leituraComAppFechado.ligar();
      } else {
        await _leituraComAppFechado.desligar();
      }
    } catch (e) {
      debugPrint('Falha ao conferir a leitura com o app fechado: $e');
    }
    _notificar();
  }

  // Botao "PERMITIR LEITURA COM O APP FECHADO": mostra o pedido do Health
  // Connect e, concedida a permissao, liga a leitura a cada 15 minutos.
  Future<void> permitirLeituraComAppFechado() async {
    try {
      final concedida = await _healthService.solicitarPermissaoSegundoPlano();
      _leituraAppFechadoPermitida = concedida;
      _mensagemLeituraAppFechado = concedida
          ? null
          : 'Permissão não concedida. Sem ela, o app só lê seus batimentos '
              'quando está aberto.';
      if (concedida) await _leituraComAppFechado.ligar();
    } catch (e) {
      debugPrint('Falha ao pedir a leitura com o app fechado: $e');
      _mensagemLeituraAppFechado =
          'Não foi possível pedir a permissão ao Health Connect.';
    }
    _notificar();
  }

  // Ao sair da conta: neste aparelho a leitura com o app fechado para, porque
  // nao tem mais para quem gravar.
  Future<void> desligarLeituraComAppFechado() async {
    try {
      await _leituraComAppFechado.desligar();
    } catch (e) {
      debugPrint('Falha ao desligar a leitura com o app fechado: $e');
    }
  }

  void _falhar(String mensagem, Object erro) {
    debugPrint('$mensagem ($erro)');
    _estado = EstadoSincronizacao.erro;
    _mensagemErro = mensagem;
    _notificar();
  }

  void _notificar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    _timer?.cancel();
    if (_observandoCicloDeVida) {
      WidgetsBinding.instance.removeObserver(this);
      _leituraComAppFechado.avisarAppAberto(false);
    }
    super.dispose();
  }
}
