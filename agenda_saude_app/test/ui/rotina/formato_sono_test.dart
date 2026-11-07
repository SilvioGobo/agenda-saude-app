import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/ui/rotina/formato_sono.dart';

void main() {
  group('formato_sono Testes', () {
    test('Deve escrever as horas dormidas em horas e minutos', () {
      expect(formatarHorasDeSono(7), '7 h');
      expect(formatarHorasDeSono(7.5), '7 h 30 min');
      expect(formatarHorasDeSono(8.25), '8 h 15 min');
      expect(formatarHorasDeSono(0.5), '30 min');
      expect(formatarHorasDeSono(14), '14 h');
    });

    test('Deve falar as horas por extenso para o leitor de tela', () {
      expect(falarHorasDeSono(7), '7 horas');
      expect(falarHorasDeSono(1), '1 hora');
      expect(falarHorasDeSono(7.5), '7 horas e 30 minutos');
      expect(falarHorasDeSono(1.5), '1 hora e 30 minutos');
      expect(falarHorasDeSono(0.5), '30 minutos');
    });

    test('Deve escrever a meta como faixa, ou como número só quando a faixa é uma', () {
      expect(formatarMetaDeSono(7, 9), '7 a 9 horas');
      expect(formatarMetaDeSono(7, 8), '7 a 8 horas');
      expect(formatarMetaDeSono(8, 8), '8 horas');
    });

    test('Deve dar uma palavra para cada nota de 1 a 5', () {
      expect(rotuloDaQualidadeDoSono(1), 'Muito ruim');
      expect(rotuloDaQualidadeDoSono(2), 'Ruim');
      expect(rotuloDaQualidadeDoSono(3), 'Regular');
      expect(rotuloDaQualidadeDoSono(4), 'Bom');
      expect(rotuloDaQualidadeDoSono(5), 'Muito bom');
    });

    test('Deve devolver vazio para uma nota fora da escala', () {
      expect(rotuloDaQualidadeDoSono(0), '');
      expect(rotuloDaQualidadeDoSono(6), '');
    });

    test('Deve juntar a palavra e a nota', () {
      expect(descreverQualidadeDoSono(4), 'Bom (4 de 5)');
      expect(descreverQualidadeDoSono(1), 'Muito ruim (1 de 5)');
      // Fora da escala: so a nota.
      expect(descreverQualidadeDoSono(0), '0 de 5');
    });
  });
}
