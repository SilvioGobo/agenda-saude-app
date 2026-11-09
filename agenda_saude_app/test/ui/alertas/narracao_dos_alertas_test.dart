import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/models/alerta.dart';
import 'package:agenda_saude_app/ui/alertas/narracao_dos_alertas.dart';

int palavras(String texto) => texto.split(RegExp(r'\s+')).length;

Alerta alerta(
  String id, {
  String tipo = Alerta.tipoEmergencia,
  String pacienteId = 'p1',
  int? bpm = 130,
  DateTime? dataHora,
  bool lido = false,
}) {
  return Alerta(
    id: id,
    pacienteId: pacienteId,
    tipo: tipo,
    mensagem: 'mensagem $id',
    bpm: bpm,
    dataHora: dataHora ?? DateTime(2026, 11, 7, 14, 30),
    lido: lido,
  );
}

String nomeDe(String pacienteId) => switch (pacienteId) {
      'p1' => 'Maria Aparecida',
      'p2' => 'José Silva',
      _ => 'Paciente',
    };

void main() {
  final agora = DateTime(2026, 11, 7, 14, 35);

  group('narrarNotificacoes Testes', () {
    String narrar(List<Alerta> alertas) =>
        narrarNotificacoes(alertas: alertas, nomeDoPaciente: nomeDe, agora: agora);

    test('Deve explicar que não há notificações', () {
      expect(
        narrar([]),
        'Nenhuma notificação por enquanto. Quando algum paciente precisar de '
        'atenção, você será avisado aqui e no celular.',
      );
    });

    test('Deve contar as não lidas e ler cada uma com paciente, nível e quando', () {
      final texto = narrar([
        alerta('a1', dataHora: DateTime(2026, 11, 7, 14, 30)),
        alerta(
          'a2',
          tipo: Alerta.tipoAtencao,
          pacienteId: 'p2',
          bpm: 112,
          dataHora: DateTime(2026, 11, 7, 9, 10),
        ),
      ]);

      expect(
        texto,
        'Você tem 2 notificações não lidas. '
        'Emergência de Maria: 130 batimentos por minuto, há 5 minutos. '
        'Atenção de José: 112 batimentos por minuto, hoje, às 9 horas e 10 '
        'minutos.',
      );
    });

    test('Deve falar uma notificação no singular', () {
      final texto = narrar([alerta('a1')]);

      expect(texto, startsWith('Você tem 1 notificação não lida.'));
    });

    test('Deve ler só as três mais novas e dizer quantas ficaram de fora', () {
      final texto = narrar([
        for (var i = 1; i <= 5; i++) alerta('a$i'),
      ]);

      expect(texto, startsWith('Você tem 5 notificações não lidas.'));
      expect('Emergência de Maria'.allMatches(texto), hasLength(3));
      expect(texto, endsWith('E mais 2 notificações.'));
    });

    test('Deve falar "e mais 1 notificação" no singular', () {
      final texto = narrar([for (var i = 1; i <= 4; i++) alerta('a$i')]);

      expect(texto, endsWith('E mais 1 notificação.'));
    });

    test('Deve ler as não lidas e pular as já lidas', () {
      final texto = narrar([
        alerta('a1', lido: true),
        alerta('a2', pacienteId: 'p2', bpm: 140),
      ]);

      expect(texto, startsWith('Você tem 1 notificação não lida.'));
      expect(texto, contains('Emergência de José'));
      expect(texto, isNot(contains('Maria')));
    });

    test('Quando todas foram lidas, deve dizer só qual foi a última', () {
      final texto = narrar([
        alerta('a1', lido: true),
        alerta('a2', lido: true, pacienteId: 'p2'),
      ]);

      expect(
        texto,
        'Nenhuma notificação nova. A última foi: Emergência de Maria: 130 '
        'batimentos por minuto, há 5 minutos.',
      );
    });

    test('Deve ler o alerta que não tem batimentos', () {
      final texto = narrar([alerta('a1', bpm: null)]);

      expect(texto, contains('Emergência de Maria, há 5 minutos.'));
    });

    test('Deve usar só o primeiro nome do paciente', () {
      final texto = narrar([alerta('a1')]);

      expect(texto, contains('Maria:'));
      expect(texto, isNot(contains('Aparecida')));
    });

    test('Deve ser curto: no máximo três notificações e o resto resumido', () {
      final texto = narrar([for (var i = 1; i <= 9; i++) alerta('a$i')]);

      expect(palavras(texto), lessThan(60), reason: texto);
    });
  });

  group('narrarEmergencia Testes', () {
    String narrar({
      String nome = 'Maria',
      String motivo = 'batimentos cardíacos elevados',
      int? bpm = 150,
      bool podeLigar = true,
      bool temLocalizacao = true,
    }) {
      return narrarEmergencia(
        nomePaciente: nome,
        motivo: motivo,
        bpm: bpm,
        dataHora: DateTime(2026, 11, 7, 14, 32),
        agora: agora,
        podeLigarParaPaciente: podeLigar,
        temLocalizacao: temLocalizacao,
      );
    }

    test('Deve avisar, dizer quem está mal e o que fazer', () {
      expect(
        narrar(),
        'Alerta crítico! Maria está com batimentos cardíacos elevados: 150 '
        'batimentos por minuto, há 3 minutos. Ligue agora para Maria para '
        'saber como está. Se não atender ou relatar mal-estar, ligue para o '
        'SAMU, número um, nove, dois. Toque em Ver localização para saber onde '
        'Maria está.',
      );
    });

    test('Deve mandar falar com o paciente quando ele não tem telefone cadastrado', () {
      final texto = narrar(podeLigar: false);

      expect(texto, contains('Fale com Maria agora para saber como está.'));
      expect(texto, isNot(contains('Ligue agora para Maria')));
    });

    test('Deve ficar sem a localização quando ela não está disponível', () {
      final texto = narrar(temLocalizacao: false);

      expect(texto, isNot(contains('localização')));
      expect(texto, endsWith('número um, nove, dois.'));
    });

    test('Deve ler o alerta sem batimentos', () {
      final texto = narrar(bpm: null, motivo: 'batimentos fora da zona de segurança');

      expect(
        texto,
        contains('Maria está com batimentos fora da zona de segurança, há 3 minutos.'),
      );
    });

    test('Deve começar a frase com maiúscula quando não há nome', () {
      final texto = narrar(nome: 'o paciente');

      expect(texto, contains('O paciente está com batimentos cardíacos elevados'));
      expect(texto, contains('Ligue agora para o paciente'));
    });

    test('Deve soletrar o número do SAMU', () {
      final texto = narrar();

      expect(texto, contains('número um, nove, dois'));
      expect(texto, isNot(contains('192')));
    });

    test('Deve ser curto: um alerta de emergência cabe em poucos segundos', () {
      expect(palavras(narrar()), lessThan(60), reason: narrar());
    });
  });
}
