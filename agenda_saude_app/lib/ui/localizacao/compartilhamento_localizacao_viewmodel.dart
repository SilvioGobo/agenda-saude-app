import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/services/localizacao_service.dart';
import '../../data/repositories/localizacao_repository.dart';
import '../../domain/models/localizacao.dart';
import '../../domain/models/paciente.dart';

enum EstadoCompartilhamento {
  verificando,
  naoSuportado, // plataforma sem GPS do celular (web, desktop)
  desligado, // o paciente nao ligou o compartilhamento (ou desligou)
  semPermissao,
  gpsDesligado, // localizacao do celular desligada nas configuracoes
  ativo,
  erro,
}

// Lado do paciente da localizacao: com o compartilhamento ligado, enquanto o
// app esta em primeiro plano, mede a posicao pelo GPS a cada [intervalo] e
// grava em `localizacoes/{pacienteId}` para os acompanhantes vinculados
// verem onde ele esta.
//
// O paciente liga e desliga pela tela "Minha localização" (menu); a escolha
// fica salva no Firestore e o app retoma sozinho ao ser aberto. Leitura com o
// app fechado (background) exigiria a permissao "o tempo todo" e fica para
// uma etapa posterior, como na sincronizacao de BPM.
class CompartilhamentoLocalizacaoViewModel extends ChangeNotifier
    with WidgetsBindingObserver {
  final Paciente paciente;
  final LocalizacaoService _localizacaoService;
  final LocalizacaoRepository _localizacaoRepository;
  final Duration intervalo;
  final bool _plataformaSuportada;

  CompartilhamentoLocalizacaoViewModel({
    required this.paciente,
    LocalizacaoService? localizacaoService,
    LocalizacaoRepository? localizacaoRepository,
    this.intervalo = const Duration(minutes: 1),
    bool? plataformaSuportada,
  })  : _localizacaoService = localizacaoService ?? LocalizacaoServiceImpl(),
        _localizacaoRepository =
            localizacaoRepository ?? LocalizacaoRepository(),
        _plataformaSuportada = plataformaSuportada ??
            (!kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS));

  EstadoCompartilhamento _estado = EstadoCompartilhamento.verificando;
  EstadoCompartilhamento get estado => _estado;

  // O paciente quer compartilhar (gravado no Firestore), mesmo que agora
  // falte permissao ou o GPS esteja desligado.
  bool _compartilhamentoLigado = false;
  bool get compartilhamentoLigado => _compartilhamentoLigado;

  // Permissao negada com "nao perguntar novamente": so pelas configuracoes.
  bool _permissaoBloqueada = false;
  bool get permissaoBloqueada => _permissaoBloqueada;

  // Horario (do GPS) da ultima posicao enviada ao acompanhante.
  DateTime? _ultimaAtualizacao;
  DateTime? get ultimaAtualizacao => _ultimaAtualizacao;

  bool _atualizando = false;
  bool get atualizando => _atualizando;

  // Verdadeiro enquanto liga/desliga: a tela desabilita os botoes.
  bool _ocupado = false;
  bool get ocupado => _ocupado;

  String? _mensagemErro;
  String? get mensagemErro => _mensagemErro;

  Timer? _timer;
  bool _observandoCicloDeVida = false;

  // Le a escolha salva e, se o paciente compartilha, volta a enviar a posicao.
  Future<void> iniciar() async {
    if (!_plataformaSuportada) {
      _estado = EstadoCompartilhamento.naoSuportado;
      notifyListeners();
      return;
    }

    if (!_observandoCicloDeVida) {
      WidgetsBinding.instance.addObserver(this);
      _observandoCicloDeVida = true;
    }

    _estado = EstadoCompartilhamento.verificando;
    _mensagemErro = null;
    _ocupado = true;
    notifyListeners();

    try {
      final salva =
          await _localizacaoRepository.getLocalizacao(paciente.id);
      _compartilhamentoLigado = salva?.ativo ?? false;
      _ultimaAtualizacao = salva?.dataHora;
      if (_compartilhamentoLigado) {
        await _ligar(pedirPermissao: false);
      } else {
        _estado = EstadoCompartilhamento.desligado;
      }
    } catch (e) {
      _falhar('Não foi possível verificar sua localização.', e);
    } finally {
      _ocupado = false;
      notifyListeners();
    }
  }

  // Botao "Compartilhar minha localização" / "Permitir localização": mostra
  // o pedido de permissao do sistema e, se concedida, liga o compartilhamento.
  Future<void> ativar() async {
    if (_ocupado) return;
    _ocupado = true;
    _mensagemErro = null;
    notifyListeners();

    try {
      await _ligar(pedirPermissao: true);
    } catch (e) {
      _falhar('Não foi possível ligar o compartilhamento da localização.', e);
    } finally {
      _ocupado = false;
      notifyListeners();
    }
  }

  // Confere permissao e GPS; com tudo certo, grava a escolha (se ainda nao
  // estava gravada) e comeca a enviar a posicao.
  Future<void> _ligar({required bool pedirPermissao}) async {
    final permissao = pedirPermissao
        ? await _localizacaoService.solicitarPermissao()
        : await _localizacaoService.verificarPermissao();
    if (permissao != PermissaoLocalizacao.concedida) {
      _pararAtualizacoes();
      _estado = EstadoCompartilhamento.semPermissao;
      _permissaoBloqueada = permissao == PermissaoLocalizacao.bloqueada;
      if (pedirPermissao) {
        _mensagemErro = _permissaoBloqueada
            ? 'A permissão de localização está bloqueada. Libere nas '
                'configurações do celular, em Permissões > Localização.'
            : 'Permissão não concedida. Sem ela seu acompanhante não '
                'consegue ver onde você está.';
      }
      return;
    }
    _permissaoBloqueada = false;

    if (!_compartilhamentoLigado) {
      await _localizacaoRepository.ativarCompartilhamento(paciente.id);
      _compartilhamentoLigado = true;
    }

    if (!await _localizacaoService.gpsLigado()) {
      _pararAtualizacoes();
      _estado = EstadoCompartilhamento.gpsDesligado;
      return;
    }

    _estado = EstadoCompartilhamento.ativo;
    _mensagemErro = null;
    notifyListeners();
    await atualizarAgora();
    if (_estado == EstadoCompartilhamento.ativo) _reiniciarTimer();
  }

  // Botao "Parar de compartilhar": a ultima posicao e apagada do Firestore.
  // Retorna se conseguiu desligar.
  Future<bool> desativar() async {
    if (_ocupado) return false;
    _ocupado = true;
    _pararAtualizacoes();
    // Ja sai de "ativo" antes de gravar: uma posicao que o GPS entregue
    // agora nao pode ser gravada depois do desligamento.
    final estadoAnterior = _estado;
    _estado = EstadoCompartilhamento.desligado;
    notifyListeners();

    try {
      await _localizacaoRepository.desativarCompartilhamento(paciente.id);
      _compartilhamentoLigado = false;
      _ultimaAtualizacao = null;
      _mensagemErro = null;
      return true;
    } catch (e) {
      // Continua ligado no Firestore: volta a enviar para nao mostrar ao
      // paciente um estado diferente do que o acompanhante ve.
      debugPrint('Falha ao desligar o compartilhamento: $e');
      _estado = estadoAnterior;
      if (_estado == EstadoCompartilhamento.ativo) _reiniciarTimer();
      return false;
    } finally {
      _ocupado = false;
      notifyListeners();
    }
  }

  // Mede a posicao e envia ao acompanhante. Chamado pelo timer e pelo botao
  // "Tentar novamente".
  Future<void> atualizarAgora() async {
    if (_atualizando || _estado != EstadoCompartilhamento.ativo) return;
    _atualizando = true;
    notifyListeners();

    try {
      final posicao = await _localizacaoService.posicaoAtual();
      // O paciente pode ter desligado enquanto o GPS respondia.
      if (_estado != EstadoCompartilhamento.ativo) return;

      await _localizacaoRepository.salvarLocalizacao(Localizacao(
        pacienteId: paciente.id,
        ativo: true,
        latitude: posicao.latitude,
        longitude: posicao.longitude,
        precisaoMetros: posicao.precisaoMetros,
        dataHora: posicao.dataHora,
      ));
      _ultimaAtualizacao = posicao.dataHora;
      _mensagemErro = null;
    } on GpsDesligadoException {
      _pararAtualizacoes();
      _estado = EstadoCompartilhamento.gpsDesligado;
    } on SemPermissaoLocalizacaoException {
      _pararAtualizacoes();
      _estado = EstadoCompartilhamento.semPermissao;
      _permissaoBloqueada = false;
    } catch (e) {
      debugPrint('Falha ao atualizar a localizacao: $e');
      _mensagemErro = 'Não foi possível enviar sua localização agora. '
          'Confira se o celular está com internet.';
    } finally {
      _atualizando = false;
      notifyListeners();
    }
  }

  Future<void> abrirConfiguracoesDoApp() async {
    try {
      await _localizacaoService.abrirConfiguracoesDoApp();
    } catch (e) {
      debugPrint('Falha ao abrir as configuracoes do app: $e');
    }
  }

  Future<void> abrirConfiguracoesDeLocalizacao() async {
    try {
      await _localizacaoService.abrirConfiguracoesDeLocalizacao();
    } catch (e) {
      debugPrint('Falha ao abrir as configuracoes de localizacao: $e');
    }
  }

  // O GPS so e lido com o app em primeiro plano: pausa ao sair de cena e, ao
  // voltar, confere de novo - o paciente pode ter liberado a permissao ou
  // ligado o GPS nas configuracoes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (state != AppLifecycleState.resumed || _ocupado) return;

    if (_estado == EstadoCompartilhamento.ativo) {
      // Timer ainda rodando = so passou por "inactive" (ex.: cortina de
      // notificacoes aberta), sem ter ido para segundo plano.
      if (_timer != null) return;
      atualizarAgora();
      _reiniciarTimer();
    } else if (_estado == EstadoCompartilhamento.semPermissao ||
        _estado == EstadoCompartilhamento.gpsDesligado) {
      _reverificar();
    }
  }

  Future<void> _reverificar() async {
    _ocupado = true;
    try {
      await _ligar(pedirPermissao: false);
    } catch (e) {
      _falhar('Não foi possível verificar sua localização.', e);
    } finally {
      _ocupado = false;
      notifyListeners();
    }
  }

  void _reiniciarTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(intervalo, (_) => atualizarAgora());
  }

  void _pararAtualizacoes() {
    _timer?.cancel();
    _timer = null;
  }

  void _falhar(String mensagem, Object erro) {
    debugPrint('$mensagem ($erro)');
    _pararAtualizacoes();
    _estado = EstadoCompartilhamento.erro;
    _mensagemErro = mensagem;
  }

  @override
  void dispose() {
    _pararAtualizacoes();
    if (_observandoCicloDeVida) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }
}
