import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/data/repositories/preferencias_repository.dart';
import 'package:agenda_saude_app/domain/metas/metas_personalizadas.dart';
import 'package:agenda_saude_app/domain/models/medicamento.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_agua.dart';
import 'package:agenda_saude_app/domain/models/registro_diabete.dart';
import 'package:agenda_saude_app/data/repositories/paciente_repository.dart';
import 'package:agenda_saude_app/ui/configuracoes/configuracoes_viewmodel.dart';
import 'package:agenda_saude_app/ui/insulina/glicemia_insulina_viewmodel.dart';
import 'package:agenda_saude_app/ui/rotina/card_hidratacao.dart';
import 'package:agenda_saude_app/ui/rotina/exercicio_viewmodel.dart';
import 'package:agenda_saude_app/ui/rotina/hidratacao_viewmodel.dart';
import 'package:agenda_saude_app/ui/rotina/medicacao_viewmodel.dart';
import 'package:agenda_saude_app/ui/rotina/narracao_da_rotina.dart';
import 'package:agenda_saude_app/ui/rotina/refeicoes_viewmodel.dart';
import 'package:agenda_saude_app/ui/rotina/rotina_view.dart';
import 'package:agenda_saude_app/ui/rotina/sono_viewmodel.dart';

import '../../core/services/fake_tts_service.dart';

// Leitura da agua que nunca chega: a tela fica "carregando".
class _RepositorioQueNaoResponde extends DadosMedicosRepository {
  _RepositorioQueNaoResponde(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Stream<List<RegistroAgua>> streamAguaDoDia(String pacienteId, DateTime dia) =>
      StreamController<List<RegistroAgua>>().stream;
}

// Leitura do dia que sempre falha (ex.: indice composto ainda nao publicado).
class _RepositorioSemLeitura extends DadosMedicosRepository {
  _RepositorioSemLeitura(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Stream<List<RegistroAgua>> streamAguaDoDia(String pacienteId, DateTime dia) =>
      Stream.error(Exception('indice faltando'));
}

// Metas completas; so a agua muda de um teste para outro.
MetasPersonalizadas metasComAgua(int hidratacaoMl) {
  return MetasPersonalizadas(
    imc: 24.7,
    classificacaoImc: ClassificacaoImc.adequado,
    hidratacaoMl: hidratacaoMl,
    sonoMinHoras: 7,
    sonoMaxHoras: 9,
    passos: 8000,
    exercicioMinutosSemana: 150,
    calorias: 1800,
    carboidratosG: 225,
    proteinasG: 90,
    gordurasG: 60,
    fibrasG: 25,
    gorduraSaturadaMaxG: 20,
    acucarLivreMaxG: 45,
    sodioMaxMg: 2000,
  );
}

void main() {
  group('RotinaView Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;

    final paciente = Paciente(
      id: 'paciente_01',
      nome: 'José Silva',
      email: 'jose@email.com',
      perfil: 'Paciente',
      possuiDiabetes: false,
      possuiCardiopatia: false,
      codigoVinculo: 'ABC123',
    );
    final hoje = DateTime(2026, 10, 25, 15, 0);

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
    });

    Future<void> montar(
      WidgetTester tester, {
      DadosMedicosRepository? repositorio,
      Paciente? pacienteDaTela,
      double escalaTexto = 1,
      // O narrador de voz, que o painel entrega a esta tela; sem ele nao ha
      // botao "Ouvir esta tela".
      ConfiguracoesViewModel? narrador,
      // Monta a tela como a de um diabetico, com o cartao de glicemia e insulina.
      bool comDiabetes = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          // Simula a opcao "tamanho da fonte" do celular.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escalaTexto)),
            child: child!,
          ),
          home: MultiProvider(
            providers: [
              if (narrador != null)
                ChangeNotifierProvider.value(value: narrador),
              if (comDiabetes)
                ChangeNotifierProvider(
                  create: (_) => GlicemiaInsulinaViewModel(
                    paciente: pacienteDaTela ?? paciente,
                    dadosRepository: repositorio ?? dadosRepository,
                    agora: () => hoje,
                  ),
                ),
              ChangeNotifierProvider(
                create: (_) => HidratacaoViewModel(
                  paciente: pacienteDaTela ?? paciente,
                  dadosRepository: repositorio ?? dadosRepository,
                  agora: () => hoje,
                ),
              ),
              ChangeNotifierProvider(
                create: (_) => RefeicoesViewModel(
                  paciente: pacienteDaTela ?? paciente,
                  dadosRepository: repositorio ?? dadosRepository,
                  pacienteRepository: PacienteRepository(firestore: fakeFirestore),
                  agora: () => hoje,
                ),
              ),
              ChangeNotifierProvider(
                create: (_) => SonoViewModel(
                  paciente: pacienteDaTela ?? paciente,
                  dadosRepository: repositorio ?? dadosRepository,
                  agora: () => hoje,
                ),
              ),
              ChangeNotifierProvider(
                create: (_) => ExercicioViewModel(
                  paciente: pacienteDaTela ?? paciente,
                  dadosRepository: repositorio ?? dadosRepository,
                  agora: () => hoje,
                ),
              ),
              ChangeNotifierProvider(
                create: (_) => MedicacaoViewModel(
                  paciente: pacienteDaTela ?? paciente,
                  dadosRepository: repositorio ?? dadosRepository,
                  agora: () => hoje,
                ),
              ),
            ],
            child: RotinaView(exibirDiabetes: comDiabetes),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Desmonta a tela para o ViewModel cancelar o timer da meia-noite.
    Future<void> desmontar(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
    }

    Future<void> salvarCopos(int quantidade) async {
      for (var i = 0; i < quantidade; i++) {
        await dadosRepository.salvarRegistro(RegistroAgua(
          id: '',
          pacienteId: paciente.id,
          dataHora: DateTime(2026, 10, 25, 6 + i, 0),
          quantidadeML: 250,
        ));
      }
    }

    // `.icon` cria uma subclasse privada, que o byType exato nao acha.
    Finder barraDaAgua() => find.descendant(
          of: find.byType(CardHidratacao),
          matching: find.byType(LinearProgressIndicator),
        );

    // So os botoes do cartao de hidratacao: o de refeicoes tem os seus.
    Finder botaoMais() => find.descendant(
          of: find.byType(CardHidratacao),
          matching: find.bySubtype<FilledButton>(),
        );
    Finder botaoMenos() => find.descendant(
          of: find.byType(CardHidratacao),
          matching: find.bySubtype<OutlinedButton>(),
        );

    testWidgets('Deve mostrar o título, a hidratação zerada e o botão de tirar copo desativado',
        (tester) async {
      await montar(tester);

      expect(find.text('Voltar'), findsOneWidget);
      expect(find.text('Minha Rotina'), findsOneWidget);
      expect(find.text('Hidratação'), findsOneWidget);
      expect(find.text('0 de 8 copos'), findsOneWidget);
      expect(find.text('0 ml de 2000 ml'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(botaoMenos()).onPressed, isNull);
      expect(tester.widget<FilledButton>(botaoMais()).onPressed, isNotNull);
      expect(find.text('META DE HOJE ATINGIDA'), findsNothing);
      // Paciente sem diabetes na triagem não vê glicemia/insulina (RF008).
      expect(find.text('Glicemia e Insulina'), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Deve somar um copo ao tocar em "+ Copo" e gravar no Firestore',
        (tester) async {
      await montar(tester);

      await tester.tap(botaoMais());
      await tester.pumpAndSettle();

      expect(find.text('1 de 8 copos'), findsOneWidget);
      expect(find.text('250 ml de 2000 ml'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(botaoMenos()).onPressed, isNotNull);

      final salvos = await fakeFirestore.collection('registros_diarios').get();
      expect(salvos.docs.length, 1);

      await desmontar(tester);
    });

    testWidgets('Deve tirar um copo ao tocar em "- Copo"', (tester) async {
      await salvarCopos(3);
      await montar(tester);
      expect(find.text('3 de 8 copos'), findsOneWidget);

      await tester.tap(botaoMenos());
      await tester.pumpAndSettle();

      expect(find.text('2 de 8 copos'), findsOneWidget);
      expect(find.text('500 ml de 2000 ml'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve mostrar o progresso salvo ao abrir a tela', (tester) async {
      await salvarCopos(5);
      await montar(tester);

      expect(find.text('5 de 8 copos'), findsOneWidget);
      final barra = tester.widget<LinearProgressIndicator>(
        barraDaAgua(),
      );
      expect(barra.value, closeTo(5 / 8, 0.0001));

      await desmontar(tester);
    });

    testWidgets('Deve avisar que a meta do dia foi atingida', (tester) async {
      await salvarCopos(7);
      await montar(tester);
      expect(find.text('META DE HOJE ATINGIDA'), findsNothing);

      await tester.tap(botaoMais());
      await tester.pumpAndSettle();

      expect(find.text('8 de 8 copos'), findsOneWidget);
      expect(find.text('META DE HOJE ATINGIDA'), findsOneWidget);

      await desmontar(tester);
    });

    testWidgets('Deve esconder o progresso e os botões se não conseguir ler a hidratação',
        (tester) async {
      await montar(tester, repositorio: _RepositorioSemLeitura(fakeFirestore));

      expect(find.textContaining('Não foi possível carregar'), findsOneWidget);
      expect(barraDaAgua(), findsNothing);
      expect(botaoMais(), findsNothing);
      expect(botaoMenos(), findsNothing);

      await desmontar(tester);
    });

    testWidgets('Deve falar o progresso e o que cada botão faz para o leitor de tela',
        (tester) async {
      final semantica = tester.ensureSemantics();
      await salvarCopos(2);
      await montar(tester);

      expect(
        find.bySemanticsLabel('Hidratação: 2 de 8 copos, 500 de 2000 mililitros.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Adicionar um copo de água'), findsOneWidget);
      expect(find.bySemanticsLabel('Tirar um copo de água'), findsOneWidget);

      await desmontar(tester);
      semantica.dispose();
    });

    testWidgets('Não deve estourar o layout com a fonte do celular em 200%',
        (tester) async {
      await salvarCopos(8);
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await montar(tester, escalaTexto: 2);

      expect(tester.takeException(), isNull);
      expect(find.text('8 de 8 copos'), findsOneWidget);
      // Com a fonte grande os botões ficam um embaixo do outro, ambos visíveis.
      expect(botaoMais(), findsOneWidget);
      expect(botaoMenos(), findsOneWidget);
      expect(
        tester.getTopLeft(botaoMais()).dx,
        tester.getTopLeft(botaoMenos()).dx,
      );

      await desmontar(tester);
    });

    testWidgets('Deve voltar para a tela anterior ao tocar em "Voltar"',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MultiProvider(
                      providers: [
                        ChangeNotifierProvider(
                          create: (_) => HidratacaoViewModel(
                            paciente: paciente,
                            dadosRepository: dadosRepository,
                            agora: () => hoje,
                          ),
                        ),
                        ChangeNotifierProvider(
                          create: (_) => RefeicoesViewModel(
                            paciente: paciente,
                            dadosRepository: dadosRepository,
                            agora: () => hoje,
                          ),
                        ),
                        ChangeNotifierProvider(
                          create: (_) => SonoViewModel(
                            paciente: paciente,
                            dadosRepository: dadosRepository,
                            agora: () => hoje,
                          ),
                        ),
                        ChangeNotifierProvider(
                          create: (_) => ExercicioViewModel(
                            paciente: paciente,
                            dadosRepository: dadosRepository,
                            agora: () => hoje,
                          ),
                        ),
                        ChangeNotifierProvider(
                          create: (_) => MedicacaoViewModel(
                            paciente: paciente,
                            dadosRepository: dadosRepository,
                            agora: () => hoje,
                          ),
                        ),
                      ],
                      child: const RotinaView(),
                    ),
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Minha Rotina'), findsOneWidget);

      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('Minha Rotina'), findsNothing);
      expect(find.text('Abrir'), findsOneWidget);
    });

    testWidgets('Deve mostrar a meta de água calculada para o paciente', (tester) async {
      await salvarCopos(5);
      await montar(
        tester,
        pacienteDaTela: paciente.copyWith(metas: metasComAgua(1500)),
      );

      expect(find.text('5 de 6 copos'), findsOneWidget);
      expect(find.text('1250 ml de 1500 ml'), findsOneWidget);
      expect(find.text('META DE HOJE ATINGIDA'), findsNothing);

      await tester.tap(botaoMais());
      await tester.pumpAndSettle();

      expect(find.text('6 de 6 copos'), findsOneWidget);
      expect(find.text('META DE HOJE ATINGIDA'), findsOneWidget);

      await desmontar(tester);
    });

    group('Ouvir esta tela', () {
      final ouvir = find.text('Ouvir esta tela');
      late FakeTtsService tts;

      setUp(() => tts = FakeTtsService());

      // O narrador como o painel o entrega: carregado e ligado.
      Future<ConfiguracoesViewModel> narradorLigado() async {
        SharedPreferences.setMockInitialValues({'narrador.ligado': true});
        final viewModel = ConfiguracoesViewModel(
          preferencias: PreferenciasRepository(),
          ttsService: tts,
        );
        await viewModel.carregar();
        return viewModel;
      }

      // Janela alta: com o botao a mais, os cartoes descem.
      void janelaAlta(WidgetTester tester) {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
      }

      testWidgets('Não deve aparecer sem o narrador', (tester) async {
        await montar(tester);

        expect(ouvir, findsNothing);
        expect(find.text('Minha Rotina'), findsOneWidget);

        await desmontar(tester);
      });

      testWidgets('Não deve aparecer com o narrador desligado', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final viewModel = ConfiguracoesViewModel(
          preferencias: PreferenciasRepository(),
          ttsService: tts,
        );
        await viewModel.carregar();
        await montar(tester, narrador: viewModel);

        expect(ouvir, findsNothing);

        await desmontar(tester);
      });

      testWidgets('Deve aparecer logo abaixo do título, antes dos cartões', (tester) async {
        janelaAlta(tester);
        await montar(tester, narrador: await narradorLigado());

        expect(ouvir, findsOneWidget);
        expect(
          tester.getTopLeft(ouvir).dy,
          greaterThan(tester.getBottomLeft(find.text('Minha Rotina')).dy),
        );
        expect(
          tester.getBottomLeft(ouvir).dy,
          lessThan(tester.getTopLeft(find.text('Hidratação')).dy),
        );

        await desmontar(tester);
      });

      testWidgets('Deve ler quantos itens estão completos e só o que falta', (tester) async {
        janelaAlta(tester);
        await salvarCopos(3);
        await montar(tester, narrador: await narradorLigado());

        await tester.tap(ouvir);
        await tester.pump();

        // Sem remedios, com o plano padrao de 4 refeicoes: agua, refeicoes e sono.
        expect(
          tts.faladas.single,
          'Sua rotina de hoje. Você completou 0 de 3 itens. Falta beber mais 5 '
          'copos de água, fazer 4 refeições e registrar o sono. Nesta semana, 0 '
          'de 150 minutos de exercício.',
        );

        await desmontar(tester);
      });

      testWidgets('Deve ler o remédio que falta, com a hora e a unidade por extenso', (tester) async {
        janelaAlta(tester);
        await montar(
          tester,
          pacienteDaTela: paciente.copyWith(
            medicamentos: const [
              Medicamento(
                id: 'm1',
                nome: 'Losartana',
                dose: '50mg',
                horarios: ['14:00'],
              ),
            ],
          ),
          narrador: await narradorLigado(),
        );

        await tester.tap(ouvir);
        await tester.pump();

        expect(
          tts.faladas.single,
          contains('tomar Losartana 50 miligramas às 14 horas'),
        );

        await desmontar(tester);
      });

      testWidgets('Deve ler a rotina do momento do toque, e não a de quando a tela abriu', (tester) async {
        janelaAlta(tester);
        await montar(tester, narrador: await narradorLigado());
        await tester.tap(ouvir);
        await tester.pump();
        expect(tts.faladas.last, contains('beber mais 8 copos de água'));
        tts.terminarDeFalar();
        await tester.pump();

        await tester.tap(botaoMais());
        await tester.pumpAndSettle();
        await tester.tap(ouvir);
        await tester.pump();

        expect(tts.faladas.last, contains('beber mais 7 copos de água'));

        await desmontar(tester);
      });

      testWidgets('Deve incluir a glicemia e a insulina lenta na leitura de quem tem diabetes', (tester) async {
        janelaAlta(tester);
        await montar(
          tester,
          pacienteDaTela: Paciente(
            id: 'paciente_01',
            nome: 'José Silva',
            email: 'jose@email.com',
            perfil: 'Paciente',
            possuiDiabetes: true,
            usaInsulina: true,
            possuiCardiopatia: false,
            codigoVinculo: 'ABC123',
          ),
          comDiabetes: true,
          narrador: await narradorLigado(),
        );
        // Uma medicao feita (ao acordar); faltam tres e a insulina lenta.
        await dadosRepository.salvarRegistro(RegistroDiabete(
          id: '',
          pacienteId: paciente.id,
          dataHora: DateTime(2026, 10, 25, 7, 10),
          nivelGlicose: 110,
          momento: 'Ao acordar',
        ));
        await tester.pumpAndSettle();

        await tester.tap(ouvir);
        await tester.pump();

        expect(
          tts.faladas.single,
          contains(
            'fazer 3 medições da glicemia, registrar a insulina lenta e '
            'registrar o sono',
          ),
        );
        // Agua, refeicoes, glicemia (com a insulina) e sono: quatro itens.
        expect(tts.faladas.single, contains('completou 0 de 4 itens'));

        await desmontar(tester);
      });

      testWidgets('Não deve citar glicemia na leitura de quem não tem diabetes', (tester) async {
        janelaAlta(tester);
        await montar(tester, narrador: await narradorLigado());

        await tester.tap(ouvir);
        await tester.pump();

        expect(tts.faladas.single, isNot(contains('glicemia')));
        expect(tts.faladas.single, isNot(contains('insulina')));

        await desmontar(tester);
      });

      testWidgets('Deve dizer que a rotina ainda está carregando, em vez de dizer que falta tudo', (tester) async {
        janelaAlta(tester);
        await montar(
          tester,
          repositorio: _RepositorioQueNaoResponde(fakeFirestore),
          narrador: await narradorLigado(),
        );

        await tester.tap(ouvir);
        await tester.pump();

        expect(tts.faladas.single, rotinaCarregandoNarrada);

        await desmontar(tester);
      });

      testWidgets('Deve dizer que não conseguiu ler a rotina quando a leitura falha', (tester) async {
        janelaAlta(tester);
        await montar(
          tester,
          repositorio: _RepositorioSemLeitura(fakeFirestore),
          narrador: await narradorLigado(),
        );

        await tester.tap(ouvir);
        await tester.pump();

        expect(tts.faladas.single, rotinaComErroNarrada);

        await desmontar(tester);
      });

      testWidgets('Deve calar a leitura ao voltar para o painel', (tester) async {
        janelaAlta(tester);
        await montar(tester, narrador: await narradorLigado());
        await tester.tap(ouvir);
        await tester.pump();
        expect(find.text('Parar de ouvir'), findsOneWidget);

        await tester.tap(find.text('Voltar'));
        await tester.pumpAndSettle();

        expect(tts.paradas, 1);
      });

      testWidgets('Não deve estourar o layout com a fonte do celular em 200%', (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await montar(tester, escalaTexto: 2, narrador: await narradorLigado());

        expect(ouvir, findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(ouvir);
        await tester.pump();
        expect(tester.takeException(), isNull);

        await desmontar(tester);
      });
    });
  });
}
