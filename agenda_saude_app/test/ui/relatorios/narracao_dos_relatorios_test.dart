import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_saude_app/domain/models/alerta.dart';
import 'package:agenda_saude_app/domain/models/batimento_cardiaco.dart';
import 'package:agenda_saude_app/domain/models/medicamento.dart';
import 'package:agenda_saude_app/domain/models/paciente.dart';
import 'package:agenda_saude_app/domain/models/refeicao_planejada.dart';
import 'package:agenda_saude_app/domain/models/registro_agua.dart';
import 'package:agenda_saude_app/domain/models/registro_diabete.dart';
import 'package:agenda_saude_app/domain/models/registro_medicacao.dart';
import 'package:agenda_saude_app/domain/models/registro_refeicao.dart';
import 'package:agenda_saude_app/domain/models/registro_sono.dart';
import 'package:agenda_saude_app/domain/relatorios/calculadora_relatorios.dart';
import 'package:agenda_saude_app/ui/relatorios/narracao_dos_relatorios.dart';

const _cafe = RefeicaoPlanejada(id: 'cafe', nome: 'Café');
const _almoco = RefeicaoPlanejada(id: 'almoco', nome: 'Almoço');

Paciente _paciente({
  bool diabetes = false,
  bool cardiopatia = false,
  List<Medicamento> medicamentos = const [],
}) {
  return Paciente(
    id: 'paciente_01',
    nome: 'José Silva',
    email: 'jose@email.com',
    perfil: 'Paciente',
    medicamentos: medicamentos,
    possuiDiabetes: diabetes,
    usaInsulina: diabetes ? false : null,
    possuiCardiopatia: cardiopatia,
    codigoVinculo: 'ABC123',
    refeicoes: const [_cafe, _almoco],
  );
}

RegistroAgua _agua(DateTime quando, [int ml = 250]) => RegistroAgua(
      id: '',
      pacienteId: 'paciente_01',
      dataHora: quando,
      quantidadeML: ml,
    );

List<RegistroAgua> _copos(DateTime dia, int quantidade) => [
      for (var i = 0; i < quantidade; i++)
        _agua(DateTime(dia.year, dia.month, dia.day, 8 + i)),
    ];

RegistroRefeicao _refeicao(String refeicaoId, DateTime quando) =>
    RegistroRefeicao(
      id: '',
      pacienteId: 'paciente_01',
      dataHora: quando,
      refeicaoId: refeicaoId,
      nome: refeicaoId,
    );

RegistroSono _sono(DateTime quando) => RegistroSono(
      id: '',
      pacienteId: 'paciente_01',
      dataHora: quando,
      dataFim: quando,
      horasTotais: 7.5,
      qualidade: 4,
    );

RegistroMedicacao _dose(String medicamentoId, String horario, DateTime quando) =>
    RegistroMedicacao(
      id: '',
      pacienteId: 'paciente_01',
      dataHora: quando,
      medicamentoId: medicamentoId,
      horario: horario,
      nome: medicamentoId,
    );

RegistroDiabete _glicemia(DateTime quando, double mgDl, {String momento = 'Ao acordar'}) =>
    RegistroDiabete(
      id: '',
      pacienteId: 'paciente_01',
      dataHora: quando,
      nivelGlicose: mgDl,
      momento: momento,
    );

BatimentoCardiaco _bpm(int valor, DateTime quando) => BatimentoCardiaco(
      id: '',
      pacienteId: 'paciente_01',
      bpm: valor,
      timestamp: quando,
    );

Alerta _alerta(String tipo, DateTime quando, {int? bpm}) => Alerta(
      id: '',
      pacienteId: 'paciente_01',
      tipo: tipo,
      mensagem: 'alerta $tipo',
      bpm: bpm,
      dataHora: quando,
    );

int palavras(String texto) => texto.split(RegExp(r'\s+')).length;

void main() {
  // 1 de novembro de 2026 e um domingo.
  final dia = DateTime(2026, 11, 1);

  group('narrarRelatorioDoDia Testes', () {
    // Um dia em que tudo foi cumprido; cada teste muda so o que quer provar.
    String narrarDia({
      Paciente? paciente,
      List<RegistroAgua>? agua,
      List<RegistroRefeicao>? refeicoes,
      List<RegistroSono>? sono,
      List<RegistroMedicacao> medicacoes = const [],
      List<RegistroDiabete> diabete = const [],
      List<BatimentoCardiaco> batimentos = const [],
      List<Alerta> alertas = const [],
    }) {
      final resumo = CalculadoraRelatorios.resumirDia(
        paciente: paciente ?? _paciente(),
        dia: dia,
        agua: agua ?? _copos(dia, 8),
        refeicoes: refeicoes ??
            [
              _refeicao('cafe', DateTime(2026, 11, 1, 8)),
              _refeicao('almoco', DateTime(2026, 11, 1, 12)),
            ],
        sono: sono ?? [_sono(DateTime(2026, 11, 1, 7))],
        medicacoes: medicacoes,
        diabete: diabete,
        batimentos: batimentos,
        alertas: alertas,
      );
      return narrarRelatorioDoDia(resumo);
    }

    group('situação da rotina', () {
      test('Deve começar pelo dia do relatório', () {
        expect(narrarDia(), startsWith('Relatório de domingo, 1 de novembro.'));
      });

      test('Deve dizer que a rotina foi completa', () {
        expect(narrarDia(), contains('Rotina completa. Tudo foi cumprido.'));
      });

      test('Deve dizer só o que faltou numa rotina parcial', () {
        final texto = narrarDia(
          agua: _copos(dia, 6),
          refeicoes: [_refeicao('cafe', DateTime(2026, 11, 1, 8))],
          sono: [],
        );

        expect(
          texto,
          contains('Rotina parcial. Faltou: meta de água, refeições e sono.'),
        );
      });

      test('Deve incluir os remédios na conta quando o paciente tem', () {
        const losartana = Medicamento(
          id: 'm1',
          nome: 'Losartana',
          dose: '50 mg',
          horarios: ['08:00', '20:00'],
        );
        final texto = narrarDia(
          paciente: _paciente(medicamentos: [losartana]),
          medicacoes: [_dose('m1', '08:00', DateTime(2026, 11, 1, 8, 5))],
        );

        expect(texto, contains('Faltou: remédios.'));
      });

      test('Deve incluir a glicemia na conta de quem tem diabetes', () {
        final texto = narrarDia(
          paciente: _paciente(diabetes: true),
          diabete: [_glicemia(DateTime(2026, 11, 1, 7), 110)],
        );

        expect(texto, contains('Faltou: glicemia.'));
      });

      test('Deve dizer que nada foi anotado num dia sem registros', () {
        final texto = narrarDia(agua: [], refeicoes: [], sono: []);

        expect(texto, contains('Nada da rotina foi anotado neste dia.'));
        expect(texto, isNot(contains('Faltou')));
      });
    });

    group('pontos de atenção', () {
      test('Deve avisar do alerta de emergência, com a hora e os batimentos', () {
        final texto = narrarDia(
          alertas: [_alerta('emergencia', DateTime(2026, 11, 1, 14, 32), bpm: 150)],
        );

        expect(
          texto,
          contains(
            'Atenção: houve um alerta de emergência nos batimentos, às 14 '
            'horas e 32 minutos, com 150 batimentos por minuto.',
          ),
        );
      });

      test('Deve contar as emergências e dizer a hora da última', () {
        final texto = narrarDia(
          alertas: [
            _alerta('emergencia', DateTime(2026, 11, 1, 18, 0), bpm: 140),
            _alerta('emergencia', DateTime(2026, 11, 1, 9, 15), bpm: 130),
          ],
        );

        expect(
          texto,
          contains(
            'Atenção: houve 2 alertas de emergência nos batimentos, o último '
            'às 18 horas.',
          ),
        );
      });

      test('Não deve chamar de ponto de atenção o alerta que não é de emergência', () {
        final texto = narrarDia(
          alertas: [_alerta('atencao', DateTime(2026, 11, 1, 10), bpm: 105)],
        );

        expect(texto, isNot(contains('Atenção:')));
      });

      test('Deve avisar da glicemia baixa e da muito alta, por extenso', () {
        final texto = narrarDia(
          paciente: _paciente(diabetes: true),
          diabete: [
            _glicemia(DateTime(2026, 11, 1, 7), 55),
            _glicemia(DateTime(2026, 11, 1, 12), 300, momento: 'Antes do almoço'),
          ],
        );

        expect(
          texto,
          contains('Glicemia baixa 1 vez: a menor foi 55 miligramas por decilitro.'),
        );
        expect(
          texto,
          contains(
            'Glicemia muito alta 1 vez: a maior foi 300 miligramas por decilitro.',
          ),
        );
        expect(texto, isNot(contains('mg/dL')));
      });

      test('Deve falar os pontos de atenção antes dos batimentos', () {
        final texto = narrarDia(
          batimentos: [_bpm(80, DateTime(2026, 11, 1, 9))],
          alertas: [_alerta('emergencia', DateTime(2026, 11, 1, 14), bpm: 150)],
        );

        expect(
          texto.indexOf('Atenção:'),
          lessThan(texto.indexOf('Batimentos')),
        );
      });
    });

    group('batimentos', () {
      test('Deve avisar quando o smartwatch não mediu nada', () {
        expect(
          narrarDia(),
          endsWith('O smartwatch não mediu batimentos neste dia.'),
        );
      });

      test('Deve dizer a média quando tudo ficou dentro da zona', () {
        final texto = narrarDia(
          batimentos: [
            _bpm(70, DateTime(2026, 11, 1, 9)),
            _bpm(90, DateTime(2026, 11, 1, 10)),
          ],
        );

        expect(
          texto,
          endsWith(
            'Batimentos sempre dentro da zona de segurança, com média de 80 por minuto.',
          ),
        );
      });

      test('Deve contar as leituras fora da zona', () {
        final texto = narrarDia(
          batimentos: [
            _bpm(70, DateTime(2026, 11, 1, 9)),
            _bpm(120, DateTime(2026, 11, 1, 10)),
            _bpm(130, DateTime(2026, 11, 1, 11)),
          ],
        );

        expect(
          texto,
          endsWith(
            'Batimentos com média de 107 por minuto. 2 leituras ficaram fora '
            'da zona de segurança.',
          ),
        );
      });

      test('Deve falar uma leitura no singular', () {
        final texto = narrarDia(
          batimentos: [
            _bpm(70, DateTime(2026, 11, 1, 9)),
            _bpm(120, DateTime(2026, 11, 1, 10)),
          ],
        );

        expect(texto, contains('1 leitura ficou fora da zona de segurança.'));
      });

      test('Deve usar a zona mais estreita dos cardiopatas', () {
        final texto = narrarDia(
          paciente: _paciente(cardiopatia: true),
          batimentos: [_bpm(95, DateTime(2026, 11, 1, 9))],
        );

        expect(texto, contains('1 leitura ficou fora da zona de segurança.'));
      });
    });

    test('Não deve ler siglas que a voz pronuncia mal', () {
      final texto = narrarDia(
        paciente: _paciente(diabetes: true),
        diabete: [_glicemia(DateTime(2026, 11, 1, 7), 55)],
        batimentos: [_bpm(120, DateTime(2026, 11, 1, 9))],
        alertas: [_alerta('emergencia', DateTime(2026, 11, 1, 14), bpm: 150)],
      );

      expect(texto, isNot(contains('BPM')));
      expect(texto, isNot(contains('mg/dL')));
    });

    test('Deve ser curto mesmo no pior caso: tudo errado, com alertas', () {
      final texto = narrarDia(
        paciente: _paciente(diabetes: true),
        agua: [],
        refeicoes: [_refeicao('cafe', DateTime(2026, 11, 1, 8))],
        sono: [],
        diabete: [
          _glicemia(DateTime(2026, 11, 1, 7), 50),
          _glicemia(DateTime(2026, 11, 1, 12), 320, momento: 'Antes do almoço'),
        ],
        batimentos: [
          _bpm(70, DateTime(2026, 11, 1, 9)),
          _bpm(130, DateTime(2026, 11, 1, 10)),
        ],
        alertas: [
          _alerta('emergencia', DateTime(2026, 11, 1, 18), bpm: 140),
          _alerta('emergencia', DateTime(2026, 11, 1, 10, 30), bpm: 130),
        ],
      );

      expect(palavras(texto), lessThan(95), reason: texto);
    });
  });

  group('narrarRelatorioDoMes Testes', () {
    final novembro = DateTime(2026, 11, 1);

    String narrarMes({
      Paciente? paciente,
      DateTime? hoje,
      List<RegistroAgua> agua = const [],
      List<RegistroRefeicao> refeicoes = const [],
      List<RegistroSono> sono = const [],
      List<RegistroDiabete> diabete = const [],
      List<Alerta> alertas = const [],
    }) {
      final resumo = CalculadoraRelatorios.resumirMes(
        paciente: paciente ?? _paciente(),
        mes: novembro,
        hoje: hoje ?? DateTime(2026, 11, 4, 10),
        agua: agua,
        refeicoes: refeicoes,
        sono: sono,
        diabete: diabete,
        alertas: alertas,
      );
      return narrarRelatorioDoMes(resumo);
    }

    // Dia 1 completo (8 copos, as 2 refeicoes e o sono) e dia 2 so com agua.
    final diaCompletoEParcial = (
      agua: [
        ..._copos(DateTime(2026, 11, 1), 8),
        ..._copos(DateTime(2026, 11, 2), 3),
      ],
      refeicoes: [
        _refeicao('cafe', DateTime(2026, 11, 1, 8)),
        _refeicao('almoco', DateTime(2026, 11, 1, 12)),
      ],
      sono: [_sono(DateTime(2026, 11, 1, 7))],
    );

    test('Deve começar pelo mês', () {
      expect(narrarMes(), startsWith('Relatório de novembro de 2026.'));
    });

    test('Deve avisar que o mês ainda não tem dias encerrados', () {
      final texto = narrarMes(hoje: DateTime(2026, 11, 1, 10));

      expect(
        texto,
        'Relatório de novembro de 2026. Ainda não terminou nenhum dia deste '
        'mês. O relatório aparece a partir de amanhã.',
      );
    });

    test('Deve contar os dias por situação, sem citar o que é zero', () {
      final texto = narrarMes(
        agua: diaCompletoEParcial.agua,
        refeicoes: diaCompletoEParcial.refeicoes,
        sono: diaCompletoEParcial.sono,
      );

      // Dias 1 a 3 encerrados: completo, parcial e sem registro.
      expect(
        texto,
        contains(
          '3 dias encerrados neste mês: 1 com a rotina completa, 1 com a '
          'rotina parcial e 1 sem registro.',
        ),
      );
    });

    test('Deve falar um dia encerrado no singular e citar só o que existe', () {
      final texto = narrarMes(
        hoje: DateTime(2026, 11, 2, 10),
        agua: diaCompletoEParcial.agua,
        refeicoes: diaCompletoEParcial.refeicoes,
        sono: diaCompletoEParcial.sono,
      );

      expect(
        texto,
        contains('1 dia encerrado neste mês: 1 com a rotina completa.'),
      );
    });

    test('Deve dizer em quantos dias a meta de água foi batida', () {
      final texto = narrarMes(
        agua: diaCompletoEParcial.agua,
        refeicoes: diaCompletoEParcial.refeicoes,
        sono: diaCompletoEParcial.sono,
      );

      expect(texto, contains('Meta de água batida em 1 dia.'));
    });

    test('Deve dizer quando nenhum dia bateu a meta de água', () {
      expect(narrarMes(), contains('Nenhum dia bateu a meta de água.'));
    });

    test('Deve dizer que os batimentos não geraram alertas', () {
      expect(
        narrarMes(),
        endsWith('Os batimentos não geraram alertas neste mês.'),
      );
    });

    test('Deve contar os alertas e dizer o dia da emergência', () {
      final texto = narrarMes(
        alertas: [
          _alerta('emergencia', DateTime(2026, 11, 2, 15), bpm: 150),
          _alerta('atencao', DateTime(2026, 11, 2, 14), bpm: 110),
          _alerta('atencao', DateTime(2026, 11, 3, 9), bpm: 108),
        ],
      );

      expect(
        texto,
        endsWith(
          'Batimentos: 1 alerta de emergência no dia 2 e 2 alertas de atenção.',
        ),
      );
    });

    test('Deve citar os vários dias com emergência', () {
      final texto = narrarMes(
        alertas: [
          _alerta('emergencia', DateTime(2026, 11, 2, 15), bpm: 150),
          _alerta('emergencia', DateTime(2026, 11, 3, 9), bpm: 140),
        ],
      );

      expect(texto, contains('2 alertas de emergência nos dias 2 e 3'));
    });

    group('diabetes', () {
      test('Não deve falar de glicemia para quem não tem diabetes', () {
        expect(narrarMes(), isNot(contains('licemia')));
      });

      test('Deve dizer a glicemia média e os dias críticos', () {
        final texto = narrarMes(
          paciente: _paciente(diabetes: true),
          diabete: [
            _glicemia(DateTime(2026, 11, 1, 7), 60),
            _glicemia(DateTime(2026, 11, 2, 7), 300),
          ],
        );

        expect(texto, contains('Glicemia média de 180 miligramas por decilitro.'));
        expect(texto, contains('Glicemia baixa no dia 1.'));
        expect(texto, contains('Glicemia muito alta no dia 2.'));
      });

      test('Deve ficar sem a média quando não houve medição', () {
        final texto = narrarMes(paciente: _paciente(diabetes: true));

        expect(texto, isNot(contains('Glicemia média')));
      });
    });

    test('Deve ser curto mesmo no pior caso', () {
      final texto = narrarMes(
        paciente: _paciente(diabetes: true),
        hoje: DateTime(2026, 11, 20, 10),
        agua: diaCompletoEParcial.agua,
        refeicoes: diaCompletoEParcial.refeicoes,
        sono: diaCompletoEParcial.sono,
        diabete: [
          _glicemia(DateTime(2026, 11, 1, 7), 60),
          _glicemia(DateTime(2026, 11, 2, 7), 300),
        ],
        alertas: [
          _alerta('emergencia', DateTime(2026, 11, 2, 15), bpm: 150),
          _alerta('emergencia', DateTime(2026, 11, 3, 9), bpm: 140),
          _alerta('atencao', DateTime(2026, 11, 4, 9), bpm: 108),
        ],
      );

      expect(palavras(texto), lessThan(95), reason: texto);
    });
  });

  test('Deve ter avisos prontos para quando o relatório não carregou', () {
    expect(relatorioCarregandoNarrado, contains('carregando'));
    expect(relatorioComErroNarrado, contains('Não foi possível'));
  });
}
