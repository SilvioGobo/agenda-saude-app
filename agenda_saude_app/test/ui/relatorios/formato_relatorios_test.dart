import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/ui/relatorios/formato_relatorios.dart';

void main() {
  group('formato_relatorios Testes', () {
    test('Deve dar o nome dos meses e dos dias da semana em português', () {
      expect(nomeDoMes(1), 'janeiro');
      expect(nomeDoMes(3), 'março');
      expect(nomeDoMes(12), 'dezembro');
      // 1/11/2026 foi um domingo; 2/11 uma segunda; 7/11 um sabado.
      expect(nomeDoDiaDaSemana(DateTime(2026, 11, 1)), 'domingo');
      expect(nomeDoDiaDaSemana(DateTime(2026, 11, 2)), 'segunda-feira');
      expect(nomeDoDiaDaSemana(DateTime(2026, 11, 7)), 'sábado');
    });

    test('Deve escrever o mês e o dia por extenso', () {
      expect(tituloDoMes(DateTime(2026, 11, 15)), 'Novembro de 2026');
      expect(tituloDoMes(DateTime(2027, 3)), 'Março de 2027');
      expect(descreverDia(DateTime(2026, 11, 1)), 'domingo, 1 de novembro');
      expect(
        descreverDiaComAno(DateTime(2026, 11, 19)),
        'quinta-feira, 19 de novembro de 2026',
      );
      expect(capitalizar('quinta-feira'), 'Quinta-feira');
      expect(capitalizar(''), '');
    });

    test('Deve formatar a hora com dois dígitos', () {
      expect(formatarHora(DateTime(2026, 11, 1, 7, 5)), '07:05');
      expect(formatarHora(DateTime(2026, 11, 1, 15, 30)), '15:30');
      expect(formatarHora(DateTime(2026, 11, 1, 0, 0)), '00:00');
    });

    test('Deve formatar água com ponto de milhar e porcentagem arredondada', () {
      expect(formatarMl(250), '250 ml');
      expect(formatarMl(1750), '1.750 ml');
      expect(formatarPorcentagem(0.823), '82%');
      expect(formatarPorcentagem(1), '100%');
      expect(formatarPorcentagem(0), '0%');
    });

    test('Deve concordar o número de vezes e listar os dias', () {
      expect(descreverVezes(1), '1 vez');
      expect(descreverVezes(3), '3 vezes');
      expect(listarDias([4]), 'dia 4');
      expect(listarDias([4, 12]), 'dias 4 e 12');
      expect(listarDias([4, 12, 20]), 'dias 4, 12 e 20');
    });

    test('Deve juntar itens com vírgulas e "e" no fim', () {
      expect(juntarComE([]), '');
      expect(juntarComE(['água']), 'água');
      expect(juntarComE(['água', 'refeições']), 'água e refeições');
      expect(
        juntarComE(['água', 'refeições', 'glicemia']),
        'água, refeições e glicemia',
      );
    });

    test('Deve pegar o primeiro nome, com um padrão para nome vazio', () {
      expect(primeiroNomeDe('José Silva'), 'José');
      expect(primeiroNomeDe('  Maria   da Silva '), 'Maria');
      expect(primeiroNomeDe('Ana'), 'Ana');
      expect(primeiroNomeDe(''), 'o paciente');
      expect(primeiroNomeDe('   ', padrao: 'Paciente'), 'Paciente');
    });
  });
}
