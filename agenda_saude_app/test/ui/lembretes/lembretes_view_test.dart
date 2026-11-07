import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/data/repositories/preferencias_repository.dart';
import 'package:agenda_saude_app/domain/models/medicamento.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/ui/lembretes/lembretes_view.dart';
import 'package:agenda_saude_app/ui/lembretes/lembretes_viewmodel.dart';

import '../../core/services/fake_notification_service.dart';

const _losartana = Medicamento(
  id: 'm1',
  nome: 'Losartana',
  dose: '50 mg',
  horarios: ['08:00'],
);

Paciente _paciente({
  bool possuiDiabetes = false,
  bool? usaInsulina,
  List<Medicamento> medicamentos = const [_losartana],
}) {
  return Paciente(
    id: 'paciente_01',
    nome: 'José Silva',
    email: 'jose@email.com',
    perfil: 'Paciente',
    possuiDiabetes: possuiDiabetes,
    usaInsulina: usaInsulina,
    possuiCardiopatia: false,
    codigoVinculo: 'ABC123',
    medicamentos: medicamentos,
  );
}

void main() {
  group('LembretesView Testes', () {
    late FakeNotificationService servico;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      servico = FakeNotificationService();
    });

    // Uma tela alta para a lista inteira ficar construida sem rolar.
    void telaAlta(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    // Monta a tela com um ViewModel de verdade; o provider o descarta ao desmontar
    // (cancelando o timer da virada do dia).
    Future<LembretesViewModel> montar(
      WidgetTester tester, {
      Paciente? paciente,
      double escalaTexto = 1,
    }) async {
      telaAlta(tester);
      final viewModel = LembretesViewModel(
        paciente: paciente ?? _paciente(),
        dadosRepository:
            DadosMedicosRepository(firestore: FakeFirebaseFirestore()),
        preferencias: PreferenciasRepository(),
        notificationService: servico,
        // Antes das 7h, para os horarios padrao de hoje ainda estarem por vir.
        agora: () => DateTime(2026, 11, 5, 5, 0),
      );
      await viewModel.iniciar();

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escalaTexto)),
            child: child!,
          ),
          home: ChangeNotifierProvider.value(
            value: viewModel,
            child: const LembretesView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return viewModel;
    }

    // Descarta o ViewModel (cancela o timer) depois de tirar a tela.
    Future<void> desmontar(
      WidgetTester tester,
      LembretesViewModel viewModel,
    ) async {
      await tester.pumpWidget(const SizedBox());
      viewModel.dispose();
    }

    testWidgets('Deve mostrar o título, o estado e os horários dos remédios',
        (tester) async {
      final viewModel = await montar(tester);

      expect(find.text('Meus lembretes'), findsOneWidget);
      expect(find.text('Lembretes ligados'), findsOneWidget);
      expect(find.text('Seus horários'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('Tomar Losartana 50 mg'), findsOneWidget);
      // O horário de remédio se muda em outra tela.
      expect(find.text('Mudar horário'), findsNothing);
      expect(find.textContaining('use "Meus remédios"'), findsOneWidget);

      await desmontar(tester, viewModel);
    });

    testWidgets('Deve mostrar os horários da glicemia e da insulina para o diabético',
        (tester) async {
      final viewModel = await montar(
        tester,
        paciente: _paciente(
          possuiDiabetes: true,
          usaInsulina: true,
          medicamentos: const [],
        ),
      );

      expect(find.text('07:00'), findsOneWidget);
      expect(find.text('Medir a glicemia (ao acordar)'), findsOneWidget);
      expect(find.text('22:00'), findsOneWidget);
      expect(find.text('Aplicar a insulina lenta'), findsOneWidget);
      // Quatro medições e a insulina lenta têm o horário editável.
      expect(find.text('Mudar horário'), findsNWidgets(5));

      await desmontar(tester, viewModel);
    });

    testWidgets('Deve desligar os lembretes e ligar de novo', (tester) async {
      final viewModel = await montar(tester);
      expect(servico.agendadas, isNotEmpty);

      await tester.tap(find.text('Desligar lembretes'));
      await tester.pumpAndSettle();

      expect(find.text('Lembretes desligados'), findsOneWidget);
      expect(find.text('Ligar lembretes'), findsOneWidget);
      expect(servico.agendadas, isEmpty);

      await tester.tap(find.text('Ligar lembretes'));
      await tester.pumpAndSettle();

      expect(find.text('Lembretes ligados'), findsOneWidget);
      expect(servico.agendadas, isNotEmpty);

      await desmontar(tester, viewModel);
    });

    testWidgets('Deve oferecer o botão quando as notificações estão desativadas',
        (tester) async {
      servico = FakeNotificationService(
        permitidas: false,
        concederAoSolicitar: false,
      );
      final viewModel = await montar(tester);

      expect(find.text('Notificações desativadas'), findsOneWidget);

      await tester.tap(find.text('Ativar notificações'));
      await tester.pumpAndSettle();

      expect(servico.aberturasDasConfiguracoes, 1);

      await desmontar(tester, viewModel);
    });

    testWidgets('Deve pedir a permissão de alarmes exatos', (tester) async {
      servico = FakeNotificationService(
        alarmesExatos: false,
        concederAlarmeExatoAoSolicitar: false,
      );
      final viewModel = await montar(tester);

      expect(find.text('Permita "Alarmes e lembretes"'), findsOneWidget);
      expect(find.textContaining('pode atrasar'), findsOneWidget);

      await tester.tap(find.text('Permitir alarmes'));
      await tester.pumpAndSettle();

      expect(servico.solicitacoesDeAlarmeExato, 1);

      await desmontar(tester, viewModel);
    });

    testWidgets('Deve orientar quem ainda não tem lembretes', (tester) async {
      final viewModel =
          await montar(tester, paciente: _paciente(medicamentos: const []));

      expect(find.textContaining('Você ainda não tem lembretes'), findsOneWidget);

      await desmontar(tester, viewModel);
    });

    testWidgets('Deve avisar quando o aparelho não mostra avisos agendados',
        (tester) async {
      servico = FakeNotificationService(disponivel: false);
      final viewModel = await montar(tester);

      expect(find.text('Lembretes indisponíveis'), findsOneWidget);
      expect(find.text('Desligar lembretes'), findsNothing);

      await desmontar(tester, viewModel);
    });

    testWidgets('Deve mudar o horário de uma medição pelo diálogo', (tester) async {
      final viewModel = await montar(
        tester,
        paciente: _paciente(possuiDiabetes: true, medicamentos: const []),
      );

      // A primeira é "ao acordar", às 07:00.
      await tester.tap(find.text('Mudar horário').first);
      await tester.pumpAndSettle();
      expect(find.text('Medir a glicemia (ao acordar)'), findsNWidgets(2));

      await tester.enterText(find.byType(TextField), '0630');
      await tester.tap(find.text('Salvar horário'));
      await tester.pumpAndSettle();

      expect(find.text('06:30'), findsOneWidget);
      expect(find.text('07:00'), findsNothing);
      expect(
        servico.agendadas.values.any((a) => a.dataHora.hour == 6 && a.dataHora.minute == 30),
        isTrue,
      );

      await desmontar(tester, viewModel);
    });

    testWidgets('Deve recusar um horário que não existe e manter o diálogo aberto',
        (tester) async {
      final viewModel = await montar(
        tester,
        paciente: _paciente(possuiDiabetes: true, medicamentos: const []),
      );

      await tester.tap(find.text('Mudar horário').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '2575');
      await tester.tap(find.text('Salvar horário'));
      await tester.pumpAndSettle();

      expect(find.textContaining('HORÁRIO INVÁLIDO'), findsOneWidget);
      expect(find.text('Salvar horário'), findsOneWidget);
      expect(find.text('07:00'), findsOneWidget);

      await desmontar(tester, viewModel);
    });

    testWidgets('Deve cancelar o diálogo sem mudar o horário', (tester) async {
      final viewModel = await montar(
        tester,
        paciente: _paciente(possuiDiabetes: true, medicamentos: const []),
      );

      await tester.tap(find.text('Mudar horário').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Salvar horário'), findsNothing);
      expect(find.text('07:00'), findsOneWidget);

      await desmontar(tester, viewModel);
    });

    testWidgets('Deve oferecer voltar ao horário padrão só depois de mudar',
        (tester) async {
      final viewModel = await montar(
        tester,
        paciente: _paciente(possuiDiabetes: true, medicamentos: const []),
      );

      await tester.tap(find.text('Mudar horário').first);
      await tester.pumpAndSettle();
      expect(find.text('Voltar para 07:00'), findsNothing);
      await tester.enterText(find.byType(TextField), '0630');
      await tester.tap(find.text('Salvar horário'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mudar horário').first);
      await tester.pumpAndSettle();
      expect(find.text('Voltar para 07:00'), findsOneWidget);
      await tester.tap(find.text('Voltar para 07:00'));
      await tester.pumpAndSettle();

      expect(find.text('07:00'), findsOneWidget);
      expect(find.text('06:30'), findsNothing);

      await desmontar(tester, viewModel);
    });

    testWidgets('Deve falar cada lembrete por inteiro para o leitor de tela',
        (tester) async {
      final semantica = tester.ensureSemantics();
      final viewModel = await montar(tester);

      expect(
        find.bySemanticsLabel('Tomar Losartana 50 mg, às 8 horas'),
        findsOneWidget,
      );

      await desmontar(tester, viewModel);
      semantica.dispose();
    });

    testWidgets('Não deve estourar o layout com a fonte do celular em 200%',
        (tester) async {
      final viewModel = await montar(
        tester,
        paciente: _paciente(possuiDiabetes: true, usaInsulina: true),
        escalaTexto: 2,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Meus lembretes'), findsOneWidget);

      await desmontar(tester, viewModel);
    });
  });
}
