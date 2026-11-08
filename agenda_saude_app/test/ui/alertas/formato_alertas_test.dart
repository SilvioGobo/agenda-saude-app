import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/models/alerta.dart';
import 'package:agenda_saude_app/ui/alertas/formato_alertas.dart';

void main() {
  group('Formato dos alertas Testes', () {
    Alerta doTipo(String tipo) => Alerta(
          id: tipo,
          pacienteId: 'paciente_01',
          tipo: tipo,
          mensagem: '',
          dataHora: DateTime(2026, 11, 8, 9),
        );

    test('Deve dar o mesmo título do push para cada tipo de alerta', () {
      expect(
        tituloDoAlerta(doTipo(Alerta.tipoEmergencia), 'José'),
        'Emergência: José',
      );
      expect(
        tituloDoAlerta(doTipo(Alerta.tipoAtencao), 'José'),
        'Atenção: José',
      );
      expect(
        tituloDoAlerta(doTipo(Alerta.tipoPendencia), 'José'),
        'Pendência: José',
      );
    });

    test('Deve dar a frase do topo do painel para cada tipo de alerta', () {
      expect(
        mancheteDoAlerta(doTipo(Alerta.tipoEmergencia), 'José'),
        'Emergência com José',
      );
      expect(
        mancheteDoAlerta(doTipo(Alerta.tipoAtencao), 'José'),
        'José precisa de atenção',
      );
      expect(
        mancheteDoAlerta(doTipo(Alerta.tipoPendencia), 'José'),
        'José tem uma atividade pendente',
      );
    });
  });
}
