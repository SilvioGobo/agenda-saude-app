import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/alerta.dart';
import '../../firebase_options.dart';
import 'notification_service.dart';

// Push do alerta de um paciente para o celular do acompanhante (B6, RF06.2).
// Quem manda e a Cloud Function `notificarAlertaPaciente` (functions/), assim
// que o app do paciente grava um documento em `alertas`. E o que faz o aviso
// chegar com o app do acompanhante fechado; com ele aberto, a escuta em tempo
// real da central de alertas ja mostra a notificacao.
//
// A mensagem so traz dados, sem o bloco `notification` do FCM: quem mostra a
// notificacao e o proprio app, no mesmo canal (`alertas_pacientes`) e com o
// mesmo id da escuta. Assim o alerta aparece uma vez so, mesmo quando a escuta
// e o push chegam juntos, e o toque abre a tela de emergencia.
class AlertaPush {
  // Valor do campo `tipo` das mensagens de alerta; as outras sao ignoradas.
  static const String tipoDaMensagem = 'alerta_paciente';

  final String alertaId;
  final String pacienteId;
  // Para quem o push foi mandado. O aparelho so mostra o alerta se essa
  // pessoa estiver logada nele.
  final String acompanhanteId;
  // `atencao` ou `emergencia`, como o campo `tipo` do alerta.
  final String nivel;
  final String titulo;
  final String texto;
  // Horario da leitura de BPM que gerou o alerta.
  final DateTime dataHora;

  const AlertaPush({
    required this.alertaId,
    required this.pacienteId,
    required this.acompanhanteId,
    required this.nivel,
    required this.titulo,
    required this.texto,
    required this.dataHora,
  });

  // Alerta sem nivel conta como emergencia, como em `Alerta.fromJson`.
  bool get ehEmergencia => nivel != Alerta.tipoAtencao;

  // Le os dados da mensagem do FCM (todos os valores chegam como texto).
  // Null se a mensagem nao e de alerta ou veio sem os ids.
  static AlertaPush? daMensagem(Map<String, dynamic> dados) {
    if (dados['tipo'] != tipoDaMensagem) return null;
    final alertaId = _texto(dados['alertaId']);
    final acompanhanteId = _texto(dados['acompanhanteId']);
    if (alertaId.isEmpty || acompanhanteId.isEmpty) return null;

    final milissegundos = int.tryParse(_texto(dados['dataHora']));
    final titulo = _texto(dados['titulo']);
    return AlertaPush(
      alertaId: alertaId,
      pacienteId: _texto(dados['pacienteId']),
      acompanhanteId: acompanhanteId,
      nivel: _texto(dados['nivel']),
      titulo: titulo.isEmpty ? 'Alerta de paciente' : titulo,
      texto: _texto(dados['texto']),
      dataHora: milissegundos == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(milissegundos),
    );
  }

  static String _texto(Object? valor) => valor?.toString().trim() ?? '';
}

// Mostra a notificacao de um push de alerta e retorna se mostrou. So mostra
// para quem o push foi mandado: se o aparelho saiu da conta (ou entrou em
// outra) sem conseguir tirar o token do Firestore, o alerta do paciente nao
// aparece para quem nao o acompanha (NF005).
Future<bool> mostrarAlertaDoPush(
  AlertaPush alerta, {
  required String? uidLogado,
  required NotificationService notificacoes,
}) async {
  if (uidLogado == null || uidLogado != alerta.acompanhanteId) return false;
  if (!notificacoes.disponivel) return false;

  await notificacoes.inicializar();
  await notificacoes.mostrar(
    id: idDaNotificacaoDoAlerta(alerta.alertaId),
    titulo: alerta.titulo,
    texto: alerta.texto,
    dataHora: alerta.dataHora,
    urgente: alerta.ehEmergencia,
    payload: alerta.alertaId,
  );
  return true;
}

// Ponto de entrada do push com o app em segundo plano ou fechado. O Android
// acorda o app num isolate separado, sem tela: por isso inicializa o Firebase
// e confere quem esta logado (a sessao fica salva no aparelho). Registrado no
// `main` com `FirebaseMessaging.onBackgroundMessage`.
@pragma('vm:entry-point')
Future<void> receberPushEmSegundoPlano(RemoteMessage mensagem) async {
  final alerta = AlertaPush.daMensagem(mensagem.data);
  if (alerta == null) return;
  try {
    DartPluginRegistrant.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final auth = FirebaseAuth.instance;
    final usuario = auth.currentUser ?? await auth.authStateChanges().first;
    await mostrarAlertaDoPush(
      alerta,
      uidLogado: usuario?.uid,
      notificacoes: NotificationServiceImpl(),
    );
  } catch (erro) {
    debugPrint('Push de alerta falhou: $erro');
  }
}

// Contrato do FCM no aparelho do acompanhante. A central de alertas depende
// so desta interface, entao nos testes basta injetar um fake em memoria.
abstract class PushService {
  // Falso fora do Android/iOS e sem o Firebase inicializado (testes).
  bool get disponivel;

  // Token que identifica este aparelho no FCM; e para ele que a Cloud
  // Function manda o push. Null se o FCM nao responder.
  Future<String?> obterToken();

  // O FCM troca o token de vez em quando (ex.: depois de limpar os dados).
  Stream<String> get tokenRenovado;

  // Invalida o token deste aparelho: o proximo push para ele falha, e a
  // Cloud Function tira o token da lista.
  Future<void> apagarToken();

  // Id do alerta da notificacao mostrada pelo sistema (iOS, ou uma mensagem
  // de teste do console) que abriu o app encerrado...
  Future<String?> alertaQueAbriuOApp();

  // ... ou que foi tocada com o app em segundo plano.
  Stream<String> get alertaTocado;
}

// Implementacao real em cima do plugin `firebase_messaging`.
class PushServiceImpl implements PushService {
  // So pega o FCM quando alguem usa: os testes criam o servico sem Firebase.
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  static bool get plataformaSuportada =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  bool get disponivel => plataformaSuportada && Firebase.apps.isNotEmpty;

  @override
  Future<String?> obterToken() => _messaging.getToken();

  @override
  Stream<String> get tokenRenovado => _messaging.onTokenRefresh;

  @override
  Future<void> apagarToken() => _messaging.deleteToken();

  @override
  Future<String?> alertaQueAbriuOApp() async {
    final mensagem = await _messaging.getInitialMessage();
    if (mensagem == null) return null;
    return AlertaPush.daMensagem(mensagem.data)?.alertaId;
  }

  @override
  Stream<String> get alertaTocado => FirebaseMessaging.onMessageOpenedApp
      .map((mensagem) => AlertaPush.daMensagem(mensagem.data)?.alertaId)
      .where((alertaId) => alertaId != null)
      .cast<String>();
}
