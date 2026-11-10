import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'core/services/push_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/sem_brilho_ao_rolar.dart';
import 'firebase_options.dart';
import 'ui/auth/abertura_view.dart';
import 'ui/auth/login_viewmodel.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();


  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Push dos alertas com o app em segundo plano ou fechado (B6): o FCM chama
  // esta funcao num isolate separado, que mostra a notificacao.
  if (PushServiceImpl.plataformaSuportada) {
    FirebaseMessaging.onBackgroundMessage(receberPushEmSegundoPlano);
  }

  runApp(const AgendaSaudeApp());
}

class AgendaSaudeApp extends StatelessWidget {
  const AgendaSaudeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agenda Saúde',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      scrollBehavior: SemBrilhoAoRolar(),
      // O app e todo em portugues, entao os textos prontos do Flutter (seletor
      // de hora e de data, "Colar"/"Copiar", o que o TalkBack diz deles)
      // tambem, qualquer que seja o idioma do celular.
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: ChangeNotifierProvider(
        create: (_) => LoginViewModel(),
        child: const AberturaView(),
      ),
    );
  }
}
