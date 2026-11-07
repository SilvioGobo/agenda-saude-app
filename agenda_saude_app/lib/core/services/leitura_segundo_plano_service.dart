import 'dart:isolate';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../../data/repositories/dados_repository.dart';
import '../../data/repositories/paciente_repository.dart';
import '../../domain/batimentos/monitor_zona_seguranca.dart';
import '../../domain/models/batimento_cardiaco.dart';
import '../../domain/models/paciente.dart';
import '../../firebase_options.dart';
import 'health_service.dart';

// Leitura do BPM do smartwatch com o app fechado (B7, RF04.2), como o teste
// B2 validou (docs/b2-bpm-app-fechado.md): uma tarefa periodica do WorkManager
// le o Health Connect, grava as leituras novas em `batimentos_cardiacos` e
// gera os alertas de atencao e emergencia com as mesmas regras do app aberto
// (MonitorZonaSeguranca); o push (B6) leva o alerta ao acompanhante. O Android
// roda tarefa periodica no minimo a cada 15 minutos e a economia de bateria
// pode espacar. So funciona onde o Health Connect oferece a leitura em segundo
// plano e o paciente concedeu a permissao (READ_HEALTH_DATA_IN_BACKGROUND): o
// SincronizacaoBpmViewModel liga a tarefa com a permissao e a desliga sem ela.

const String tarefaBpmSegundoPlano = 'agenda_saude_bpm_segundo_plano';

// Menor intervalo que o Android aceita para uma tarefa periodica.
const Duration intervaloSegundoPlano = Duration(minutes: 15);

// Quanto de historico cada execucao rele, como a leitura com o app aberto.
const Duration janelaSegundoPlano = Duration(hours: 12);

// Uma execucao da leitura com o app fechado: le o Health Connect, grava so as
// leituras que ainda nao estao no Firestore (o mesmo criterio do app aberto,
// o horario de cada leitura) e gera os alertas. Como cada execucao comeca do
// zero, retoma o episodio fora da zona pelas leituras e alertas da janela.
// Os alertas ja gravados sao lidos antes de gravar as leituras: se essa
// leitura falhar, nada e gravado e a proxima execucao tenta tudo de novo.
Future<({int leiturasNovas, int alertas})> sincronizarComAppFechado({
  required Paciente paciente,
  required HealthService healthService,
  required DadosMedicosRepository dadosRepository,
  required DateTime agora,
  Duration janela = janelaSegundoPlano,
}) async {
  final inicio = agora.subtract(janela);
  final gravados = await dadosRepository.getBatimentosDesde(paciente.id, inicio);
  final jaGravados =
      gravados.map((b) => b.timestamp.millisecondsSinceEpoch).toSet();

  final leituras =
      await healthService.lerBatimentos(inicio: inicio, fim: agora);
  final novas = leituras
      .where((l) => !jaGravados.contains(l.timestamp.millisecondsSinceEpoch))
      .map((l) => BatimentoCardiaco(
            id: '',
            pacienteId: paciente.id,
            bpm: l.bpm,
            timestamp: l.timestamp,
          ))
      .toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  if (novas.isEmpty) return (leiturasNovas: 0, alertas: 0);

  final alertasDaJanela =
      await dadosRepository.getAlertasDesde(paciente.id, inicio);
  await dadosRepository.salvarBatimentos(novas);

  final monitor = MonitorZonaSeguranca.retomar(
    pacienteId: paciente.id,
    possuiCardiopatia: paciente.possuiCardiopatia,
    gravados: gravados,
    alertas: alertasDaJanela,
  );
  final alertas = monitor.avaliar(novas);
  for (final alerta in alertas) {
    await dadosRepository.gerarAlerta(alerta);
  }
  return (leiturasNovas: novas.length, alertas: alertas.length);
}

// Nome com que o app aberto se anuncia enquanto le o BPM a cada 30 s. Com o
// app aberto, a tarefa do WorkManager roda no mesmo processo e pula a
// execucao ao achar o nome: senao as duas leituras gravariam as mesmas
// leituras e os mesmos alertas em dobro.
const String _nomeDoAppAberto = 'agenda_saude_bpm_app_aberto';
ReceivePort? _portaDoAppAberto;

// Marca a execucao avulsa (`lerUmaVezAgora`) nos dados da tarefa.
const String _execucaoAvulsa = 'avulsa';

void anunciarAppAberto(bool aberto) {
  if (aberto) {
    if (_portaDoAppAberto != null) return;
    final porta = ReceivePort();
    IsolateNameServer.removePortNameMapping(_nomeDoAppAberto);
    IsolateNameServer.registerPortWithName(porta.sendPort, _nomeDoAppAberto);
    _portaDoAppAberto = porta;
  } else {
    final porta = _portaDoAppAberto;
    if (porta == null) return;
    IsolateNameServer.removePortNameMapping(_nomeDoAppAberto);
    porta.close();
    _portaDoAppAberto = null;
  }
}

bool appAbertoLendoBpm() =>
    IsolateNameServer.lookupPortByName(_nomeDoAppAberto) != null;

// Ponto de entrada do WorkManager. Roda num isolate separado, sem tela: por
// isso inicializa o Firebase e pega o usuario logado (a sessao fica salva no
// aparelho). O resultado vai para o log (`flutter logs` / `adb logcat`).
@pragma('vm:entry-point')
void despacharTarefaEmSegundoPlano() {
  Workmanager().executeTask((tarefa, dados) async {
    if (tarefa != tarefaBpmSegundoPlano) return true;
    // A execucao avulsa do cartao de teste (B2) roda mesmo com o app aberto.
    final avulsa = dados?[_execucaoAvulsa] == true;
    if (!avulsa && appAbertoLendoBpm()) {
      debugPrint('BPM em segundo plano: app aberto, a leitura de 30 s cuida');
      return true;
    }
    try {
      DartPluginRegistrant.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final usuario = FirebaseAuth.instance.currentUser ??
          await FirebaseAuth.instance.authStateChanges().first;
      if (usuario == null) {
        debugPrint('BPM em segundo plano: ninguem logado');
        return true;
      }
      final paciente = await PacienteRepository().getPaciente(usuario.uid);
      if (paciente == null || paciente.perfil != 'Paciente') {
        debugPrint('BPM em segundo plano: a conta logada nao e de paciente');
        return true;
      }
      final resultado = await sincronizarComAppFechado(
        paciente: paciente,
        healthService: HealthServiceImpl(),
        dadosRepository: DadosMedicosRepository(),
        agora: DateTime.now(),
      );
      debugPrint('BPM em segundo plano: ${resultado.leiturasNovas} leituras '
          'novas, ${resultado.alertas} alertas');
    } catch (erro) {
      // Ex.: sem a permissao de segundo plano o Health Connect recusa a
      // leitura com o app fechado.
      debugPrint('BPM em segundo plano falhou: $erro');
    }
    // Falha nao reagenda com espera: a proxima execucao periodica tenta.
    return true;
  });
}

// Liga, desliga e consulta a tarefa periodica, e avisa a tarefa quando o app
// esta aberto lendo o BPM. Quem usa depende so desta interface, entao nos
// testes basta injetar um fake em memoria.
abstract class LeituraSegundoPlanoService {
  Future<bool> estaLigada();

  // Agenda a tarefa; se ja estiver agendada, mantem o horario dela.
  Future<void> ligar();

  Future<void> desligar();

  // Uma execucao avulsa logo em seguida, para conferir o caminho de segundo
  // plano sem esperar os 15 minutos (cartao do teste B2).
  Future<void> lerUmaVezAgora();

  // O app aberto le a cada 30 s: enquanto [aberto], a tarefa pula a vez.
  void avisarAppAberto(bool aberto);
}

// Implementacao real em cima do plugin `workmanager`.
class LeituraSegundoPlanoServiceImpl implements LeituraSegundoPlanoService {
  bool _inicializado = false;

  Future<void> _garantirInicializado() async {
    if (_inicializado) return;
    await Workmanager().initialize(despacharTarefaEmSegundoPlano);
    _inicializado = true;
  }

  // Sem internet a leitura nao chega ao Firestore: espera a conexao.
  Constraints get _comInternet => Constraints(networkType: NetworkType.connected);

  @override
  Future<bool> estaLigada() async {
    await _garantirInicializado();
    return Workmanager().isScheduledByUniqueName(tarefaBpmSegundoPlano);
  }

  @override
  Future<void> ligar() async {
    await _garantirInicializado();
    await Workmanager().registerPeriodicTask(
      tarefaBpmSegundoPlano,
      tarefaBpmSegundoPlano,
      frequency: intervaloSegundoPlano,
      constraints: _comInternet,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  @override
  Future<void> desligar() async {
    await _garantirInicializado();
    await Workmanager().cancelByUniqueName(tarefaBpmSegundoPlano);
  }

  @override
  Future<void> lerUmaVezAgora() async {
    await _garantirInicializado();
    await Workmanager().registerOneOffTask(
      '${tarefaBpmSegundoPlano}_agora',
      tarefaBpmSegundoPlano,
      constraints: _comInternet,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      inputData: {_execucaoAvulsa: true},
    );
  }

  @override
  void avisarAppAberto(bool aberto) => anunciarAppAberto(aberto);
}
