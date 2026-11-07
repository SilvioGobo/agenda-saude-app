import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/theme/app_cores.dart';
import 'package:agenda_saude_app/domain/models/registro_agua.dart';
import 'package:agenda_saude_app/domain/models/registro_diabete.dart';
import 'package:agenda_saude_app/domain/models/registro_exercicio.dart';
import 'package:agenda_saude_app/domain/models/registro_medicacao.dart';
import 'package:agenda_saude_app/domain/models/registro_refeicao.dart';
import 'package:agenda_saude_app/domain/models/registro_sono.dart';
import 'package:agenda_saude_app/ui/acompanhante/formato_status_paciente.dart';
import 'package:agenda_saude_app/ui/acompanhante/status_paciente_viewmodel.dart';
import 'package:agenda_saude_app/ui/insulina/formatacao_diabete.dart';

void main() {
  group('Formato do status do paciente Testes', () {
    final quando = DateTime(2026, 11, 6, 9, 0);

    test('Deve dar rótulo, ícone e cor para cada status', () {
      expect(estiloDoStatus(StatusSaude.estavel).rotulo, 'ESTÁVEL');
      expect(estiloDoStatus(StatusSaude.estavel).cor, AppCores.sucesso);
      expect(estiloDoStatus(StatusSaude.atencao).rotulo, 'ATENÇÃO');
      expect(estiloDoStatus(StatusSaude.atencao).cor, AppCores.perigo);
      // Falta de dado e aviso (laranja): o vermelho fica para o alerta.
      expect(estiloDoStatus(StatusSaude.semDados).rotulo, 'SEM DADOS');
      expect(estiloDoStatus(StatusSaude.semDados).cor, AppCores.aviso);
      expect(estiloDoStatus(StatusSaude.semDados).icone, Icons.watch_off_rounded);
    });

    test('Deve descrever água e refeição', () {
      expect(
        descreverAtividade(RegistroAgua(
          id: '1',
          pacienteId: 'p',
          dataHora: quando,
          quantidadeML: 250,
        )).texto,
        'BEBEU ÁGUA: 250 ML',
      );
      expect(
        descreverAtividade(RegistroRefeicao(
          id: '2',
          pacienteId: 'p',
          dataHora: quando,
          refeicaoId: 'almoco',
          nome: 'Almoço',
        )).texto,
        'FEZ A REFEIÇÃO: ALMOÇO',
      );
    });

    test('Deve descrever glicemia, insulina e os dois juntos', () {
      RegistroDiabete diabete({double? glicose, double? dose}) => RegistroDiabete(
            id: '3',
            pacienteId: 'p',
            dataHora: quando,
            nivelGlicose: glicose,
            momento: 'Antes do almoço',
            doseInsulina: dose,
            tipoInsulina: dose == null ? null : 'Rápida',
          );

      final glicemia = descreverAtividade(diabete(glicose: 112));
      expect(glicemia.texto, 'MEDIU A GLICEMIA: ${formatarGlicemia(112)}');
      expect(glicemia.icone, Icons.bloodtype_rounded);

      final insulina = descreverAtividade(diabete(dose: 6));
      expect(
        insulina.texto,
        'APLICOU ${descreverInsulina('Rápida', 6).toUpperCase()}',
      );
      expect(insulina.icone, Icons.vaccines_rounded);

      expect(
        descreverAtividade(diabete(glicose: 112, dose: 6)).texto,
        'MEDIU A GLICEMIA: ${formatarGlicemia(112)} E '
        'APLICOU ${descreverInsulina('Rápida', 6).toUpperCase()}',
      );
    });

    test('Deve descrever sono e exercício', () {
      RegistroSono sono(double horas) => RegistroSono(
            id: '4',
            pacienteId: 'p',
            dataHora: quando,
            dataFim: quando,
            horasTotais: horas,
            qualidade: 4,
          );

      expect(descreverAtividade(sono(8)).texto, 'REGISTROU O SONO: 8 HORAS');
      expect(
        descreverAtividade(sono(1.5)).texto,
        'REGISTROU O SONO: 1 HORA E 30 MINUTOS',
      );
      expect(descreverAtividade(sono(0.75)).texto, 'REGISTROU O SONO: 45 MINUTOS');

      expect(
        descreverAtividade(RegistroExercicio(
          id: '5',
          pacienteId: 'p',
          dataHora: quando,
          tipoExercicio: 'Caminhada',
          duracaoMinutos: 30,
          intensidade: 'Leve',
        )).texto,
        'FEZ EXERCÍCIO: CAMINHADA, 30 MINUTOS',
      );
    });

    test('Deve descrever o remédio tomado, com a dose quando houver', () {
      RegistroMedicacao remedio({String nome = 'Losartana', String dose = ''}) =>
          RegistroMedicacao(
            id: '6',
            pacienteId: 'p',
            dataHora: quando,
            medicamentoId: 'm1',
            horario: '08:00',
            nome: nome,
            dose: dose,
          );

      final comDose = descreverAtividade(remedio(dose: '50 mg'));
      expect(comDose.texto, 'TOMOU O REMÉDIO: LOSARTANA 50 MG');
      expect(comDose.icone, Icons.medication_rounded);
      expect(descreverAtividade(remedio()).texto, 'TOMOU O REMÉDIO: LOSARTANA');
      expect(descreverAtividade(remedio(nome: '  ')).texto, 'TOMOU UM REMÉDIO');
    });
  });
}
