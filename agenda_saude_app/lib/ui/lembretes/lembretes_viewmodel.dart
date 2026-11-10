import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../core/constants/momentos_glicemia.dart';
import '../../core/services/notification_service.dart';
import '../../data/repositories/dados_repository.dart';
import '../../data/repositories/preferencias_repository.dart';
import '../../domain/lembretes/lembrete.dart';
import '../../domain/lembretes/plano_de_lembretes.dart';
import '../../domain/medicacao/horario_medicacao.dart';
import '../../domain/models/paciente.dart';
import '../../domain/models/registro_diabete.dart';
import '../../domain/models/registro_medicacao.dart';

// Como estao os lembretes, para o menu e para a tela "Meus lembretes".
enum SituacaoLembretes {
  // O celular nao tem notificacao do sistema (web, desktop).
  naoSuportado,
  // O paciente desligou.
  desligados,
  // Ligados, mas nao ha o que lembrar: sem remedios e sem diabetes.
  semLembretes,
  // O Android nao deixa o app mostrar notificacoes.
  semPermissao,
  // Tocam, mas sem a permissao de alarme exato podem atrasar alguns minutos.
  semAlarmeExato,
  ativos,
}

// Lembretes do paciente (RF 07.3): mantem agendados no aparelho os avisos de
// remedio, glicemia e insulina dos proximos dias, para tocarem mesmo com o app
// fechado. A cada mudanca - o app abrir, o paciente marcar uma dose, mudar os
// remedios ou os horarios - refaz o plano e acerta o que esta agendado: o aviso
// do que ja foi cumprido hoje some (da bandeja tambem), o de amanha continua.
//
// Cada lembrete tem tambem o aviso de pendencia (RF 06.3, B9), no
// horario-limite, se a tarefa ainda nao foi registrada. Para o acompanhante
// receber o mesmo aviso por push, a lista de tarefas do dia vai para o doc do
// paciente ([_publicarTarefas]), que a Cloud Function `verificarPendencias`
// confere a cada 10 minutos.
//
// Fica vivo enquanto o painel do paciente estiver aberto. Fechar o app nao
// cancela os avisos; so sair da conta ([cancelarTodos]).
class LembretesViewModel extends ChangeNotifier with WidgetsBindingObserver {
  final DadosMedicosRepository _dadosRepository;
  final PreferenciasRepository _preferencias;
  final NotificationService _servico;
  final DateTime Function() _agora;

  Paciente _paciente;
  late String _assinaturaDoPaciente;

  bool _ligados = true;
  Map<String, String> _horarios = const {};
  // null ate a primeira verificacao.
  bool? _notificacoesPermitidas;
  bool? _alarmesExatosPermitidos;

  // O que ja foi cumprido hoje, vindo do Firestore em tempo real.
  List<RegistroMedicacao> _medicacoesDeHoje = const [];
  List<RegistroDiabete> _diabeteDeHoje = const [];
  StreamSubscription<List<RegistroMedicacao>>? _assinaturaMedicacao;
  StreamSubscription<List<RegistroDiabete>>? _assinaturaDiabete;
  Timer? _timerViradaDoDia;
  late DateTime _dia;

  bool _iniciado = false;
  bool _observandoCicloDeVida = false;
  bool _pediuPermissao = false;
  // Um plano por vez: mudancas que chegam durante um plano entram no proximo.
  bool _reagendando = false;
  bool _reagendarDeNovo = false;
  // O plano em andamento, para o cancelamento esperar por ele terminar.
  Future<void>? _reagendamentoAtual;
  // Saiu da conta ou o painel fechou: nada mais deve ser agendado.
  bool _encerrado = false;
  bool _descartado = false;

  // A lista de tarefas (com o fuso) gravada no Firestore nesta sessao, para
  // nao gravar de novo o que nao mudou.
  String? _tarefasPublicadas;

  LembretesViewModel({
    required Paciente paciente,
    DadosMedicosRepository? dadosRepository,
    PreferenciasRepository? preferencias,
    NotificationService? notificationService,
    DateTime Function()? agora,
  })  : _paciente = paciente,
        _dadosRepository = dadosRepository ?? DadosMedicosRepository(),
        _preferencias = preferencias ?? PreferenciasRepository(),
        _servico = notificationService ?? NotificationServiceImpl(),
        _agora = agora ?? DateTime.now {
    _assinaturaDoPaciente = _assinaturaDe(paciente);
  }

  bool get suportado => _servico.disponivel;

  bool get ligados => _ligados;

  // Falso so depois de o Android negar; null enquanto nao se sabe.
  bool? get notificacoesPermitidas => _notificacoesPermitidas;

  bool? get alarmesExatosPermitidos => _alarmesExatosPermitidos;

  // Os horarios que o paciente escolheu para a glicemia (nome do momento ->
  // "HH:MM"); o que nao esta aqui usa o horario padrao.
  Map<String, String> get horariosDosMomentos => Map.unmodifiable(_horarios);

  // Os lembretes diarios do paciente, do primeiro horario ao ultimo, estejam os
  // lembretes ligados ou nao.
  List<Lembrete> get lembretes =>
      Lembrete.doPaciente(_paciente, horariosDosMomentos: _horarios);

  SituacaoLembretes get situacao {
    if (!suportado) return SituacaoLembretes.naoSuportado;
    if (!_ligados) return SituacaoLembretes.desligados;
    if (lembretes.isEmpty) return SituacaoLembretes.semLembretes;
    if (_notificacoesPermitidas == false) return SituacaoLembretes.semPermissao;
    if (_alarmesExatosPermitidos == false) return SituacaoLembretes.semAlarmeExato;
    return SituacaoLembretes.ativos;
  }

  // Le as preferencias e as permissoes, comeca a acompanhar o que o paciente ja
  // cumpriu hoje e deixa os avisos agendados.
  Future<void> iniciar() async {
    if (_iniciado || _descartado) return;
    _iniciado = true;
    if (!_servico.disponivel) {
      notifyListeners();
      return;
    }

    try {
      await _servico.inicializar();
      _ligados = await _preferencias.lembretesLigados(_paciente.id);
      _horarios = await _preferencias.horariosDosMomentos(_paciente.id);
      await _verificarPermissoes();
    } catch (erro) {
      debugPrint('Falha ao preparar os lembretes: $erro');
    }
    if (_descartado || _encerrado) return;

    // Para notar quando o paciente volta das configuracoes do Android.
    WidgetsBinding.instance.addObserver(this);
    _observandoCicloDeVida = true;

    _observarDia();
    notifyListeners();
    // Sem esperar: sem internet a gravacao so termina quando a conexao volta, e
    // os avisos do aparelho nao podem ficar esperando por ela.
    unawaited(_publicarTarefas());
    await _pedirPermissaoDeNotificacoes();
    // Nao espera os registros de hoje chegarem: se o Firestore demorar ou falhar,
    // os avisos ficam agendados do mesmo jeito (melhor um aviso a mais do que um
    // a menos). Quando os registros chegam o plano e refeito.
    await _reagendar();
  }

  // O paciente mudou (ex.: cadastrou um remedio): refaz os avisos. Chamado
  // durante o build pelo provider, por isso nao notifica na hora.
  void atualizarPaciente(Paciente novo) {
    final assinatura = _assinaturaDe(novo);
    final mudou = assinatura != _assinaturaDoPaciente;
    _paciente = novo;
    _assinaturaDoPaciente = assinatura;
    if (!mudou || !_iniciado) return;

    scheduleMicrotask(() {
      if (!_descartado) notifyListeners();
    });
    unawaited(_publicarTarefas());
    _pedirPermissaoDeNotificacoes().then((_) => _reagendar());
  }

  Future<void> alternarLembretes(bool ligados) async {
    if (_ligados == ligados) return;
    _ligados = ligados;
    notifyListeners();
    try {
      await _preferencias.salvarLembretesLigados(_paciente.id, ligados);
    } catch (erro) {
      debugPrint('Falha ao guardar se os lembretes estao ligados: $erro');
    }
    await _pedirPermissaoDeNotificacoes();
    await _reagendar();
  }

  // O aviso deste momento da glicemia esta fora do horario padrao? E o que
  // mostra o "Voltar para 07:00". Um horario guardado igual ao padrao (de
  // quando o horario se digitava e dava para escrever "0700") nao conta.
  bool horarioFoiAlterado(String nomeDoMomento) {
    final guardado = _horarios[nomeDoMomento];
    return guardado != null &&
        guardado != MomentoGlicemia.porNome(nomeDoMomento).horarioPadrao;
  }

  // Muda o horario do aviso de um momento da glicemia (ou da insulina lenta).
  // [entrada] vem do relogio, em "HH:MM" (tambem aceita "0630"). Escolher o
  // horario padrao e o mesmo que voltar a ele. Devolve false, sem mudar nada,
  // se nao for uma hora valida ou se nao conseguir guardar.
  Future<bool> definirHorarioDoMomento(
    String nomeDoMomento,
    String entrada,
  ) async {
    final horario = normalizarHorario(entrada);
    if (horario == null) return false;
    final padrao = MomentoGlicemia.porNome(nomeDoMomento).horarioPadrao;
    return _guardarHorario(nomeDoMomento, horario == padrao ? null : horario);
  }

  // Volta o aviso do momento ao horario padrao.
  Future<bool> restaurarHorarioDoMomento(String nomeDoMomento) =>
      _guardarHorario(nomeDoMomento, null);

  Future<bool> _guardarHorario(String nomeDoMomento, String? horario) async {
    try {
      await _preferencias.salvarHorarioDoMomento(
        _paciente.id,
        nomeDoMomento,
        horario,
      );
    } catch (erro) {
      debugPrint('Falha ao guardar o horario do lembrete: $erro');
      return false;
    }
    final novos = Map<String, String>.of(_horarios);
    if (horario == null) {
      novos.remove(nomeDoMomento);
    } else {
      novos[nomeDoMomento] = horario;
    }
    _horarios = novos;
    if (!_descartado) notifyListeners();
    unawaited(_publicarTarefas());
    await _reagendar();
    return true;
  }

  // Botao "Ativar notificações": tenta o pedido do sistema e, se o Android ja
  // nao mostra mais o pedido (permissao negada antes), abre as configuracoes de
  // notificacao do app.
  Future<void> ativarNotificacoes() async {
    try {
      final permitiu = await _servico.solicitarPermissao();
      if (!permitiu) await _servico.abrirConfiguracoes();
      _notificacoesPermitidas = permitiu;
    } catch (erro) {
      debugPrint('Falha ao ativar as notificações: $erro');
    }
    if (!_descartado) notifyListeners();
    await _reagendar();
  }

  // Botao "Permitir alarmes exatos": abre a tela do Android. O resultado so se
  // sabe quando o paciente volta ao app (ver [didChangeAppLifecycleState]).
  Future<void> permitirAlarmesExatos() async {
    try {
      await _servico.solicitarAlarmesExatos();
    } catch (erro) {
      debugPrint('Falha ao pedir os alarmes exatos: $erro');
    }
  }

  // Ao sair da conta: tira do aparelho todos os avisos deste paciente, para o
  // proximo a entrar no celular nao receber os dele. Nao muda a escolha de
  // ligar ou desligar, que fica guardada para a proxima entrada.
  Future<void> cancelarTodos() async {
    _encerrado = true;
    if (!_servico.disponivel) return;
    // Um plano que ja estava agendando para ao ver que encerrou; espera por ele
    // para nenhum aviso entrar depois do cancelamento.
    try {
      await _reagendamentoAtual;
    } catch (erro) {
      debugPrint('Falha no plano que estava em andamento: $erro');
    }
    try {
      final agendados = await _servico.idsAgendados(
        prefixoDoPayload: OcorrenciaDeLembrete.prefixoDoPayload,
      );
      for (final id in agendados) {
        await _servico.cancelar(id);
      }
      // Os de hoje que ja tocaram e continuam na bandeja (o lembrete e o aviso
      // de pendencia).
      final hoje = _agora();
      for (final lembrete in lembretes) {
        final horario = lembrete.em(hoje);
        await _servico.cancelar(OcorrenciaDeLembrete(lembrete, horario).id);
        await _servico
            .cancelar(OcorrenciaDeLembrete.pendencia(lembrete, horario).id);
      }
    } catch (erro) {
      debugPrint('Falha ao cancelar os lembretes: $erro');
    }
  }

  // Passa a acompanhar o dia atual e agenda a virada para o proximo, para o
  // que foi cumprido recomecar do zero a meia-noite mesmo com o app aberto.
  void _observarDia() {
    final agora = _agora();
    _dia = DateTime(agora.year, agora.month, agora.day);

    _assinaturaMedicacao?.cancel();
    _assinaturaMedicacao =
        _dadosRepository.streamMedicacoesDoDia(_paciente.id, _dia).listen(
      (registros) {
        _medicacoesDeHoje = registros;
        _reagendar();
      },
      onError: (Object erro) {
        debugPrint('Stream de medicacao dos lembretes falhou: $erro');
        _reagendar();
      },
    );

    _assinaturaDiabete?.cancel();
    _assinaturaDiabete = null;
    if (_paciente.possuiDiabetes) {
      _assinaturaDiabete =
          _dadosRepository.streamDiabeteDoDia(_paciente.id, _dia).listen(
        (registros) {
          _diabeteDeHoje = registros;
          _reagendar();
        },
        onError: (Object erro) {
          debugPrint('Stream de diabetes dos lembretes falhou: $erro');
          _reagendar();
        },
      );
    }

    _timerViradaDoDia?.cancel();
    final meiaNoite = DateTime(_dia.year, _dia.month, _dia.day + 1);
    _timerViradaDoDia = Timer(meiaNoite.difference(agora), _aoVirarODia);
  }

  void _aoVirarODia() {
    if (_descartado || _encerrado) return;
    _medicacoesDeHoje = const [];
    _diabeteDeHoje = const [];
    _observarDia();
    _reagendar();
  }

  Future<void> _verificarPermissoes() async {
    _notificacoesPermitidas = await _servico.notificacoesPermitidas();
    _alarmesExatosPermitidos = await _servico.alarmesExatosPermitidos();
  }

  // O pedido do sistema so aparece uma vez por sessao e so se ha o que lembrar:
  // quem nao tem remedios nem diabetes nao precisa ser incomodado.
  Future<void> _pedirPermissaoDeNotificacoes() async {
    if (_pediuPermissao || _notificacoesPermitidas != false) return;
    if (!_ligados || lembretes.isEmpty || _encerrado || _descartado) return;
    _pediuPermissao = true;
    try {
      _notificacoesPermitidas = await _servico.solicitarPermissao();
    } catch (erro) {
      debugPrint('Falha ao pedir a permissão de notificações: $erro');
    }
    if (!_descartado) notifyListeners();
  }

  Future<void> _reagendar() async {
    if (_descartado || _encerrado || !_servico.disponivel) return;
    if (_reagendando) {
      _reagendarDeNovo = true;
      return;
    }
    _reagendando = true;
    final execucao = _executarPlanos();
    _reagendamentoAtual = execucao;
    try {
      await execucao;
    } finally {
      _reagendando = false;
      _reagendamentoAtual = null;
    }
  }

  Future<void> _executarPlanos() async {
    do {
      _reagendarDeNovo = false;
      await _aplicarPlano();
    } while (_reagendarDeNovo && !_descartado && !_encerrado);
  }

  // Deixa agendado no aparelho exatamente o plano de agora: cancela o que nao
  // deve mais tocar (remedio apagado, horario trocado, lembretes desligados, dose
  // de hoje ja cumprida) e agenda o resto. Agendar de novo um aviso que ja
  // existe so o substitui, entao refazer o plano varias vezes e inofensivo.
  Future<void> _aplicarPlano() async {
    try {
      final plano = PlanejadorDeLembretes.planejar(
        lembretes: _ligados ? lembretes : const [],
        cumpridosHoje: PlanejadorDeLembretes.chavesCumpridas(
          medicacoes: _medicacoesDeHoje,
          diabete: _diabeteDeHoje,
        ),
        agora: _agora(),
      );

      final desejados = {for (final o in plano.agendar) o.id};
      final agendados = await _servico.idsAgendados(
        prefixoDoPayload: OcorrenciaDeLembrete.prefixoDoPayload,
      );
      for (final id in agendados) {
        if (!desejados.contains(id)) await _servico.cancelar(id);
      }
      // Tira da bandeja o aviso de hoje que ja tocou e foi cumprido.
      for (final id in plano.cumpridosHoje) {
        await _servico.cancelar(id);
      }

      for (final ocorrencia in plano.agendar) {
        // Saiu da conta no meio do plano: para de agendar.
        if (_encerrado || _descartado) return;
        try {
          await _servico.agendarLembrete(
            id: ocorrencia.id,
            titulo: ocorrencia.titulo,
            texto: ocorrencia.texto,
            dataHora: ocorrencia.dataHora,
            payload: ocorrencia.payload,
          );
        } catch (erro) {
          // Um aviso que falha nao pode impedir os demais.
          debugPrint('Falha ao agendar ${ocorrencia.payload}: $erro');
        }
      }
    } catch (erro) {
      debugPrint('Falha ao refazer os lembretes: $erro');
    }
  }

  // RF 06.3: grava no doc do paciente as tarefas do dia com horario (as mesmas
  // dos lembretes) e o fuso do aparelho. E por elas que a Cloud Function
  // `verificarPendencias` avisa o acompanhante quando uma passa do
  // horario-limite sem registro, mesmo com o app do paciente fechado. Vale
  // tambem com os lembretes desligados: o paciente escolheu nao ser lembrado,
  // mas o acompanhante continua acompanhando. Uma falha so fica no log; a
  // proxima mudanca (ou abertura do app) tenta de novo.
  Future<void> _publicarTarefas() async {
    if (_descartado || _encerrado) return;
    final tarefas = lembretes;
    final fusoHorarioMinutos = _agora().timeZoneOffset.inMinutes;
    final conteudo = jsonEncode([
      fusoHorarioMinutos,
      tarefas.map((tarefa) => tarefa.toJsonTarefa()).toList(),
    ]);
    if (conteudo == _tarefasPublicadas) return;
    try {
      await _dadosRepository.salvarTarefasDiarias(
        _paciente.id,
        tarefas,
        fusoHorarioMinutos: fusoHorarioMinutos,
      );
      _tarefasPublicadas = conteudo;
    } catch (erro) {
      debugPrint('Falha ao publicar as tarefas do dia: $erro');
    }
  }

  // Remedios e perfil mudam os avisos; o resto do paciente (BPM, metas...) nao.
  static String _assinaturaDe(Paciente paciente) {
    return jsonEncode([
      paciente.medicamentos.map((remedio) => remedio.toJson()).toList(),
      paciente.possuiDiabetes,
      paciente.usaInsulina,
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _aoVoltarAoApp();
  }

  // O paciente pode ter voltado das configuracoes do Android (com permissoes
  // novas) ou de um dia depois (o app ficou parado em segundo plano).
  Future<void> _aoVoltarAoApp() async {
    try {
      await _verificarPermissoes();
    } catch (erro) {
      debugPrint('Falha ao verificar as permissões dos lembretes: $erro');
    }
    if (_descartado || _encerrado) return;
    // O paciente pode ter viajado para outro fuso.
    unawaited(_publicarTarefas());
    final hoje = _agora();
    if (DateTime(hoje.year, hoje.month, hoje.day) != _dia) {
      _aoVirarODia();
    } else {
      // Tambem completa os proximos dias e troca para o modo exato se o
      // paciente acabou de permitir.
      _reagendar();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    _assinaturaMedicacao?.cancel();
    _assinaturaDiabete?.cancel();
    _timerViradaDoDia?.cancel();
    if (_observandoCicloDeVida) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }
}
