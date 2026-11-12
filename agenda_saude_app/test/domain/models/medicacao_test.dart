import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/models/medicamento.dart';
import 'package:agenda_saude_app/domain/models/registro_medicacao.dart';

void main() {
  group('Medicamento Testes', () {
    test('Deve ir para o JSON e voltar sem perder nada', () {
      const medicamento = Medicamento(
        id: 'm1',
        nome: 'Losartana potássica',
        dose: '50 mg',
        horarios: ['08:00', '20:00'],
        substancias: ['Losartana'],
      );

      final lido = Medicamento.fromJson(medicamento.toJson());

      expect(lido.id, 'm1');
      expect(lido.nome, 'Losartana potássica');
      expect(lido.dose, '50 mg');
      expect(lido.horarios, ['08:00', '20:00']);
      expect(lido.substancias, ['Losartana']);
    });

    test('Deve tratar campos que faltam como vazios', () {
      final lido = Medicamento.fromJson({'id': 'm9', 'nome': 'Aspirina'});

      expect(lido.dose, '');
      expect(lido.horarios, isEmpty);
      // Remedio cadastrado antes do catalogo de remedios.
      expect(lido.substancias, isEmpty);
      expect(Medicamento.fromJson({}).id, '');
    });

    test('Deve juntar o nome e a dose na descrição', () {
      expect(
        const Medicamento(id: 'm1', nome: 'Losartana', dose: ' 50 mg ').descricao,
        'Losartana 50 mg',
      );
      expect(const Medicamento(id: 'm2', nome: 'Aspirina').descricao, 'Aspirina');
    });
  });

  group('RegistroMedicacao Testes', () {
    test('Deve gravar o tipo e os dados da dose tomada', () {
      final registro = RegistroMedicacao(
        id: '',
        pacienteId: 'paciente_01',
        dataHora: DateTime(2026, 11, 6, 8, 10),
        medicamentoId: 'm1',
        horario: '08:00',
        nome: 'Losartana',
        dose: '50 mg',
      );

      final json = registro.toJson();

      expect(json['tipo'], 'medicacao');
      expect(json['pacienteId'], 'paciente_01');
      expect(json['dataHora'], DateTime(2026, 11, 6, 8, 10));
      expect(json['medicamentoId'], 'm1');
      expect(json['horario'], '08:00');
      expect(json['nome'], 'Losartana');
      expect(json['dose'], '50 mg');
    });

    test('Deve ler do Firestore, com o id do documento', () {
      final lido = RegistroMedicacao.fromJson({
        'tipo': 'medicacao',
        'pacienteId': 'paciente_01',
        'dataHora': Timestamp.fromDate(DateTime(2026, 11, 6, 8, 10)),
        'medicamentoId': 'm1',
        'horario': '08:00',
        'nome': 'Losartana',
        'dose': '50 mg',
      }, 'doc123');

      expect(lido.id, 'doc123');
      expect(lido.dataHora, DateTime(2026, 11, 6, 8, 10));
      expect(lido.medicamentoId, 'm1');
      expect(lido.horario, '08:00');
      expect(lido.descricao, 'Losartana 50 mg');
    });

    test('Deve ler um registro sem dose, só com o nome', () {
      final lido = RegistroMedicacao.fromJson({
        'pacienteId': 'paciente_01',
        'medicamentoId': 'm2',
        'horario': '12:00',
        'nome': 'Aspirina',
      }, 'doc456');

      expect(lido.dose, '');
      expect(lido.descricao, 'Aspirina');
    });
  });
}
