import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agenda_saude_app/data/repositories/acompanhante_repository.dart';
import 'package:agenda_saude_app/data/repositories/auth_repository.dart';
import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/data/repositories/localizacao_repository.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/data/repositories/preferencias_repository.dart';
import 'package:agenda_saude_app/data/repositories/relatorios_repository.dart';
import 'package:agenda_saude_app/domain/models/acompanhante.dart';
import 'package:agenda_saude_app/domain/models/batimento_cardiaco.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_agua.dart';
import 'package:agenda_saude_app/ui/auth/login_viewmodel.dart';
import 'package:agenda_saude_app/ui/configuracoes/configuracoes_viewmodel.dart';
import 'package:agenda_saude_app/ui/lembretes/lembretes_viewmodel.dart';
import 'package:agenda_saude_app/ui/localizacao/compartilhamento_localizacao_viewmodel.dart';
import 'package:agenda_saude_app/ui/paciente/paciente_view.dart';
import 'package:agenda_saude_app/ui/paciente/paciente_viewmodel.dart';
import 'package:agenda_saude_app/ui/sincronizacao/sincronizacao_bpm_viewmodel.dart';

import '../../core/services/fake_health_service.dart';
import '../../core/services/fake_leitura_segundo_plano_service.dart';
import '../../core/services/fake_localizacao_service.dart';
import '../../core/services/fake_notification_service.dart';
import '../../core/services/fake_telefone_service.dart';
import '../../core/services/fake_tts_service.dart';

class _AuthRepositoryFalso extends AuthRepository {
  int saidas = 0;
  // Simula um logout que falha (ex.: sem internet).
  bool falharAoSair = false;

  @override
  Future<void> sair() async {
    if (falharAoSair) throw Exception('sem conexao');
    saidas++;
  }
}

void main() {
  group('PacienteView Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    late _AuthRepositoryFalso authRepository;
    late FakeTelefoneService telefoneService;
    late FakeNotificationService notificationService;
    late FakeTtsService ttsService;

    final paciente = Paciente(
      id: 'paciente_01',
      nome: 'José Silva',
      email: 'jose@email.com',
      perfil: 'Paciente',
      possuiDiabetes: false,
      possuiCardiopatia: false,
      codigoVinculo: 'ABC123',
    );

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
      authRepository = _AuthRepositoryFalso();
      telefoneService = FakeTelefoneService();
      notificationService = FakeNotificationService();
      ttsService = FakeTtsService();
      SharedPreferences.setMockInitialValues({});
    });

    // `smartwatchSuportado: false` simula celular sem Health Connect; com
    // true, o smartwatch fica conectado (permissao concedida, sem leituras
    // novas) e o painel mostra o que estiver salvo no Firestore.
    Future<void> montar(
      WidgetTester tester, {
      bool smartwatchSuportado = true,
      double escalaTexto = 1,
      // Simula o TalkBack ligado.
      bool leitorDeTela = false,
      // Os lembretes dependem dos remedios e do perfil; o paciente padrao do
      // teste nao tem nenhum dos dois.
      Paciente? pacienteDosLembretes,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          // Simula a opcao "tamanho da fonte" do celular.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(escalaTexto),
              accessibleNavigation: leitorDeTela,
            ),
            child: child!,
          ),
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => PacienteViewModel(
                  paciente: paciente,
                  dadosRepository: dadosRepository,
                  authRepository: authRepository,
                ),
              ),
              ChangeNotifierProvider(
                create: (_) => SincronizacaoBpmViewModel(
                  paciente: paciente,
                  healthService: FakeHealthService(),
                  dadosRepository: dadosRepository,
                  leituraComAppFechado: FakeLeituraSegundoPlanoService(),
                  plataformaSuportada: smartwatchSuportado,
                  intervalo: const Duration(hours: 1),
                )..iniciar(),
              ),
              ChangeNotifierProvider(
                create: (_) => CompartilhamentoLocalizacaoViewModel(
                  paciente: paciente,
                  localizacaoService: FakeLocalizacaoService(),
                  localizacaoRepository:
                      LocalizacaoRepository(firestore: fakeFirestore),
                  plataformaSuportada: true,
                  intervalo: const Duration(hours: 1),
                )..iniciar(),
              ),
              // `lazy: false`, como em `PacienteView.comProviders`: os avisos
              // sao agendados ao abrir o painel, sem esperar o menu.
              ChangeNotifierProvider(
                lazy: false,
                create: (_) => LembretesViewModel(
                  paciente: pacienteDosLembretes ?? paciente,
                  dadosRepository: dadosRepository,
                  preferencias: PreferenciasRepository(),
                  notificationService: notificationService,
                )..iniciar(),
              ),
              ChangeNotifierProvider(
                lazy: false,
                create: (_) => ConfiguracoesViewModel(
                  preferencias: PreferenciasRepository(),
                  ttsService: ttsService,
                )..carregar(),
              ),
            ],
            child: PacienteView(
              relatoriosRepository:
                  RelatoriosRepository(firestore: fakeFirestore),
              acompanhanteRepository:
                  AcompanhanteRepository(firestore: fakeFirestore),
              telefoneService: telefoneService,
              // A tela de login, para onde "Sair da conta" volta, sem Firebase.
              criarLoginViewModel: () => LoginViewModel(
                authRepository: authRepository,
                pacienteRepository: PacienteRepository(firestore: fakeFirestore),
                acompanhanteRepository:
                    AcompanhanteRepository(firestore: fakeFirestore),
                firestore: fakeFirestore,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // O menu lateral tem 7 itens (metas, codigo, smartwatch, localizacao,
    // lembretes, acessibilidade e sair) e rola. Numa tela mais alta o "Sair da
    // conta" ja fica construido.
    void menuAlto(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    // Desmonta o painel para os ViewModels cancelarem o polling (timer).
    Future<void> desmontar(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
    }

    Future<void> salvarBatimento(int bpm) {
      return dadosRepository.salvarBatimento(BatimentoCardiaco(
        id: '',
        pacienteId: paciente.id,
        bpm: bpm,
        timestamp: DateTime.now(),
      ));
    }

    testWidgets('Deve mostrar saudação e atalhos, sem código nem smartwatch na tela',
        (tester) async {
      await montar(tester);

      expect(find.text('Olá, José'), findsOneWidget);
      expect(find.text('Menu'), findsOneWidget);
      expect(find.text('Minha Rotina'), findsOneWidget);
      expect(find.text('Meus Relatórios'), findsOneWidget);
      // O ultimo atalho fica abaixo da dobra na tela do teste (800x600).
      await tester.scrollUntilVisible(find.text('Falar com Acompanhante'), 200);
      expect(find.text('Falar com Acompanhante'), findsOneWidget);
      expect(find.text('ABC123'), findsNothing);
      expect(find.text('Smartwatch conectado'), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Deve ligar para o acompanhante em dois toques a partir do painel',
        (tester) async {
      await PacienteRepository(firestore: fakeFirestore).salvarPaciente(paciente);
      final acompanhanteRepository =
          AcompanhanteRepository(firestore: fakeFirestore);
      await acompanhanteRepository.salvarAcompanhante(Acompanhante(
        id: 'cuidador_01',
        nome: 'Carlos Souza',
        email: 'carlos@email.com',
        perfil: 'Acompanhante',
        telefone: '67999990000',
        pacientesVinculadosIds: [],
      ));
      await acompanhanteRepository.vincularPaciente('cuidador_01', paciente.id);
      await montar(tester);

      // Toque 1: o atalho do painel.
      await tester.scrollUntilVisible(find.text('Falar com Acompanhante'), 200);
      await tester.ensureVisible(find.text('Falar com Acompanhante'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Falar com Acompanhante'));
      await tester.pumpAndSettle();
      expect(find.text('FALAR COM ACOMPANHANTE'), findsOneWidget);

      // Toque 2: ligar.
      await tester.tap(find.text('LIGAR PARA CARLOS'));
      await tester.pumpAndSettle();
      expect(telefoneService.numerosChamados, ['67999990000']);

      // "Voltar" cai de novo no painel, onde estava (rolado ate o botao).
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();
      expect(find.text('FALAR COM ACOMPANHANTE'), findsNothing);
      expect(find.text('Falar com Acompanhante'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve abrir os relatórios pelo botão do painel, com os dados de ontem, e voltar',
        (tester) async {
      final ontem = DateTime.now().subtract(const Duration(days: 1));
      await dadosRepository.salvarRegistro(RegistroAgua(
        id: '',
        pacienteId: paciente.id,
        dataHora: DateTime(ontem.year, ontem.month, ontem.day, 9),
        quantidadeML: 250,
      ));
      await montar(tester);

      await tester.tap(find.text('Meus Relatórios'));
      await tester.pumpAndSettle();

      expect(find.text('Meus relatórios'), findsOneWidget);
      expect(find.text('Ontem'), findsOneWidget);
      expect(find.text('Mês'), findsOneWidget);
      expect(find.text('250 ml de 2.000 ml'), findsOneWidget);

      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('Olá, José'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar o BPM em destaque e o status estável', (tester) async {
      await salvarBatimento(72);
      await montar(tester);

      expect(find.text('72'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
      expect(find.textContaining('Medido às'), findsOneWidget);
      expect(find.text('ESTÁVEL'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar alerta quando o BPM está alto demais', (tester) async {
      await salvarBatimento(128);
      await montar(tester);

      expect(find.text('128'), findsOneWidget);
      expect(find.text('BATIMENTOS ALTOS'), findsOneWidget);
      expect(find.textContaining('acima de 100 por minuto'), findsOneWidget);
      expect(find.text('ESTÁVEL'), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar alerta quando o BPM está baixo demais', (tester) async {
      await salvarBatimento(45);
      await montar(tester);

      expect(find.text('BATIMENTOS BAIXOS'), findsOneWidget);
      expect(find.textContaining('abaixo de 60 por minuto'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar o problema do smartwatch no lugar do BPM',
        (tester) async {
      await salvarBatimento(72);
      await montar(tester, smartwatchSuportado: false);

      expect(find.text('Smartwatch indisponível'), findsOneWidget);
      expect(find.text('72'), findsNothing);
      expect(find.text('ESTÁVEL'), findsNothing);
    });

    testWidgets('Deve explicar como os batimentos chegam pelo "Como funciona?" do destaque',
        (tester) async {
      await salvarBatimento(72);
      await montar(tester);

      expect(find.text('72'), findsOneWidget);
      await tester.ensureVisible(find.text('Como funciona?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Como funciona?'));
      await tester.pumpAndSettle();

      expect(find.text('Como o app recebe seus batimentos'), findsOneWidget);
      expect(find.text('Onde fica o Saúde Connect'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve oferecer o "Como funciona?" também enquanto aguarda a primeira medição',
        (tester) async {
      await montar(tester);

      expect(find.text('Aguardando medição'), findsOneWidget);
      expect(find.text('Como funciona?'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Não deve estourar o layout com a fonte do celular em 200%',
        (tester) async {
      // Celular pequeno (360x640) com a fonte no maximo: qualquer overflow
      // vira erro e reprova o teste.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await salvarBatimento(128);
      await montar(tester, escalaTexto: 2);

      // Rola a tela inteira para montar (e medir) tudo, ate o ultimo botao.
      await tester.scrollUntilVisible(find.text('BATIMENTOS ALTOS'), 200);
      await tester.scrollUntilVisible(find.text('Falar com Acompanhante'), 200);
      expect(find.text('Falar com Acompanhante'), findsOneWidget);

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();
      final listaDoMenu = find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Sair da conta'),
        200,
        scrollable: listaDoMenu,
      );
      expect(find.text('Sair da conta'), findsOneWidget);

      // O primeiro item ja saiu da tela (e da lista montada): rola de volta.
      await tester.scrollUntilVisible(
        find.text('Meu código de vínculo'),
        -200,
        scrollable: listaDoMenu,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meu código de vínculo'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Copiar código'), 200);
      expect(find.text('Copiar código'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve abrir o menu e a tela do código de vínculo', (tester) async {
      menuAlto(tester);
      await montar(tester);

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();

      expect(find.text('José Silva'), findsOneWidget);
      expect(find.text('Meu código de vínculo'), findsOneWidget);
      expect(find.text('Meu smartwatch'), findsOneWidget);
      expect(find.text('Conectado'), findsOneWidget);
      expect(find.text('Minha localização'), findsOneWidget);
      expect(find.text('Não compartilhada'), findsOneWidget);
      expect(find.text('Sair da conta'), findsOneWidget);

      await tester.tap(find.text('Meu código de vínculo'));
      await tester.pumpAndSettle();

      expect(find.text('ABC123'), findsOneWidget);
      expect(find.text('Copiar código'), findsOneWidget);

      // Voltar cai direto no painel, com o menu ja fechado.
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('Olá, José'), findsOneWidget);
      expect(find.text('Sair da conta'), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Deve abrir "Meus dados" pelo perfil do menu', (tester) async {
      await montar(tester);

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();
      expect(find.text('Ver e mudar meus dados'), findsOneWidget);

      await tester.tap(find.text('José Silva'));
      await tester.pumpAndSettle();

      expect(find.text('Meus dados'), findsOneWidget);
      expect(find.text('SOBRE VOCÊ'), findsOneWidget);
      expect(find.text('ALERGIAS'), findsOneWidget);

      // Cancelar cai direto no painel, com o menu ja fechado.
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Olá, José'), findsOneWidget);
      expect(find.text('Ver e mudar meus dados'), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Deve abrir a tela do smartwatch pelo menu', (tester) async {
      await montar(tester);

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meu smartwatch'));
      await tester.pumpAndSettle();

      expect(find.text('Smartwatch conectado'), findsOneWidget);
      expect(find.text('Sincronizar agora'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve ligar o compartilhamento da localização pelo menu',
        (tester) async {
      menuAlto(tester);
      await montar(tester);

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Minha localização'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Compartilhar minha localização'));
      await tester.pumpAndSettle();
      expect(find.text('Compartilhando sua localização'), findsOneWidget);

      // De volta ao painel, o menu mostra que esta compartilhando.
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();
      expect(find.text('Compartilhando'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar os lembretes no menu e abrir a tela deles',
        (tester) async {
      menuAlto(tester);
      await montar(tester);

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Meus lembretes'), findsOneWidget);
      // O paciente do teste não tem remédios nem diabetes: nada a lembrar.
      expect(find.text('Remédios e horários da glicemia'), findsOneWidget);

      await tester.tap(find.text('Meus lembretes'));
      await tester.pumpAndSettle();

      expect(find.text('Meus lembretes'), findsOneWidget);
      expect(find.text('Lembretes ligados'), findsOneWidget);
      expect(find.textContaining('Você ainda não tem lembretes'), findsOneWidget);

      // Voltar cai direto no painel.
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();
      expect(find.text('Olá, José'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar no menu que os lembretes estão ligados e agendá-los',
        (tester) async {
      menuAlto(tester);
      await montar(
        tester,
        pacienteDosLembretes: Paciente(
          id: 'paciente_01',
          nome: 'José Silva',
          email: 'jose@email.com',
          perfil: 'Paciente',
          possuiDiabetes: true,
          usaInsulina: false,
          possuiCardiopatia: false,
          codigoVinculo: 'ABC123',
        ),
      );

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Ligados'), findsOneWidget);
      // As quatro medições de glicemia dos próximos dias foram agendadas.
      expect(notificationService.agendadas, isNotEmpty);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar a acessibilidade no menu e abrir a tela do narrador',
        (tester) async {
      menuAlto(tester);
      await montar(tester);

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Acessibilidade'), findsOneWidget);
      expect(find.text('Narrador desligado'), findsOneWidget);

      await tester.tap(find.text('Acessibilidade'));
      await tester.pumpAndSettle();

      expect(find.text('Acessibilidade'), findsOneWidget);
      expect(find.text('Ligar narrador'), findsOneWidget);

      // Ligar na tela e voltar: o menu passa a dizer que esta ligado.
      await tester.tap(find.text('Ligar narrador'));
      await tester.pumpAndSettle();
      expect(ttsService.faladas, ['Narrador ligado.']);

      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();
      expect(find.text('Narrador ligado'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar no menu quando o celular não tem voz do sistema',
        (tester) async {
      menuAlto(tester);
      ttsService = FakeTtsService(disponivel: false);
      await montar(tester);

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Acessibilidade'), findsOneWidget);
      expect(find.text('Indisponível neste celular'), findsOneWidget);

      await desmontar(tester);
    });

    group('Ouvir esta tela', () {
      final ouvir = find.text('Ouvir esta tela');

      // O narrador ja vem ligado, como depois de o paciente te-lo ligado.
      void narradorLigado() {
        SharedPreferences.setMockInitialValues({'narrador.ligado': true});
      }

      testWidgets('Não deve aparecer com o narrador desligado', (tester) async {
        await montar(tester);

        expect(ouvir, findsNothing);

        await desmontar(tester);
      });

      testWidgets('Deve aparecer logo abaixo da saudação com o narrador ligado',
          (tester) async {
        narradorLigado();
        await montar(tester);

        expect(ouvir, findsOneWidget);
        expect(
          tester.getTopLeft(ouvir).dy,
          greaterThan(tester.getBottomLeft(find.text('Olá, José')).dy),
        );

        await desmontar(tester);
      });

      testWidgets('Deve ler os batimentos e para onde ir, em poucas frases',
          (tester) async {
        narradorLigado();
        await salvarBatimento(78);
        await montar(tester);

        await tester.tap(ouvir);
        await tester.pump();

        final texto = ttsService.faladas.single;
        expect(texto, startsWith('Olá, José. Seus batimentos estão em 78 por minuto'));
        expect(texto, contains('Está tudo estável.'));
        expect(texto, contains('Minha Rotina, Meus Relatórios ou Falar com Acompanhante'));
        // Texto curto: nao e o painel inteiro, so os pontos principais.
        expect(texto.split(' ').length, lessThan(55));
        // Enquanto fala, o botao oferece parar.
        expect(find.text('Parar de ouvir'), findsOneWidget);

        await desmontar(tester);
      });

      testWidgets('Deve ler o alerta quando os batimentos estão altos',
          (tester) async {
        narradorLigado();
        await salvarBatimento(128);
        await montar(tester);

        await tester.tap(ouvir);
        await tester.pump();

        final texto = ttsService.faladas.single;
        expect(texto, contains('Atenção! Seus batimentos estão altos: 128 por minuto'));
        expect(texto, contains('fale com seu acompanhante'));

        await desmontar(tester);
      });

      testWidgets('Deve ler o aviso do smartwatch no lugar dos batimentos',
          (tester) async {
        narradorLigado();
        await salvarBatimento(72);
        await montar(tester, smartwatchSuportado: false);

        await tester.tap(ouvir);
        await tester.pump();

        final texto = ttsService.faladas.single;
        expect(texto, contains('Smartwatch indisponível.'));
        expect(texto, isNot(contains('72')));

        await desmontar(tester);
      });

      testWidgets('Deve ler a espera pela primeira medição', (tester) async {
        narradorLigado();
        await montar(tester);

        await tester.tap(ouvir);
        await tester.pump();

        expect(ttsService.faladas.single, contains('Aguardando medição.'));

        await desmontar(tester);
      });

      testWidgets('Deve calar a leitura ao abrir outra tela', (tester) async {
        // Janela alta: com o botao a mais, "Meus Relatorios" desce.
        menuAlto(tester);
        narradorLigado();
        await salvarBatimento(78);
        await montar(tester);
        await tester.tap(ouvir);
        await tester.pump();

        await tester.tap(find.text('Meus Relatórios'));
        await tester.pumpAndSettle();

        expect(ttsService.paradas, 1);

        await tester.tap(find.text('Voltar'));
        await tester.pumpAndSettle();
        await desmontar(tester);
      });

      testWidgets('Não deve aparecer, nem falar, com o leitor de tela ligado',
          (tester) async {
        narradorLigado();
        await salvarBatimento(78);
        await montar(tester, leitorDeTela: true);

        expect(ouvir, findsNothing);
        expect(ttsService.faladas, isEmpty);

        await desmontar(tester);
      });

      testWidgets('Deve aparecer ao ligar o narrador pelo menu e voltar ao painel',
          (tester) async {
        menuAlto(tester);
        await montar(tester);
        expect(ouvir, findsNothing);

        await tester.tap(find.text('Menu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Acessibilidade'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ligar narrador'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Voltar'));
        await tester.pumpAndSettle();

        expect(ouvir, findsOneWidget);

        await desmontar(tester);
      });

      testWidgets('Não deve estourar o layout com a fonte do celular em 200%',
          (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        narradorLigado();
        await salvarBatimento(128);
        await montar(tester, escalaTexto: 2);

        expect(ouvir, findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(ouvir);
        await tester.pump();
        expect(tester.takeException(), isNull);

        await desmontar(tester);
      });
    });

    testWidgets('Deve pedir confirmação antes de sair e não sair ao cancelar',
        (tester) async {
      menuAlto(tester);
      await montar(tester);

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();

      expect(find.text('Sair da conta?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Sair da conta?'), findsNothing);
      expect(find.text('Olá, José'), findsOneWidget);
      expect(authRepository.saidas, 0);

      await desmontar(tester);
    });

    // Um diabetico sempre tem avisos agendados nos proximos dias.
    final diabetico = Paciente(
      id: 'paciente_01',
      nome: 'José Silva',
      email: 'jose@email.com',
      perfil: 'Paciente',
      possuiDiabetes: true,
      usaInsulina: false,
      possuiCardiopatia: false,
      codigoVinculo: 'ABC123',
    );

    // O ViewModel dos lembretes agenda depois de ler as preferencias e os
    // registros de hoje (async de verdade): da um tempo para ele terminar.
    Future<void> aguardarOsLembretes(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> sairDaContaPeloMenu(WidgetTester tester) async {
      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      // O botao "Sair" do dialogo de confirmacao (o texto e exatamente "Sair":
      // o item do menu e o titulo do dialogo dizem "Sair da conta").
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
    }

    testWidgets('Deve cancelar os lembretes agendados ao sair da conta', (tester) async {
      menuAlto(tester);
      await montar(tester, pacienteDosLembretes: diabetico);
      await aguardarOsLembretes(tester);
      expect(notificationService.agendadas, isNotEmpty);

      await sairDaContaPeloMenu(tester);

      expect(authRepository.saidas, 1);
      // Quem entrar depois neste celular nao recebe os avisos de quem saiu.
      expect(notificationService.agendadas, isEmpty);
      // E o app voltou para a tela de login.
      expect(find.text('Olá, José'), findsNothing);
    });

    testWidgets('Deve manter os lembretes se não conseguir sair da conta', (tester) async {
      menuAlto(tester);
      authRepository.falharAoSair = true;
      await montar(tester, pacienteDosLembretes: diabetico);
      await aguardarOsLembretes(tester);
      final agendadas = notificationService.agendadas.length;
      expect(agendadas, greaterThan(0));

      await sairDaContaPeloMenu(tester);

      // Continua logado, no painel, e continua sendo avisado.
      expect(find.text('Não foi possível sair. Tente de novo.'), findsOneWidget);
      expect(find.text('Olá, José'), findsOneWidget);
      expect(notificationService.agendadas, hasLength(agendadas));

      await desmontar(tester);
    });

    testWidgets('Deve abrir Minhas metas pelo menu e voltar ao painel', (tester) async {
      await montar(tester);

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();
      expect(find.text('Água, passos, calorias e mais'), findsOneWidget);

      await tester.tap(find.text('Minhas metas'));
      await tester.pumpAndSettle();

      // Este paciente nao tem dados fisicos, entao ainda nao ha metas.
      expect(find.text('Minhas metas'), findsOneWidget);
      expect(
        find.text('Ainda não foi possível calcular suas metas.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('Olá, José'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve oferecer Personalizar rotina no menu', (tester) async {
      menuAlto(tester);
      await montar(tester);

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Personalizar rotina'), findsOneWidget);
      expect(find.text('Remédios, refeições e metas'), findsOneWidget);

      await desmontar(tester);
    });
  });
}
