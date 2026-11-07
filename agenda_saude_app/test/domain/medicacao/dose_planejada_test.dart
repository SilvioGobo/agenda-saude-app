import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/medicacao/dose_planejada.dart';
import 'package:agenda_saude_app/domain/models/medicamento.dart';

void main() {
  group('DosePlanejada Testes', () {
    const losartana = Medicamento(
      id: 'm1',
      nome: 'Losartana',
      dose: '50 mg',
      horarios: ['08:00'],
    );
    const metformina = Medicamento(
      id: 'm2',
      nome: 'Metformina',
      dose: '500 mg',
      horarios: ['12:00', '20:00'],
    );

    test('Deve fazer uma dose por remédio e horário, do primeiro horário ao último', () {
      final doses = DosePlanejada.doDia([metformina, losartana]);

      expect(doses.map((d) => '${d.nome} ${d.horario}'), [
        'Losartana 08:00',
        'Metformina 12:00',
        'Metformina 20:00',
      ]);
    });

    test('Deve desempatar o mesmo horário pelo nome', () {
      const sinvastatina = Medicamento(
        id: 'm3',
        nome: 'Sinvastatina',
        horarios: ['12:00'],
      );

      final doses = DosePlanejada.doDia([sinvastatina, metformina]);

      expect(doses.map((d) => d.nome), ['Metformina', 'Sinvastatina', 'Metformina']);
    });

    test('Deve dar uma chave diferente ao mesmo remédio em horários diferentes', () {
      final doses = DosePlanejada.doDia([metformina]);

      expect(doses[0].chave, 'm2|12:00');
      expect(doses[1].chave, 'm2|20:00');
      expect(doses[0].chave, isNot(doses[1].chave));
    });

    test('Deve juntar o nome e a dose na descrição, e só o nome sem dose', () {
      final doses = DosePlanejada.doDia([
        losartana,
        const Medicamento(id: 'm4', nome: 'Vitamina D', horarios: ['09:00']),
      ]);

      expect(doses.first.descricao, 'Losartana 50 mg');
      expect(doses.last.descricao, 'Vitamina D');
    });

    test('Um remédio sem horários não gera dose nenhuma', () {
      expect(
        DosePlanejada.doDia([const Medicamento(id: 'm5', nome: 'Sem horário')]),
        isEmpty,
      );
      expect(DosePlanejada.doDia(const []), isEmpty);
    });
  });
}
