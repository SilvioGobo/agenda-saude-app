import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/data/repositories/preferencias_repository.dart';
import 'package:agenda_saude_app/core/services/notification_service.dart';
import 'package:agenda_saude_app/domain/lembretes/lembrete.dart';
import 'package:agenda_saude_app/domain/lembretes/plano_de_lembretes.dart';
import 'package:agenda_saude_app/domain/models/medicamento.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/registro_diabete.dart';
import 'package:agenda_saude_app/domain/models/registro_medicacao.dart';
import 'package:agenda_saude_app/ui/lembretes/lembretes_viewmodel.dart';

import '../../core/services/fake_notification_service.dart';

// Recusa sempre um aviso (o do payload dado): os demais precisam sair assim mesmo.
class _ServicoQueRecusaUm extends FakeNotificationService {
  final String payloadRecusado;
  int tentativas = 0;

  _ServicoQueRecusaUm(this.payloadRecusado);

  @override
  Future<void> agendarLembrete({
    required int id,
    required String titulo,
    required String texto,
    required DateTime dataHora,
    String? payload,
  }) async {
    tentativas++;
    if (payload == payloadRecusado) throw Exception('o sistema recusou');
    return super.agendarLembrete(
      id: id,
      titulo: titulo,
      texto: texto,
      dataHora: dataHora,
      payload: payload,
    );
  }
}

// O primeiro agendamento fica preso ate `liberar` terminar (com `travar`): para
// testar o que acontece quando algo chega no meio de um plano.
class _ServicoLento extends FakeNotificationService {
  final Completer<void> liberar = Completer<void>();
  bool travar = false;
  int tentativas = 0;

  @override
  Future<void> agendarLembrete({
    required int id,
    required String titulo,
    required String texto,
    required DateTime dataHora,
    String? payload,
  }) async {
    tentativas++;
    if (travar && tentativas == 1) await liberar.future;
    return super.agendarLembrete(
      id: id,
      titulo: titulo,
      texto: texto,
      dataHora: dataHora,
      payload: payload,
    );
  }
}

// A leitura dos registros de hoje sempre falha (ex.: indice nao publicado).
class _RepositorioSemLeitura extends DadosMedicosRepository {
  _RepositorioSemLeitura(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Stream<List<RegistroMedicacao>> streamMedicacoesDoDia(
    String pacienteId,
    DateTime dia,
  ) =>
      Stream.error(Exception('indice faltando'));
}

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

const _losartana = Medicamento(
  id: 'm1',
  nome: 'Losartana',
  dose: '50 mg',
  horarios: ['08:00'],
);
const _metformina = Medicamento(
  id: 'm2',
  nome: 'Metformina',
  dose: '500 mg',
  horarios: ['12:00', '20:00'],
);

Paciente _paciente({
  bool possuiDiabetes = false,
  bool? usaInsulina,
  List<Medicamento> medicamentos = const [_losartana, _metformina],
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LembretesViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    late FakeNotificationService servico;
    late DateTime agora;
    final criados = <LembretesViewModel>[];

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
      servico = FakeNotificationService();
      // Quinta-feira, 5 de novembro de 2026, 7h: antes do remedio das 8h.
      agora = DateTime(2026, 11, 5, 7, 0);
    });

    tearDown(() {
      for (final viewModel in criados) {
        viewModel.dispose();
      }
      criados.clear();
    });

    LembretesViewModel criar({
      Paciente? paciente,
      NotificationService? notificationService,
      DadosMedicosRepository? repositorio,
      PreferenciasRepository? preferencias,
    }) {
      final viewModel = LembretesViewModel(
        paciente: paciente ?? _paciente(),
        dadosRepository: repositorio ?? dadosRepository,
        preferencias: preferencias ?? PreferenciasRepository(),
        notificationService: notificationService ?? servico,
        agora: () => agora,
      );
      criados.add(viewModel);
      return viewModel;
    }

    // Deixa os streams do Firestore e os agendamentos terminarem.
    Future<void> aguardar() async {
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    Future<LembretesViewModel> iniciar([LembretesViewModel? viewModel]) async {
      final criado = viewModel ?? criar();
      await criado.iniciar();
      await aguardar();
      return criado;
    }

    String hhmm(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    // Os horarios agendados em um dia, em ordem.
    List<String> horariosDe(int dia, {int mes = 11}) {
      return servico.agendadas.values
          .where((a) => a.dataHora.month == mes && a.dataHora.day == dia)
          .map((a) => hhmm(a.dataHora))
          .toList()
        ..sort();
    }

    Future<void> marcarDose({
      required String medicamentoId,
      required String horario,
      DateTime? quando,
    }) {
      return dadosRepository.salvarRegistro(
        RegistroMedicacao(
          id: '',
          pacienteId: 'paciente_01',
          dataHora: quando ?? DateTime(2026, 11, 5, 7, 30),
          medicamentoId: medicamentoId,
          horario: horario,
          nome: 'Remédio',
        ),
      );
    }

    group('agendamento', () {
      test('Deve agendar os remédios dos próximos sete dias ao iniciar', () async {
        await iniciar();

        // Três doses por dia, em sete dias.
        expect(servico.agendadas, hasLength(21));
        expect(horariosDe(5), ['08:00', '12:00', '20:00']);
        expect(horariosDe(11), ['08:00', '12:00', '20:00']);
        expect(horariosDe(12), isEmpty);
        expect(servico.inicializacoes, 1);
      });

      test('Deve agendar com o título, o texto e o payload do lembrete', () async {
        await iniciar();

        final losartanaHoje = servico.agendadas.values.firstWhere(
          (a) => a.dataHora == DateTime(2026, 11, 5, 8),
        );
        expect(losartanaHoje.titulo, 'Hora do remédio');
        expect(losartanaHoje.texto, contains('Losartana 50 mg'));
        expect(losartanaHoje.payload, 'lembrete:remedio|m1|08:00@2026-11-05');
      });

      test('Não deve agendar nada para quem não tem remédios nem diabetes', () async {
        await iniciar(criar(paciente: _paciente(medicamentos: const [])));

        expect(servico.agendadas, isEmpty);
      });

      test('Deve incluir a glicemia e a insulina lenta do diabético', () async {
        agora = DateTime(2026, 11, 5, 6, 0);

        await iniciar(
          criar(
            paciente: _paciente(
              possuiDiabetes: true,
              usaInsulina: true,
              medicamentos: const [],
            ),
          ),
        );

        expect(horariosDe(5), ['07:00', '11:30', '18:00', '21:30', '22:00']);
      });

      test('Não deve repetir o agendamento do mesmo aviso: um id, um agendamento', () async {
        await iniciar();

        // Dois planos seguidos deixam a mesma quantidade agendada.
        expect(servico.agendadas, hasLength(21));
        final ids = servico.agendadas.keys.toSet();
        expect(ids, hasLength(21));
      });
    });

    group('cumprir o lembrete', () {
      test('Deve tirar o aviso de hoje quando a dose é marcada, e manter o de amanhã', () async {
        await iniciar();
        expect(horariosDe(5), contains('08:00'));

        await marcarDose(medicamentoId: 'm1', horario: '08:00');
        await aguardar();

        expect(horariosDe(5), ['12:00', '20:00']);
        expect(horariosDe(6), ['08:00', '12:00', '20:00']);
      });

      test('Deve voltar a avisar se a dose for desmarcada', () async {
        await iniciar();
        await marcarDose(medicamentoId: 'm1', horario: '08:00');
        await aguardar();
        expect(horariosDe(5), isNot(contains('08:00')));

        final registros =
            await fakeFirestore.collection('registros_diarios').get();
        await dadosRepository.removerRegistro(registros.docs.single.id);
        await aguardar();

        expect(horariosDe(5), contains('08:00'));
      });

      test('Deve tirar da bandeja o aviso que já tocou quando a dose é marcada', () async {
        agora = DateTime(2026, 11, 5, 9, 0);
        await iniciar();
        servico.canceladas.clear();

        await marcarDose(
          medicamentoId: 'm1',
          horario: '08:00',
          quando: DateTime(2026, 11, 5, 9, 0),
        );
        await aguardar();

        final idDeHoje = OcorrenciaDeLembrete(
          // Mesmo lembrete que o ViewModel monta para a dose das 8h.
          Lembrete.doPaciente(_paciente())
              .firstWhere((l) => l.chave == 'remedio|m1|08:00'),
          DateTime(2026, 11, 5, 8),
        ).id;
        expect(servico.canceladas, contains(idDeHoje));
        // E o de amanhã continua.
        expect(horariosDe(6), contains('08:00'));
      });

      test('Deve tirar o aviso do momento da glicemia quando ele é registrado', () async {
        agora = DateTime(2026, 11, 5, 6, 0);
        await iniciar(
          criar(
            paciente: _paciente(possuiDiabetes: true, medicamentos: const []),
          ),
        );
        expect(horariosDe(5), contains('07:00'));

        await dadosRepository.salvarRegistro(
          RegistroDiabete(
            id: '',
            pacienteId: 'paciente_01',
            dataHora: DateTime(2026, 11, 5, 6, 30),
            momento: 'Ao acordar',
            nivelGlicose: 105,
          ),
        );
        await aguardar();

        expect(horariosDe(5), ['11:30', '18:00', '21:30']);
        expect(horariosDe(6), contains('07:00'));
      });
    });

    group('mudanças no paciente', () {
      test('Deve tirar do aparelho o aviso do remédio que o paciente apagou', () async {
        final viewModel = await iniciar();

        viewModel.atualizarPaciente(_paciente(medicamentos: const [_metformina]));
        await aguardar();

        expect(horariosDe(5), ['12:00', '20:00']);
        expect(
          servico.agendadas.values.any((a) => a.payload!.contains('|m1|')),
          isFalse,
        );
      });

      test('Deve trocar os avisos quando o horário do remédio muda', () async {
        final viewModel = await iniciar();

        viewModel.atualizarPaciente(
          _paciente(
            medicamentos: const [
              Medicamento(
                id: 'm1',
                nome: 'Losartana',
                dose: '50 mg',
                horarios: ['09:30'],
              ),
              _metformina,
            ],
          ),
        );
        await aguardar();

        expect(horariosDe(5), ['09:30', '12:00', '20:00']);
        expect(servico.agendadas, hasLength(21));
      });

      test('Deve agendar o remédio que o paciente acabou de cadastrar', () async {
        final viewModel =
            await iniciar(criar(paciente: _paciente(medicamentos: const [])));
        expect(servico.agendadas, isEmpty);

        viewModel.atualizarPaciente(_paciente(medicamentos: const [_losartana]));
        await aguardar();

        expect(horariosDe(5), ['08:00']);
      });

      test('Não deve refazer os avisos por uma mudança que não é de remédio', () async {
        final viewModel = await iniciar();
        final antes = servico.agendamentos;

        viewModel.atualizarPaciente(_paciente().copyWith(pesoKg: 80));
        await aguardar();

        expect(servico.agendamentos, antes);
      });

      test('Deve avisar os ouvintes, fora do build, quando o paciente muda', () async {
        final viewModel = await iniciar();
        var avisos = 0;
        viewModel.addListener(() => avisos++);

        viewModel.atualizarPaciente(_paciente(medicamentos: const [_losartana]));
        // Nao notifica na hora: o provider chama isto durante o build.
        expect(avisos, 0);
        await aguardar();

        expect(avisos, greaterThan(0));
      });
    });

    group('ligar e desligar', () {
      test('Deve desligar: cancela os avisos agendados e guarda a escolha', () async {
        final viewModel = await iniciar();
        expect(servico.agendadas, isNotEmpty);

        await viewModel.alternarLembretes(false);
        await aguardar();

        expect(viewModel.ligados, isFalse);
        expect(viewModel.situacao, SituacaoLembretes.desligados);
        expect(servico.agendadas, isEmpty);
        expect(await PreferenciasRepository().lembretesLigados('paciente_01'),
            isFalse);
      });

      test('Deve religar e agendar tudo de novo', () async {
        final viewModel = await iniciar();
        await viewModel.alternarLembretes(false);

        await viewModel.alternarLembretes(true);
        await aguardar();

        expect(viewModel.ligados, isTrue);
        expect(servico.agendadas, hasLength(21));
      });

      test('Deve começar desligado se o paciente já tinha desligado', () async {
        await PreferenciasRepository().salvarLembretesLigados('paciente_01', false);

        final viewModel = await iniciar();

        expect(viewModel.situacao, SituacaoLembretes.desligados);
        expect(servico.agendadas, isEmpty);
      });

      test('Deve usar o horário que o paciente escolheu para a glicemia', () async {
        agora = DateTime(2026, 11, 5, 5, 0);
        await PreferenciasRepository()
            .salvarHorarioDoMomento('paciente_01', 'Ao acordar', '06:15');

        await iniciar(
          criar(paciente: _paciente(possuiDiabetes: true, medicamentos: const [])),
        );

        expect(horariosDe(5), ['06:15', '11:30', '18:00', '21:30']);
      });
    });

    group('horários da glicemia', () {
      LembretesViewModel diabetico() => criar(
            paciente: _paciente(
              possuiDiabetes: true,
              usaInsulina: true,
              medicamentos: const [],
            ),
          );

      setUp(() => agora = DateTime(2026, 11, 5, 5, 0));

      test('Deve mudar o horário do aviso e agendar no novo horário', () async {
        final viewModel = await iniciar(diabetico());
        expect(horariosDe(5), contains('07:00'));

        final mudou =
            await viewModel.definirHorarioDoMomento('Ao acordar', '0630');
        await aguardar();

        expect(mudou, isTrue);
        expect(viewModel.horarioFoiAlterado('Ao acordar'), isTrue);
        expect(horariosDe(5), ['06:30', '11:30', '18:00', '21:30', '22:00']);
        expect(servico.agendadas, hasLength(5 * 7));
      });

      test('Deve mudar também a hora da insulina lenta', () async {
        final viewModel = await iniciar(diabetico());

        await viewModel.definirHorarioDoMomento('Insulina lenta (22h)', '21:00');
        await aguardar();

        expect(horariosDe(5), contains('21:00'));
        expect(horariosDe(5), isNot(contains('22:00')));
      });

      test('Não deve aceitar o que não é um horário', () async {
        final viewModel = await iniciar(diabetico());
        final antes = servico.agendamentos;

        final mudou =
            await viewModel.definirHorarioDoMomento('Ao acordar', '2575');
        await aguardar();

        expect(mudou, isFalse);
        expect(viewModel.horarioFoiAlterado('Ao acordar'), isFalse);
        expect(servico.agendamentos, antes);
        expect(horariosDe(5), contains('07:00'));
      });

      test('Deve voltar ao horário padrão', () async {
        final viewModel = await iniciar(diabetico());
        await viewModel.definirHorarioDoMomento('Ao acordar', '0630');

        final voltou = await viewModel.restaurarHorarioDoMomento('Ao acordar');
        await aguardar();

        expect(voltou, isTrue);
        expect(viewModel.horarioFoiAlterado('Ao acordar'), isFalse);
        expect(horariosDe(5), contains('07:00'));
        expect(horariosDe(5), isNot(contains('06:30')));
      });

      test('Deve lembrar o horário escolhido na próxima vez que o app abre', () async {
        final primeiro = await iniciar(diabetico());
        await primeiro.definirHorarioDoMomento('Ao acordar', '0630');

        servico = FakeNotificationService();
        final segundo = await iniciar(diabetico());

        expect(segundo.horariosDosMomentos, {'Ao acordar': '06:30'});
        expect(horariosDe(5), contains('06:30'));
      });

      test('Não deve mudar nada se não conseguir guardar o horário', () async {
        final viewModel = await iniciar(
          criar(
            paciente: _paciente(possuiDiabetes: true, medicamentos: const []),
            preferencias: _PreferenciasQueNaoGravam(),
          ),
        );

        final mudou =
            await viewModel.definirHorarioDoMomento('Ao acordar', '0630');

        expect(mudou, isFalse);
        expect(viewModel.horarioFoiAlterado('Ao acordar'), isFalse);
        expect(horariosDe(5), contains('07:00'));
      });
    });

    group('permissões', () {
      test('Deve pedir a permissão de notificações quando há lembretes e ela falta', () async {
        servico = FakeNotificationService(permitidas: false);

        final viewModel = await iniciar();

        expect(servico.solicitacoesDePermissao, 1);
        expect(viewModel.notificacoesPermitidas, isTrue);
        expect(viewModel.situacao, SituacaoLembretes.ativos);
      });

      test('Não deve incomodar com o pedido quem não tem o que lembrar', () async {
        servico = FakeNotificationService(permitidas: false);

        final viewModel =
            await iniciar(criar(paciente: _paciente(medicamentos: const [])));

        expect(servico.solicitacoesDePermissao, 0);
        expect(viewModel.situacao, SituacaoLembretes.semLembretes);
      });

      test('Deve apontar a falta de permissão quando o paciente nega', () async {
        servico = FakeNotificationService(
          permitidas: false,
          concederAoSolicitar: false,
        );

        final viewModel = await iniciar();

        expect(viewModel.situacao, SituacaoLembretes.semPermissao);
      });

      test('Deve fazer o pedido do sistema uma vez só por sessão', () async {
        servico = FakeNotificationService(
          permitidas: false,
          concederAoSolicitar: false,
        );
        final viewModel = await iniciar();

        viewModel.atualizarPaciente(_paciente(medicamentos: const [_losartana]));
        await aguardar();

        expect(servico.solicitacoesDePermissao, 1);
      });

      test('Deve abrir as configurações se o botão "Ativar notificações" não consegue a permissão', () async {
        servico = FakeNotificationService(
          permitidas: false,
          concederAoSolicitar: false,
        );
        final viewModel = await iniciar();

        await viewModel.ativarNotificacoes();

        expect(servico.aberturasDasConfiguracoes, 1);
        expect(viewModel.situacao, SituacaoLembretes.semPermissao);
      });

      test('Deve avisar que sem o alarme exato os avisos podem atrasar', () async {
        servico = FakeNotificationService(alarmesExatos: false);

        final viewModel = await iniciar();

        expect(viewModel.situacao, SituacaoLembretes.semAlarmeExato);
        // Mesmo assim os avisos ficam agendados.
        expect(servico.agendadas, hasLength(21));
      });

      test('Deve abrir a tela do sistema para permitir os alarmes exatos', () async {
        servico = FakeNotificationService(
          alarmesExatos: false,
          concederAlarmeExatoAoSolicitar: false,
        );
        final viewModel = await iniciar();

        await viewModel.permitirAlarmesExatos();

        expect(servico.solicitacoesDeAlarmeExato, 1);
      });

      test('Deve conferir de novo as permissões quando o paciente volta ao app', () async {
        servico = FakeNotificationService(alarmesExatos: false);
        final viewModel = await iniciar();
        expect(viewModel.situacao, SituacaoLembretes.semAlarmeExato);

        // O paciente permitiu na tela do Android e voltou.
        servico.alarmesExatos = true;
        viewModel.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await aguardar();

        expect(viewModel.situacao, SituacaoLembretes.ativos);
      });

      test('Deve refazer os avisos ao voltar ao app, completando os próximos dias', () async {
        final viewModel = await iniciar();
        servico.agendadas.clear();

        viewModel.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await aguardar();

        expect(servico.agendadas, hasLength(21));
      });
    });

    group('situações especiais', () {
      test('Não deve fazer nada em aparelho sem notificação do sistema', () async {
        servico = FakeNotificationService(disponivel: false);

        final viewModel = await iniciar();

        expect(viewModel.suportado, isFalse);
        expect(viewModel.situacao, SituacaoLembretes.naoSuportado);
        expect(servico.inicializacoes, 0);
        expect(servico.agendadas, isEmpty);
      });

      test('Deve cancelar todos os avisos ao sair da conta, e não agendar mais', () async {
        final viewModel = await iniciar();
        expect(servico.agendadas, isNotEmpty);

        await viewModel.cancelarTodos();
        expect(servico.agendadas, isEmpty);

        // Um registro novo mexeria no plano, mas a conta ja saiu.
        await marcarDose(medicamentoId: 'm1', horario: '08:00');
        await aguardar();
        expect(servico.agendadas, isEmpty);
      });

      test('Não deve agendar nada depois de cancelar, mesmo com um plano em andamento', () async {
        final lento = _ServicoLento();
        servico = lento;
        lento.travar = true;

        // O plano comeca a agendar e fica preso no primeiro aviso.
        final iniciando = criar().iniciar();
        await aguardar();
        expect(lento.tentativas, 1);

        // O paciente sai da conta enquanto o plano ainda esta agendando.
        final viewModel = criados.single;
        final cancelando = viewModel.cancelarTodos();
        lento.liberar.complete();
        await cancelando;
        await iniciando;
        await aguardar();

        // O plano parou assim que viu que a conta encerrou: nada ficou agendado.
        expect(lento.tentativas, 1);
        expect(servico.agendadas, isEmpty);
      });

      test('Não deve apagar a escolha de ligar ou desligar ao sair da conta', () async {
        final viewModel = await iniciar();
        await viewModel.alternarLembretes(false);

        await viewModel.cancelarTodos();

        expect(await PreferenciasRepository().lembretesLigados('paciente_01'),
            isFalse);
      });

      test('Deve agendar mesmo que a leitura dos registros de hoje falhe', () async {
        await iniciar(criar(repositorio: _RepositorioSemLeitura(fakeFirestore)));

        // Sem saber o que foi cumprido, e melhor avisar a mais do que a menos.
        expect(servico.agendadas, hasLength(21));
      });

      test('Um aviso que falha ao agendar não impede os outros', () async {
        const recusado = 'lembrete:remedio|m1|08:00@2026-11-05';
        final falho = _ServicoQueRecusaUm(recusado);
        servico = falho;

        await iniciar();

        // Os outros 20 foram agendados; so o recusado ficou de fora.
        expect(falho.tentativas, greaterThanOrEqualTo(21));
        expect(servico.agendadas, hasLength(20));
        expect(
          servico.agendadas.values.any((a) => a.payload == recusado),
          isFalse,
        );
      });

      test('Deve completar os próximos dias na virada do dia', () async {
        // Faltam 300 ms para a meia-noite; o relogio do teste ja passa dela
        // quando o timer da virada dispara.
        agora = DateTime(2026, 11, 5, 23, 59, 59, 700);
        await iniciar();
        expect(horariosDe(12), isEmpty);

        agora = DateTime(2026, 11, 6, 0, 0, 0, 100);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await aguardar();

        // Entrou o ultimo dia da janela de sete dias.
        expect(horariosDe(12), ['08:00', '12:00', '20:00']);
      });
    });
  });
}
