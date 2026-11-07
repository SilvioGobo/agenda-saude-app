import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/models/alerta.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/alertas/emergencia_view.dart';

import '../../core/services/fake_telefone_service.dart';

void main() {
  group('EmergenciaView Testes', () {
    final agora = DateTime(2026, 11, 6, 15, 0);
    late FakeTelefoneService telefoneService;

    Paciente criarPaciente({String? telefone}) => Paciente(
          id: 'paciente_01',
          nome: 'José Silva',
          email: 'jose@email.com',
          perfil: 'Paciente',
          telefone: telefone,
          possuiDiabetes: false,
          possuiCardiopatia: false,
          codigoVinculo: 'ABC123',
        );

    Alerta criarAlerta({int bpm = 128}) => Alerta(
          id: 'alerta_01',
          pacienteId: 'paciente_01',
          tipo: Alerta.tipoEmergencia,
          mensagem: 'Batimentos fora da zona de segurança há 6 minutos '
              '(última leitura: $bpm BPM).',
          bpm: bpm,
          dataHora: agora.subtract(const Duration(minutes: 3)),
        );

    setUp(() => telefoneService = FakeTelefoneService());

    Future<void> montar(
      WidgetTester tester, {
      Paciente? paciente,
      Alerta? alerta,
      WidgetBuilder? telaDeLocalizacao,
      double escalaTexto = 1,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escalaTexto)),
            child: child!,
          ),
          home: EmergenciaView(
            alerta: alerta ?? criarAlerta(),
            nomePaciente: 'José Silva',
            paciente: paciente,
            telaDeLocalizacao: telaDeLocalizacao,
            telefoneService: telefoneService,
            agora: agora,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // A lista so monta o que esta perto da tela: rola ate o botao antes.
    Future<void> mostrar(WidgetTester tester, String texto) =>
        tester.scrollUntilVisible(find.text(texto), 200);

    Future<void> tocar(WidgetTester tester, String texto) async {
      await mostrar(tester, texto);
      await tester.pumpAndSettle();
      await tester.tap(find.text(texto));
      await tester.pumpAndSettle();
    }

    testWidgets('Deve mostrar o alerta crítico com o paciente, o BPM e há quanto tempo', (tester) async {
      await montar(tester, paciente: criarPaciente(telefone: '67999990000'));

      expect(find.text('ALERTA CRÍTICO'), findsOneWidget);
      expect(find.text('José Silva'), findsOneWidget);
      expect(find.text('BATIMENTOS CARDÍACOS ELEVADOS'), findsOneWidget);
      expect(find.text('128'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
      expect(find.bySemanticsLabel('128 batimentos por minuto'), findsOneWidget);
      expect(find.text('HÁ 3 MINUTOS'), findsOneWidget);
      expect(find.textContaining('última leitura: 128 BPM'), findsOneWidget);
      expect(find.text('O que fazer'), findsOneWidget);
      expect(find.textContaining('Ligue agora para José'), findsOneWidget);
    });

    testWidgets('Botão "Ligar para José" disca o telefone do paciente', (tester) async {
      await montar(tester, paciente: criarPaciente(telefone: '(67) 99999-0000'));

      await tocar(tester, 'LIGAR PARA JOSÉ');

      expect(telefoneService.numerosChamados, ['(67) 99999-0000']);
    });

    testWidgets('Botão do SAMU disca 192', (tester) async {
      await montar(tester, paciente: criarPaciente(telefone: '67999990000'));

      await tocar(tester, 'LIGAR PARA O SAMU (192)');

      expect(telefoneService.numerosChamados, ['192']);
    });

    testWidgets('Sem telefone cadastrado, o botão de ligar para o paciente some', (tester) async {
      await montar(tester, paciente: criarPaciente());

      expect(find.text('LIGAR PARA JOSÉ'), findsNothing);
      expect(find.textContaining('Fale com José agora'), findsOneWidget);
      await mostrar(tester, 'LIGAR PARA O SAMU (192)');
      expect(find.text('LIGAR PARA O SAMU (192)'), findsOneWidget);
    });

    testWidgets('Paciente desvinculado: só o SAMU, sem ligar para ele nem localização', (tester) async {
      await montar(tester);

      expect(find.text('LIGAR PARA JOSÉ'), findsNothing);
      expect(find.text('VER LOCALIZAÇÃO'), findsNothing);
      await mostrar(tester, 'LIGAR PARA O SAMU (192)');
      expect(find.text('LIGAR PARA O SAMU (192)'), findsOneWidget);
    });

    testWidgets('Deve indicar batimentos baixos quando o BPM está abaixo da zona', (tester) async {
      await montar(tester, paciente: criarPaciente(), alerta: criarAlerta(bpm: 42));

      expect(find.text('BATIMENTOS CARDÍACOS BAIXOS'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('"Ver localização" abre a tela de onde o paciente está', (tester) async {
      await montar(
        tester,
        paciente: criarPaciente(),
        telaDeLocalizacao: (_) =>
            const Scaffold(body: Text('Onde está José')),
      );
      expect(
        find.textContaining('informe o endereço que aparece em "Ver localização"'),
        findsOneWidget,
      );

      await tocar(tester, 'VER LOCALIZAÇÃO');

      expect(find.text('Onde está José'), findsOneWidget);
    });

    testWidgets('Deve avisar quando o celular não consegue abrir o discador', (tester) async {
      telefoneService.abreDiscador = false;
      await montar(tester, paciente: criarPaciente());

      await tocar(tester, 'LIGAR PARA O SAMU (192)');

      expect(
        find.text('Não foi possível abrir o telefone deste celular. Ligue para 192.'),
        findsOneWidget,
      );
    });

    testWidgets('"Voltar" fecha a tela de emergência', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EmergenciaView(
                      alerta: criarAlerta(),
                      nomePaciente: 'José Silva',
                      telefoneService: telefoneService,
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
      expect(find.text('ALERTA CRÍTICO'), findsOneWidget);

      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('ALERTA CRÍTICO'), findsNothing);
      expect(find.text('Abrir'), findsOneWidget);
    });

    testWidgets('Não deve estourar o layout com a fonte do celular em 200%', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await montar(
        tester,
        paciente: criarPaciente(telefone: '67999990000'),
        telaDeLocalizacao: (_) => const SizedBox(),
        escalaTexto: 2,
      );

      await tester.scrollUntilVisible(find.text('LIGAR PARA JOSÉ'), 200);
      await tester.scrollUntilVisible(find.text('VER LOCALIZAÇÃO'), 200);
      expect(find.text('VER LOCALIZAÇÃO'), findsOneWidget);
    });
  });
}
