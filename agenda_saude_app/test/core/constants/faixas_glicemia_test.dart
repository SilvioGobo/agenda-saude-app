import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/core/constants/faixas_glicemia.dart';
import 'package:agenda_saude_app/core/constants/momentos_glicemia.dart';

void main() {
  group('FaixasGlicemia Testes', () {
    test('Deve classificar a glicemia nos limites de cada faixa', () {
      expect(FaixasGlicemia.classificar(53), ClassificacaoGlicemia.muitoBaixa);
      expect(FaixasGlicemia.classificar(54), ClassificacaoGlicemia.baixa);
      expect(FaixasGlicemia.classificar(69), ClassificacaoGlicemia.baixa);
      expect(FaixasGlicemia.classificar(70), ClassificacaoGlicemia.naFaixa);
      expect(FaixasGlicemia.classificar(180), ClassificacaoGlicemia.naFaixa);
      expect(FaixasGlicemia.classificar(181), ClassificacaoGlicemia.alta);
      expect(FaixasGlicemia.classificar(250), ClassificacaoGlicemia.alta);
      expect(FaixasGlicemia.classificar(251), ClassificacaoGlicemia.muitoAlta);
    });

    test('Deve considerar hipoglicemia só abaixo de 70 mg/dL', () {
      expect(FaixasGlicemia.ehHipoglicemia(69), isTrue);
      expect(FaixasGlicemia.ehHipoglicemia(70), isFalse);
    });
  });

  group('MomentoGlicemia Testes', () {
    test('Deve ter as quatro medições da entrevista E6 para quem não usa insulina', () {
      final momentos = MomentoGlicemia.doDia(usaInsulina: false);

      expect(momentos.map((m) => m.nome), [
        'Ao acordar',
        'Antes do almoço',
        'Antes do jantar',
        'Antes de dormir',
      ]);
      expect(momentos.every((m) => m.medeGlicemia), isTrue);
    });

    test('Deve incluir a insulina lenta das 22h para quem usa insulina', () {
      final momentos = MomentoGlicemia.doDia(usaInsulina: true);

      expect(momentos.length, 5);
      expect(momentos.last, MomentoGlicemia.insulinaLenta);
      expect(momentos.last.medeGlicemia, isFalse);
      expect(momentos.last.tipoInsulinaFixo, TipoInsulina.lenta);
    });

    test('Deve achar o momento pelo nome gravado e tratar nome desconhecido como medição avulsa', () {
      expect(MomentoGlicemia.porNome('Antes do jantar').rotulo, 'ANTES DO JANTAR');
      expect(
        MomentoGlicemia.porNome('Insulina lenta (22h)').rotulo,
        'INSULINA LENTA (22\u00A0HORAS)',
      );
      expect(MomentoGlicemia.porNome('Jejum'), MomentoGlicemia.outraMedicao);
    });
  });
}
