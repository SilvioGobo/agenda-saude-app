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
import '../shared/escolher_horario.dart';

// Nao consegue guardar o horario escolhido (ex.: armazenamento cheio).
class _PreferenciasQueNaoGravam extends PreferenciasRepository {
  @override
  Future<void> salvarHorarioDoMomento(
    String pacienteId,
    String nomeDoMomento,
    String? horario,
  ) =>
      throw Exception('sem espaco');
}

// O texto dentro do relogio aberto, e nao na lista atras dele.
Finder _noRelogio(String texto) => find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.text(texto),
    );

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

    // Por padrao, uma tela alta para a lista inteira ficar construida sem rolar.
    void ajustarTela(WidgetTester tester, Size tamanho) {
      tester.view.physicalSize = tamanho;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    // Monta a tela com um ViewModel de verdade; o provider o descarta ao desmontar
    // (cancelando o timer da virada do dia).
    Future<LembretesViewModel> montar(
      WidgetTester tester, {
      Paciente? paciente,
      PreferenciasRepository? preferencias,
      double escalaTexto = 1,
      Size tamanho = const Size(800, 3200),
    }) async {
      ajustarTela(tester, tamanho);
      final viewModel = LembretesViewModel(
        paciente: paciente ?? _paciente(),
        dadosRepository:
            DadosMedicosRepository(firestore: FakeFirebaseFirestore()),
        preferencias: preferencias ?? PreferenciasRepository(),
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
      expect(find.textContaining('use "Personalizar rotina"'), findsOneWidget);

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

    testWidgets('Deve mudar o horário de uma medição pelo relógio', (tester) async {
      final viewModel = await montar(
        tester,
        paciente: _paciente(possuiDiabetes: true, medicamentos: const []),
      );

      // A primeira é "ao acordar", às 07:00.
      await tester.tap(find.text('Mudar horário').first);
      await tester.pumpAndSettle();
      await escolherNoSeletorDeHorario(tester, hora: 6, minuto: 30);

      expect(find.byType(TimePickerDialog), findsNothing);
      expect(find.text('06:30'), findsOneWidget);
      expect(find.text('07:00'), findsNothing);
      expect(find.text('Horário mudado para 06:30.'), findsOneWidget);
      expect(
        servico.agendadas.values.any((a) => a.dataHora.hour == 6 && a.dataHora.minute == 30),
        isTrue,
      );
      // Nada de campo para digitar: o horário só se escolhe no relógio.
      expect(find.byType(TextField), findsNothing);

      await desmontar(tester, viewModel);
    });

    testWidgets('Deve abrir o relógio no horário do aviso, com o título do que muda',
        (tester) async {
      final viewModel = await montar(
        tester,
        paciente: _paciente(
          possuiDiabetes: true,
          usaInsulina: true,
          medicamentos: const [],
        ),
      );

      await tester.tap(find.text('Mudar horário').first);
      await tester.pumpAndSettle();
      expect(_noRelogio('HORÁRIO DA GLICEMIA'), findsOneWidget);
      expect(_noRelogio('07'), findsOneWidget);
      expect(_noRelogio('00'), findsOneWidget);
      // Confirmar o mesmo horário não muda nada nem mostra aviso.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('07:00'), findsOneWidget);

      // A última é a insulina lenta, às 22:00.
      await tester.tap(find.text('Mudar horário').last);
      await tester.pumpAndSettle();
      expect(_noRelogio('HORÁRIO DA INSULINA'), findsOneWidget);
      expect(_noRelogio('22'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      await desmontar(tester, viewModel);
    });

    testWidgets('Deve cancelar o relógio sem mudar o horário', (tester) async {
      final viewModel = await montar(
        tester,
        paciente: _paciente(possuiDiabetes: true, medicamentos: const []),
      );

      await tester.tap(find.text('Mudar horário').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsNothing);
      expect(find.text('07:00'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(viewModel.horarioFoiAlterado('Ao acordar'), isFalse);

      await desmontar(tester, viewModel);
    });

    testWidgets('Deve oferecer voltar ao horário padrão só depois de mudar',
        (tester) async {
      final viewModel = await montar(
        tester,
        paciente: _paciente(possuiDiabetes: true, medicamentos: const []),
      );
      expect(find.textContaining('Voltar para'), findsNothing);

      await tester.tap(find.text('Mudar horário').first);
      await tester.pumpAndSettle();
      await escolherNoSeletorDeHorario(tester, hora: 6, minuto: 30);

      // Só o cartão que mudou ganha o botão.
      expect(find.text('Voltar para 07:00'), findsOneWidget);
      expect(find.textContaining('Voltar para'), findsOneWidget);
      await tester.tap(find.text('Voltar para 07:00'));
      await tester.pumpAndSettle();

      expect(find.text('07:00'), findsOneWidget);
      expect(find.text('06:30'), findsNothing);
      expect(find.text('Voltar para 07:00'), findsNothing);
      expect(find.text('Horário de volta para 07:00.'), findsOneWidget);

      await desmontar(tester, viewModel);
    });

    testWidgets('Escolher no relógio o horário padrão deve ser o mesmo que voltar a ele',
        (tester) async {
      final viewModel = await montar(
        tester,
        paciente: _paciente(possuiDiabetes: true, medicamentos: const []),
      );

      await tester.tap(find.text('Mudar horário').first);
      await tester.pumpAndSettle();
      await escolherNoSeletorDeHorario(tester, hora: 6, minuto: 30);
      expect(find.text('Voltar para 07:00'), findsOneWidget);

      await tester.tap(find.text('Mudar horário').first);
      await tester.pumpAndSettle();
      await escolherNoSeletorDeHorario(tester, hora: 7, minuto: 0);

      expect(find.text('07:00'), findsOneWidget);
      expect(find.text('Voltar para 07:00'), findsNothing);
      expect(viewModel.horariosDosMomentos, isEmpty);

      await desmontar(tester, viewModel);
    });

    testWidgets('Deve avisar quando não consegue guardar o horário', (tester) async {
      final viewModel = await montar(
        tester,
        paciente: _paciente(possuiDiabetes: true, medicamentos: const []),
        preferencias: _PreferenciasQueNaoGravam(),
      );

      await tester.tap(find.text('Mudar horário').first);
      await tester.pumpAndSettle();
      await escolherNoSeletorDeHorario(tester, hora: 6, minuto: 30);

      expect(
        find.text('Não foi possível mudar o horário. Tente de novo.'),
        findsOneWidget,
      );
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

    testWidgets('Não deve estourar o cartão com os dois botões num celular, fonte em 200%',
        (tester) async {
      // Largura de celular; alta para a lista inteira ficar construida.
      final viewModel = await montar(
        tester,
        paciente: _paciente(possuiDiabetes: true, medicamentos: const []),
        escalaTexto: 2,
        tamanho: const Size(412, 4000),
      );

      await tester.tap(find.text('Mudar horário').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await escolherNoSeletorDeHorario(tester, hora: 6, minuto: 30);

      expect(tester.takeException(), isNull);
      expect(find.text('Voltar para 07:00'), findsOneWidget);

      await desmontar(tester, viewModel);
    });
  });
}
