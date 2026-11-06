import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../../data/repositories/dados_repository.dart';
import '../../domain/models/batimento_cardiaco.dart';
import '../../firebase_options.dart';
import 'health_service.dart';

// TESTE B2 do roteiro (RF04.2): ler o BPM do smartwatch com o app fechado.
// Uma tarefa periodica do WorkManager le o Health Connect e grava as
// leituras novas em `batimentos_cardiacos`. O Android roda tarefa periodica
// no minimo a cada 15 minutos e pode atrasar com a economia de bateria. O
// resultado do teste no aparelho real decide entre viavel, viavel so em
// alguns aparelhos ou inviavel (docs/b2-bpm-app-fechado.md). Ainda nao gera
// alertas: isso e o B7, se o teste der certo.

const String tarefaBpmSegundoPlano = 'agenda_saude_bpm_segundo_plano';

// Menor intervalo que o Android aceita para uma tarefa periodica.
const Duration intervaloSegundoPlano = Duration(minutes: 15);

// Le o Health Connect e grava so as leituras que ainda nao estao no
// Firestore, com o mesmo criterio da sincronizacao com o app aberto (o
// timestamp de cada leitura). Retorna quantas leituras novas gravou.
Future<int> importarLeiturasNovas({
  required String pacienteId,
  required HealthService healthService,
  required DadosMedicosRepository dadosRepository,
  required DateTime agora,
  Duration janela = const Duration(hours: 12),
}) async {
  final inicio = agora.subtract(janela);
  final gravados = await dadosRepository.getBatimentosDesde(pacienteId, inicio);
  final jaGravados =
      gravados.map((b) => b.timestamp.millisecondsSinceEpoch).toSet();

  final leituras =
      await healthService.lerBatimentos(inicio: inicio, fim: agora);
  final novas = leituras
      .where((l) => !jaGravados.contains(l.timestamp.millisecondsSinceEpoch))
      .toList();
  if (novas.isEmpty) return 0;

  await dadosRepository.salvarBatimentos(
    novas
        .map((l) => BatimentoCardiaco(
              id: '',
              pacienteId: pacienteId,
              bpm: l.bpm,
              timestamp: l.timestamp,
            ))
        .toList(),
  );
  return novas.length;
}

// Ponto de entrada do WorkManager. Roda num isolate separado, sem tela: por
// isso inicializa o Firebase e pega o usuario logado (a sessao fica salva no
// aparelho). O resultado vai para o log (`flutter logs` / `adb logcat`).
@pragma('vm:entry-point')
void despacharTarefaEmSegundoPlano() {
  Workmanager().executeTask((tarefa, _) async {
    if (tarefa != tarefaBpmSegundoPlano) return true;
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
      final novas = await importarLeiturasNovas(
        pacienteId: usuario.uid,
        healthService: HealthServiceImpl(),
        dadosRepository: DadosMedicosRepository(),
        agora: DateTime.now(),
      );
      debugPrint('BPM em segundo plano: $novas leituras novas');
    } catch (erro) {
      // Ex.: sem a permissao de segundo plano o Health Connect recusa a
      // leitura com o app fechado.
      debugPrint('BPM em segundo plano falhou: $erro');
    }
    // Falha nao reagenda com espera: a proxima execucao periodica tenta.
    return true;
  });
}

// Liga, desliga e consulta a tarefa do teste. A tela depende so desta
// interface, entao nos testes basta injetar um fake em memoria.
abstract class LeituraSegundoPlanoService {
  Future<bool> estaLigada();

  Future<void> ligar();

  Future<void> desligar();

  // Uma execucao avulsa logo em seguida, para conferir o caminho de segundo
  // plano sem esperar os 15 minutos.
  Future<void> lerUmaVezAgora();
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
    );
  }
}
