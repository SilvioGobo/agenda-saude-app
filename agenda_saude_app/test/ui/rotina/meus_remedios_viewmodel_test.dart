import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/models/medicamento.dart';
import 'package:agenda_saude_app/ui/rotina/meus_remedios_viewmodel.dart';

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

void main() {
  group('MeusRemediosViewModel Testes', () {
    late List<List<Medicamento>> salvos;
    late bool gravaComSucesso;

    setUp(() {
      salvos = [];
      gravaComSucesso = true;
    });

    MeusRemediosViewModel criar({List<Medicamento> atual = const []}) {
      var contador = 0;
      return MeusRemediosViewModel(
        atual: atual,
        aoSalvar: (lista) async {
          if (gravaComSucesso) salvos.add(lista);
          return gravaComSucesso;
        },
        gerarId: () => 'novo${++contador}',
      );
    }

    // Digita no campo de horario do remedio e toca em "Adicionar horario".
    bool digitarEAdicionar(
      MeusRemediosViewModel viewModel,
      RemedioEmEdicao remedio,
      String texto,
    ) {
      viewModel.definirHorarioDigitado(remedio, texto);
      return viewModel.adicionarHorario(remedio);
    }

    test('Deve começar com os remédios que o paciente já tem', () {
      final viewModel = criar(atual: const [_losartana, _metformina]);

      expect(viewModel.remedios.map((r) => r.nome), ['Losartana', 'Metformina']);
      expect(viewModel.remedios.last.horarios, ['12:00', '20:00']);
      expect(viewModel.salvando, isFalse);
      expect(viewModel.mensagemErro, isNull);
    });

    test('Deve copiar os horários: editar o rascunho não mexe no que já está salvo', () {
      const original = _metformina;
      final viewModel = criar(atual: const [original]);

      viewModel.removerHorario(viewModel.remedios.single, '12:00');

      expect(viewModel.remedios.single.horarios, ['20:00']);
      expect(original.horarios, ['12:00', '20:00']);
    });

    test('Deve adicionar e remover remédios', () {
      final viewModel = criar();

      viewModel.adicionar();
      viewModel.adicionar();
      expect(viewModel.remedios.map((r) => r.id), ['novo1', 'novo2']);

      viewModel.remover('novo1');
      expect(viewModel.remedios.map((r) => r.id), ['novo2']);
    });

    test('Deve parar de adicionar remédios no limite', () {
      final viewModel = criar();

      for (var i = 0; i < 20; i++) {
        viewModel.adicionar();
      }

      expect(viewModel.remedios.length, 10);
      expect(viewModel.podeAdicionar, isFalse);
    });

    test('Deve guardar o horário digitado como HH:MM, em ordem', () {
      final viewModel = criar(atual: const [_losartana]);
      final remedio = viewModel.remedios.single;

      expect(digitarEAdicionar(viewModel, remedio, '2000'), isTrue);
      expect(digitarEAdicionar(viewModel, remedio, '6'), isTrue);
      expect(digitarEAdicionar(viewModel, remedio, '14:30'), isTrue);

      expect(remedio.horarios, ['06:00', '08:00', '14:30', '20:00']);
      expect(remedio.horarioDigitado, '');
      expect(remedio.erroHorario, isNull);
    });

    test('Deve recriar o campo de horário ao adicionar um horário', () {
      final viewModel = criar(atual: const [_losartana]);
      final remedio = viewModel.remedios.single;
      final antes = remedio.versaoDoHorario;

      digitarEAdicionar(viewModel, remedio, '1200');

      expect(remedio.versaoDoHorario, antes + 1);
    });

    test('Deve explicar por que um horário não entrou, sem apagar o que foi digitado', () {
      final viewModel = criar(atual: const [_losartana]);
      final remedio = viewModel.remedios.single;

      expect(digitarEAdicionar(viewModel, remedio, ''), isFalse);
      expect(remedio.erroHorario, contains('Digite o horário'));

      expect(digitarEAdicionar(viewModel, remedio, '2560'), isFalse);
      expect(remedio.erroHorario, contains('não existe'));
      expect(remedio.horarioDigitado, '2560');

      expect(digitarEAdicionar(viewModel, remedio, '0800'), isFalse);
      expect(remedio.erroHorario, 'Esse horário já está na lista.');

      expect(remedio.horarios, ['08:00']);
    });

    test('Deve limpar o aviso do horário ao digitar de novo', () {
      final viewModel = criar(atual: const [_losartana]);
      final remedio = viewModel.remedios.single;
      digitarEAdicionar(viewModel, remedio, '9999');
      expect(remedio.erroHorario, isNotNull);

      viewModel.definirHorarioDigitado(remedio, '0900');

      expect(remedio.erroHorario, isNull);
    });

    test('Deve limitar os horários de cada remédio', () {
      final viewModel = criar();
      viewModel.adicionar();
      final remedio = viewModel.remedios.single;

      for (final horario in ['0600', '0800', '1000', '1200', '1400', '1600']) {
        expect(digitarEAdicionar(viewModel, remedio, horario), isTrue);
      }

      expect(viewModel.podeAdicionarHorario(remedio), isFalse);
      expect(digitarEAdicionar(viewModel, remedio, '1800'), isFalse);
      expect(remedio.erroHorario, contains('até 6 horários'));
      expect(remedio.horarios, hasLength(6));
    });

    test('Deve remover um horário', () {
      final viewModel = criar(atual: const [_metformina]);

      viewModel.removerHorario(viewModel.remedios.single, '12:00');

      expect(viewModel.remedios.single.horarios, ['20:00']);
    });

    test('Deve pedir o nome de todos os remédios antes de salvar', () async {
      final viewModel = criar();
      viewModel.adicionar();
      digitarEAdicionar(viewModel, viewModel.remedios.single, '0800');

      final salvou = await viewModel.salvar();

      expect(salvou, isFalse);
      expect(viewModel.mensagemErro, 'Dê um nome para todos os remédios.');
      expect(salvos, isEmpty);
    });

    test('Deve pedir pelo menos um horário para cada remédio antes de salvar', () async {
      final viewModel = criar();
      viewModel.adicionar();
      viewModel.definirNome(viewModel.remedios.single, 'Losartana');

      final salvou = await viewModel.salvar();

      expect(salvou, isFalse);
      expect(
        viewModel.mensagemErro,
        'Escolha pelo menos um horário para cada remédio.',
      );
      expect(salvos, isEmpty);
    });

    test('Deve salvar os remédios com o nome e a dose sem espaços sobrando', () async {
      final viewModel = criar(atual: const [_metformina]);
      viewModel.adicionar();
      final novo = viewModel.remedios.last;
      viewModel.definirNome(novo, '  Losartana ');
      viewModel.definirDose(novo, ' 50 mg ');
      digitarEAdicionar(viewModel, novo, '0800');

      final salvou = await viewModel.salvar();

      expect(salvou, isTrue);
      expect(viewModel.mensagemErro, isNull);
      expect(viewModel.salvando, isFalse);
      final lista = salvos.single;
      expect(lista.map((m) => m.nome), ['Metformina', 'Losartana']);
      expect(lista.last.id, 'novo1');
      expect(lista.last.dose, '50 mg');
      expect(lista.last.horarios, ['08:00']);
      expect(lista.first.horarios, ['12:00', '20:00']);
    });

    test('Deve acrescentar o horário que foi digitado mas não adicionado ao salvar', () async {
      final viewModel = criar(atual: const [_losartana]);
      viewModel.definirHorarioDigitado(viewModel.remedios.single, '2000');

      final salvou = await viewModel.salvar();

      expect(salvou, isTrue);
      expect(salvos.single.single.horarios, ['08:00', '20:00']);
    });

    test('Não deve salvar quando o horário digitado e não adicionado está errado', () async {
      final viewModel = criar(atual: const [_losartana]);
      viewModel.definirHorarioDigitado(viewModel.remedios.single, '9999');

      final salvou = await viewModel.salvar();

      expect(salvou, isFalse);
      expect(viewModel.mensagemErro, 'Confira o horário digitado.');
      expect(viewModel.remedios.single.erroHorario, contains('não existe'));
      expect(salvos, isEmpty);
    });

    test('Deve aceitar salvar sem nenhum remédio: quem para de tomar apaga a lista', () async {
      final viewModel = criar(atual: const [_losartana]);
      viewModel.remover('m1');

      final salvou = await viewModel.salvar();

      expect(salvou, isTrue);
      expect(salvos.single, isEmpty);
    });

    test('Deve avisar quando não conseguir salvar, e deixar tentar de novo', () async {
      gravaComSucesso = false;
      final viewModel = criar(atual: const [_losartana]);

      final salvou = await viewModel.salvar();

      expect(salvou, isFalse);
      expect(viewModel.mensagemErro, 'Não foi possível salvar. Tente de novo.');
      expect(viewModel.salvando, isFalse);

      gravaComSucesso = true;
      expect(await viewModel.salvar(), isTrue);
      expect(viewModel.mensagemErro, isNull);
    });

    test('Deve limpar o aviso do "Salvar" quando a pessoa edita', () async {
      final viewModel = criar();
      viewModel.adicionar();
      await viewModel.salvar();
      expect(viewModel.mensagemErro, isNotNull);

      viewModel.definirNome(viewModel.remedios.single, 'L');

      expect(viewModel.mensagemErro, isNull);
    });
  });
}
