import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/ui/paciente/narracao_do_painel.dart';
import 'package:agenda_saude_app/ui/paciente/paciente_viewmodel.dart';

int palavras(String texto) => texto.split(RegExp(r'\s+')).length;

void main() {
  group('narrarPainel Testes', () {
    final agora = DateTime(2026, 11, 7, 14, 34);
    final medidoHaDoisMinutos = DateTime(2026, 11, 7, 14, 32);

    test('Deve dizer os batimentos, quando foram medidos e que está estável', () {
      final texto = narrarPainel(
        primeiroNome: 'Maria',
        status: StatusCardiaco.estavel,
        bpm: 78,
        medidoEm: medidoHaDoisMinutos,
        agora: agora,
      );

      expect(
        texto,
        'Olá, Maria. Seus batimentos estão em 78 por minuto, medidos há 2 '
        'minutos. Está tudo estável. Nesta tela você pode abrir Minha Rotina, '
        'Meus Relatórios ou Falar com Acompanhante.',
      );
    });

    test('Deve avisar que os batimentos estão altos e o que fazer', () {
      final texto = narrarPainel(
        primeiroNome: 'Maria',
        status: StatusCardiaco.alto,
        bpm: 130,
        medidoEm: medidoHaDoisMinutos,
        agora: agora,
      );

      expect(texto, startsWith('Olá, Maria. Atenção! Seus batimentos estão altos: 130 por minuto'));
      expect(texto, contains('Fique em repouso.'));
      expect(texto, contains('fale com seu acompanhante'));
      expect(texto, contains('toque em Falar com Acompanhante'));
      expect(texto, isNot(contains('estável')));
    });

    test('Deve avisar que os batimentos estão baixos', () {
      final texto = narrarPainel(
        primeiroNome: 'José',
        status: StatusCardiaco.baixo,
        bpm: 48,
        medidoEm: medidoHaDoisMinutos,
        agora: agora,
      );

      expect(texto, contains('Atenção! Seus batimentos estão baixos: 48 por minuto'));
    });

    test('Deve terminar o alerta com o que fazer, sem a lista de atalhos', () {
      final texto = narrarPainel(
        primeiroNome: 'Maria',
        status: StatusCardiaco.alto,
        bpm: 130,
        medidoEm: medidoHaDoisMinutos,
        agora: agora,
      );

      expect(texto, endsWith('toque em Falar com Acompanhante.'));
      expect(texto, isNot(contains('Nesta tela')));
    });

    test('Deve dizer o dia quando a última leitura não é de hoje', () {
      final texto = narrarPainel(
        primeiroNome: 'Maria',
        status: StatusCardiaco.estavel,
        bpm: 80,
        medidoEm: DateTime(2026, 11, 6, 21, 0),
        agora: agora,
      );

      expect(texto, contains('medidos ontem, às 21 horas'));
    });

    test('Deve explicar o problema do smartwatch no lugar dos batimentos', () {
      final texto = narrarPainel(
        primeiroNome: 'Maria',
        status: StatusCardiaco.semLeitura,
        semLeituraTitulo: 'Conecte seu smartwatch',
        semLeituraDescricao: 'Permita que o app leia seus batimentos cardíacos.',
        agora: agora,
      );

      expect(
        texto,
        'Olá, Maria. Conecte seu smartwatch. Permita que o app leia seus '
        'batimentos cardíacos. Nesta tela você pode abrir Minha Rotina, Meus '
        'Relatórios ou Falar com Acompanhante.',
      );
    });

    test('Deve avisar que está aguardando a primeira medição', () {
      final texto = narrarPainel(
        primeiroNome: 'Maria',
        status: StatusCardiaco.semLeitura,
        agora: agora,
      );

      expect(texto, contains('Aguardando medição.'));
      expect(texto, contains('Use o smartwatch no pulso.'));
    });

    test('Não deve inventar batimentos se faltar o horário da medição', () {
      final texto = narrarPainel(
        primeiroNome: 'Maria',
        status: StatusCardiaco.estavel,
        bpm: 78,
        agora: agora,
      );

      expect(texto, isNot(contains('78')));
      expect(texto, contains('Aguardando medição.'));
    });

    test('Deve ser curto: poucos segundos de fala', () {
      for (final status in [
        StatusCardiaco.estavel,
        StatusCardiaco.alto,
        StatusCardiaco.baixo,
      ]) {
        final texto = narrarPainel(
          primeiroNome: 'Maria Aparecida',
          status: status,
          bpm: 120,
          medidoEm: DateTime(2026, 11, 6, 21, 5),
          agora: agora,
        );

        expect(palavras(texto), lessThan(55), reason: texto);
      }
    });
  });
}
