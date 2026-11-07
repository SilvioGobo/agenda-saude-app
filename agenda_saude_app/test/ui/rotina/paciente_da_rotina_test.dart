import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/models/medicamento.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/refeicao_planejada.dart';
import 'package:agenda_saude_app/ui/rotina/paciente_da_rotina.dart';

void main() {
  group('PacienteDaRotina Testes', () {
    late Paciente original;
    late List<Paciente> avisados;
    late PacienteDaRotina paciente;

    const plano = [RefeicaoPlanejada(id: 'r1', nome: 'Café')];
    const remedios = [
      Medicamento(id: 'm1', nome: 'Losartana', horarios: ['08:00']),
    ];

    setUp(() {
      original = Paciente(
        id: 'paciente_01',
        nome: 'José Silva',
        email: 'jose@email.com',
        perfil: 'Paciente',
        possuiDiabetes: false,
        possuiCardiopatia: false,
        codigoVinculo: 'ABC123',
      );
      avisados = [];
      paciente = PacienteDaRotina(original, avisados.add);
    });

    // O ViewModel de cada cartao guarda a SUA copia do paciente (a de quando a
    // Rotina abriu) e avisa com ela mais a mudanca que fez.
    Paciente copiaDoCartaoDeRefeicoes() => original.copyWith(refeicoes: plano);
    Paciente copiaDoCartaoDeMedicacoes() =>
        original.copyWith(medicamentos: remedios);

    test('Deve avisar o painel com o plano de refeições novo', () {
      paciente.refeicoesMudaram(copiaDoCartaoDeRefeicoes());

      expect(avisados.single.refeicoes!.map((r) => r.nome), ['Café']);
      expect(avisados.single.medicamentos, isEmpty);
    });

    test('Deve avisar o painel com os remédios novos', () {
      paciente.medicamentosMudaram(copiaDoCartaoDeMedicacoes());

      expect(avisados.single.medicamentos.map((m) => m.nome), ['Losartana']);
      expect(avisados.single.refeicoes, isNull);
    });

    test('Salvar os remédios e depois as refeições não deve desfazer os remédios', () {
      paciente.medicamentosMudaram(copiaDoCartaoDeMedicacoes());
      // O cartao de refeicoes ainda tem a copia de antes dos remedios.
      paciente.refeicoesMudaram(copiaDoCartaoDeRefeicoes());

      final ultimo = avisados.last;
      expect(ultimo.medicamentos.map((m) => m.nome), ['Losartana']);
      expect(ultimo.refeicoes!.map((r) => r.nome), ['Café']);
    });

    test('Salvar as refeições e depois os remédios não deve desfazer as refeições', () {
      paciente.refeicoesMudaram(copiaDoCartaoDeRefeicoes());
      paciente.medicamentosMudaram(copiaDoCartaoDeMedicacoes());

      final ultimo = avisados.last;
      expect(ultimo.refeicoes!.map((r) => r.nome), ['Café']);
      expect(ultimo.medicamentos.map((m) => m.nome), ['Losartana']);
      expect(paciente.atual.medicamentos, hasLength(1));
    });

    test('Deve funcionar sem ninguém para avisar', () {
      final semPainel = PacienteDaRotina(original, null);

      semPainel.medicamentosMudaram(copiaDoCartaoDeMedicacoes());

      expect(semPainel.atual.medicamentos, hasLength(1));
    });
  });
}
