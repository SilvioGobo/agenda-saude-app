import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/data/repositories/dados_repository.dart';
import 'package:agenda_saude_app/data/repositories/relatorios_repository.dart';
import 'package:agenda_saude_app/domain/models/alerta.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/refeicao_planejada.dart';
import 'package:agenda_saude_app/domain/models/registro_agua.dart';
import 'package:agenda_saude_app/domain/models/registro_diabete.dart';
import 'package:agenda_saude_app/domain/relatorios/resumo_do_dia.dart';
import 'package:agenda_saude_app/ui/relatorios/estado_relatorio.dart';
import 'package:agenda_saude_app/ui/relatorios/relatorio_mes_viewmodel.dart';

// Conta quantas leituras foram feitas e falha quando `falhando` for
// verdadeiro.
class _RepositorioContador extends RelatoriosRepository {
  int leituras = 0;
  bool falhando = false;
  DateTime? ultimoFim;

  _RepositorioContador(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);

  @override
  Future<RegistrosDoPeriodo> registrosDoPeriodo(
    String pacienteId,
    DateTime inicio,
    DateTime fim, {
    required bool incluirDiabete,
  }) {
    leituras++;
    ultimoFim = fim;
    if (falhando) throw Exception('sem conexao');
    return super.registrosDoPeriodo(
      pacienteId,
      inicio,
      fim,
      incluirDiabete: incluirDiabete,
    );
  }
}

void main() {
  group('RelatorioMesViewModel Testes', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DadosMedicosRepository dadosRepository;
    late _RepositorioContador relatoriosRepository;
    late DateTime agora;

    Paciente criarPaciente({bool diabetes = false}) {
      return Paciente(
        id: 'paciente_01',
        nome: 'José Silva',
        email: 'jose@email.com',
        perfil: 'Paciente',
        possuiDiabetes: diabetes,
        possuiCardiopatia: false,
        codigoVinculo: 'ABC123',
        refeicoes: const [RefeicaoPlanejada(id: 'cafe', nome: 'Café')],
      );
    }

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      dadosRepository = DadosMedicosRepository(firestore: fakeFirestore);
      relatoriosRepository = _RepositorioContador(fakeFirestore);
      // 10 de novembro de 2026: o mes atual tem 9 dias encerrados.
      agora = DateTime(2026, 11, 10, 15);
    });

    RelatorioMesViewModel criar({Paciente? paciente}) {
      return RelatorioMesViewModel(
        paciente: paciente ?? criarPaciente(),
        relatoriosRepository: relatoriosRepository,
        agora: () => agora,
      );
    }

    Future<void> salvarCopos(DateTime base, int quantidade) async {
      for (var i = 0; i < quantidade; i++) {
        await dadosRepository.salvarRegistro(RegistroAgua(
          id: '',
          pacienteId: 'paciente_01',
          dataHora: base.add(Duration(minutes: i)),
          quantidadeML: 250,
        ));
      }
    }

    test('Deve abrir no mês atual, carregando', () {
      final viewModel = criar();

      expect(viewModel.mes, DateTime(2026, 11));
      expect(viewModel.estado, EstadoRelatorio.carregando);
      expect(viewModel.resumo, isNull);
      viewModel.dispose();
    });

    test('Deve abrir no mês anterior no dia 1, quando o mês atual ainda não tem dia encerrado', () {
      agora = DateTime(2026, 11, 1, 9);

      final viewModel = criar();

      expect(viewModel.mes, DateTime(2026, 10));
      viewModel.dispose();
    });

    test('Deve abrir em dezembro do ano anterior no dia 1 de janeiro', () {
      agora = DateTime(2027, 1, 1, 9);

      final viewModel = criar();

      expect(viewModel.mes, DateTime(2026, 12));
      viewModel.dispose();
    });

    test('Deve montar o resumo do mês atual só com os dias já encerrados', () async {
      await salvarCopos(DateTime(2026, 11, 2, 8), 8);
      await salvarCopos(DateTime(2026, 11, 5, 8), 3);
      // Hoje (dia 10) ainda nao terminou.
      await salvarCopos(DateTime(2026, 11, 10, 8), 8);
      final viewModel = criar();

      await viewModel.carregar();

      expect(viewModel.estado, EstadoRelatorio.pronto);
      final resumo = viewModel.resumo!;
      expect(resumo.dias.length, 9);
      expect(resumo.diasComAgua, 2);
      expect(resumo.diasMetaDeAgua, 1);
      expect(resumo.diaDeHoje, 10);
      // A leitura para na meia-noite de hoje.
      expect(relatoriosRepository.ultimoFim, DateTime(2026, 11, 10));
      viewModel.dispose();
    });

    test('Deve ler a glicemia só de quem tem diabetes e trazer os alertas do mês', () async {
      await dadosRepository.salvarRegistro(RegistroDiabete(
        id: '',
        pacienteId: 'paciente_01',
        dataHora: DateTime(2026, 11, 3, 7),
        nivelGlicose: 55,
        momento: 'Ao acordar',
      ));
      await dadosRepository.gerarAlerta(Alerta(
        id: '',
        pacienteId: 'paciente_01',
        tipo: Alerta.tipoEmergencia,
        mensagem: 'BPM alto',
        dataHora: DateTime(2026, 11, 4, 15),
      ));
      final diabetico = criar(paciente: criarPaciente(diabetes: true));
      final semDiabetes = criar();

      await diabetico.carregar();
      await semDiabetes.carregar();

      expect(diabetico.resumo!.diasComHipoglicemia, [3]);
      expect(diabetico.resumo!.diasComEmergencia, [4]);
      expect(semDiabetes.resumo!.temDiabetes, isFalse);
      diabetico.dispose();
      semDiabetes.dispose();
    });

    test('Não deve deixar avançar além do mês atual', () async {
      final viewModel = criar();
      await viewModel.carregar();

      expect(viewModel.podeAvancar, isFalse);
      final leiturasAntes = relatoriosRepository.leituras;
      await viewModel.proximoMes();

      expect(viewModel.mes, DateTime(2026, 11));
      expect(relatoriosRepository.leituras, leiturasAntes);
      viewModel.dispose();
    });

    test('Deve voltar ao mês anterior, com o mês inteiro encerrado, e avançar de novo', () async {
      await salvarCopos(DateTime(2026, 10, 31, 8), 8);
      final viewModel = criar();
      await viewModel.carregar();

      await viewModel.mesAnterior();

      expect(viewModel.mes, DateTime(2026, 10));
      expect(viewModel.podeAvancar, isTrue);
      expect(viewModel.resumo!.dias.length, 31);
      expect(viewModel.resumo!.diaDeHoje, isNull);
      expect(viewModel.resumo!.diasMetaDeAgua, 1);

      await viewModel.proximoMes();

      expect(viewModel.mes, DateTime(2026, 11));
      expect(viewModel.resumo!.dias.length, 9);
      viewModel.dispose();
    });

    test('Deve atravessar a virada de ano ao voltar de janeiro', () async {
      agora = DateTime(2027, 1, 15);
      final viewModel = criar();
      await viewModel.carregar();

      await viewModel.mesAnterior();

      expect(viewModel.mes, DateTime(2026, 12));
      expect(viewModel.resumo!.diasNoMes, 31);
      viewModel.dispose();
    });

    test('Não deve ler o Firestore de novo ao voltar a um mês que já terminou', () async {
      final viewModel = criar();
      await viewModel.carregar();
      await viewModel.mesAnterior(); // outubro: le do Firestore
      await viewModel.proximoMes(); // novembro: o mes atual e lido sempre
      final leiturasAntes = relatoriosRepository.leituras;

      await viewModel.mesAnterior(); // outubro de novo: ja estava guardado

      expect(relatoriosRepository.leituras, leiturasAntes);
      expect(viewModel.estado, EstadoRelatorio.pronto);
      expect(viewModel.mes, DateTime(2026, 10));
      viewModel.dispose();
    });

    test('Deve ler o mês atual de novo a cada carga, porque ele muda a cada dia', () async {
      final viewModel = criar();
      await viewModel.carregar();
      final leiturasAntes = relatoriosRepository.leituras;

      await viewModel.carregar();

      expect(relatoriosRepository.leituras, leiturasAntes + 1);
      viewModel.dispose();
    });

    test('Deve ir para o erro quando a leitura falha, e se recuperar ao tentar de novo', () async {
      relatoriosRepository.falhando = true;
      final viewModel = criar();

      await viewModel.carregar();

      expect(viewModel.estado, EstadoRelatorio.erro);
      expect(viewModel.resumo, isNull);

      relatoriosRepository.falhando = false;
      await viewModel.carregar();

      expect(viewModel.estado, EstadoRelatorio.pronto);
      expect(viewModel.resumo, isNotNull);
      viewModel.dispose();
    });

    test('Deve mostrar carregando ao trocar de mês e limpar o resumo do mês anterior', () async {
      final viewModel = criar();
      await viewModel.carregar();
      final estados = <EstadoRelatorio>[];
      viewModel.addListener(() => estados.add(viewModel.estado));

      await viewModel.mesAnterior();

      expect(estados, [EstadoRelatorio.carregando, EstadoRelatorio.pronto]);
      viewModel.dispose();
    });

    test('Deve descartar a resposta de um mês que o usuário já deixou para trás', () async {
      await salvarCopos(DateTime(2026, 9, 10, 8), 8);
      final viewModel = criar();
      await viewModel.carregar();

      // Dois cliques seguidos em "Mês anterior", sem esperar o primeiro.
      final primeira = viewModel.mesAnterior();
      final segunda = viewModel.mesAnterior();
      await Future.wait([primeira, segunda]);

      expect(viewModel.mes, DateTime(2026, 9));
      expect(viewModel.resumo!.mes, DateTime(2026, 9));
      expect(viewModel.resumo!.diasMetaDeAgua, 1);
      expect(
        viewModel.resumo!.dias.where((d) => d.situacao != SituacaoDoDia.semRegistro),
        hasLength(1),
      );
      viewModel.dispose();
    });

    test('Não deve estourar se a tela for fechada durante a leitura', () async {
      final viewModel = criar();

      final leitura = viewModel.carregar();
      viewModel.dispose();

      await expectLater(leitura, completes);
    });
  });
}
