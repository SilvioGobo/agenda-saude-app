import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/constants/meta_exercicio.dart';

void main() {
  group('MetaExercicio Testes', () {
    test('Deve começar a semana no domingo, como o calendário dos relatórios', () {
      // Novembro de 2026 começa num domingo.
      final domingo = DateTime(2026, 11, 1);

      expect(MetaExercicio.inicioDaSemana(DateTime(2026, 11, 1)), domingo);
      expect(MetaExercicio.inicioDaSemana(DateTime(2026, 11, 2)), domingo);
      expect(MetaExercicio.inicioDaSemana(DateTime(2026, 11, 6)), domingo);
      expect(MetaExercicio.inicioDaSemana(DateTime(2026, 11, 7)), domingo);
      expect(
        MetaExercicio.inicioDaSemana(DateTime(2026, 11, 8)),
        DateTime(2026, 11, 8),
      );
    });

    test('Deve guardar o início da semana sem a hora', () {
      expect(
        MetaExercicio.inicioDaSemana(DateTime(2026, 11, 6, 15, 40)),
        DateTime(2026, 11, 1),
      );
    });

    test('Deve voltar ao mês anterior quando a semana começa nele', () {
      // Quarta-feira, 2 de dezembro de 2026: a semana começou em 29/11.
      expect(
        MetaExercicio.inicioDaSemana(DateTime(2026, 12, 2)),
        DateTime(2026, 11, 29),
      );
      // E ao ano anterior.
      expect(
        MetaExercicio.inicioDaSemana(DateTime(2027, 1, 2)),
        DateTime(2026, 12, 27),
      );
    });

    test('Deve oferecer tipos e intensidades fixos, com "Outro" no fim', () {
      expect(MetaExercicio.tipos.first, 'Caminhada');
      expect(MetaExercicio.tipos.last, 'Outro');
      expect(MetaExercicio.intensidades, ['Leve', 'Moderada', 'Intensa']);
    });

    test('Deve ter o minuto inicial dentro dos limites e no passo de 5', () {
      expect(MetaExercicio.minutosIniciais,
          inInclusiveRange(MetaExercicio.minutosMinimos, MetaExercicio.minutosMaximos));
      expect(MetaExercicio.minutosIniciais % MetaExercicio.passoMinutos, 0);
      expect(MetaExercicio.minutosMinimos % MetaExercicio.passoMinutos, 0);
      expect(MetaExercicio.minutosMaximos % MetaExercicio.passoMinutos, 0);
    });
  });
}
